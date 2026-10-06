// Quick non-UVM check of the DUT and the SVA checker (runs in Verilator).
// Not the deliverable: it just proves the DUT is sane before the UVM env runs on a commercial simulator.
`timescale 1ns/1ps
module dut_smoke;
    logic aclk = 0, aresetn = 0;
    always #5 aclk = ~aclk;

    logic [3:0] awid, arid, bid, rid;
    logic [15:0] awaddr, araddr;
    logic [7:0] awlen, arlen;
    logic [2:0] awsize, arsize;
    logic [1:0] awburst, arburst, bresp, rresp;
    logic awvalid = 0, awready, wvalid = 0, wready, wlast = 0, bvalid, bready = 0;
    logic arvalid = 0, arready, rvalid, rready = 0, rlast;
    logic [31:0] wdata, rdata;
    logic [3:0] wstrb;

    axi4_mem dut (.*);
    axi_checker chk (.*);

    // reference model
    byte unsigned ref_mem [int];
    int errors = 0, checks = 0;

    function automatic logic [15:0] nxt(logic [15:0] a, int size, int len, int burst);
        int nb = 1 << size; int total = (len + 1) << size;
        case (burst)
            1: return a + nb;
            2: return (a & ~16'(total - 1)) | 16'((a + nb) & (total - 1));
            default: return a;
        endcase
    endfunction

    task automatic do_write(input logic [3:0] id, input logic [15:0] addr, input int len,
                            input int size, input int burst, input logic [3:0] strb_mask);
        logic [15:0] a = addr;
        logic [1:0] resp;
        logic [3:0] got_bid;
        awid = id; awaddr = addr; awlen = len; awsize = size; awburst = burst; awvalid = 1;
        do @(negedge aclk); while (!awready); @(posedge aclk);
        #1 awvalid = 0;
        for (int i = 0; i <= len; i++) begin
            wdata = $urandom; wstrb = $urandom & strb_mask; wlast = (i == len); wvalid = 1;
            // narrow transfers: keep strobes inside the active lanes
            if (size < 2) wstrb &= (4'((1 << (1 << size)) - 1)) << a[1:0];
            do @(negedge aclk); while (!wready); @(posedge aclk);
            if (a < 16384)
                for (int l = 0; l < 4; l++) if (wstrb[l]) ref_mem[(a & ~16'd3) + l] = wdata[8*l +: 8];
            a = nxt(a, size, len, burst);
            #1 wvalid = 0;
            if ($urandom_range(0, 3) == 0) begin repeat ($urandom_range(1, 3)) @(posedge aclk); #1; end
        end
        wlast = 0;
        bready = 1;
        do @(negedge aclk); while (!bvalid);
        resp = bresp; got_bid = bid;
        @(posedge aclk);
        #1 bready = 0;
        checks++;
        if (resp !== ((addr >= 16384) ? 2'b10 : 2'b00)) begin
            errors++; $display("FAIL write resp %0d @%h", resp, addr);
        end
        if (got_bid !== id) begin errors++; $display("FAIL bid"); end
    endtask

    task automatic do_read(input logic [3:0] id, input logic [15:0] addr, input int len,
                           input int size, input int burst);
        logic [15:0] a = addr;
        logic [31:0] g_data; logic [1:0] g_resp; logic g_last; logic [3:0] g_id;
        arid = id; araddr = addr; arlen = len; arsize = size; arburst = burst; arvalid = 1;
        do @(posedge aclk); while (!arready);
        #1 arvalid = 0;
        for (int i = 0; i <= len; i++) begin
            rready = 1;
            do @(negedge aclk); while (!rvalid);
            g_data = rdata; g_resp = rresp; g_last = rlast; g_id = rid;
            @(posedge aclk);
            checks++;
            if (a >= 16384) begin
                if (g_resp !== 2'b10) begin errors++; $display("FAIL read resp @%h", a); end
            end else begin
                if (g_resp !== 2'b00) begin errors++; $display("FAIL read okay resp @%h", a); end
                for (int l = 0; l < 4; l++) begin
                    int lane_active = (size == 2) ? 1 : ((l >= a[1:0]) && (l < a[1:0] + (1 << size)));
                    byte unsigned exp = ref_mem.exists((a & ~16'd3) + l) ? ref_mem[(a & ~16'd3) + l] : 8'h00;
                    if (lane_active && g_data[8*l +: 8] !== exp) begin
                        errors++; $display("FAIL read data @%h lane %0d exp %02h got %02h", a, l, exp, g_data[8*l +: 8]);
                    end
                end
            end
            if (g_last !== (i == len)) begin errors++; $display("FAIL rlast beat %0d", i); end
            if (g_id !== id) begin errors++; $display("FAIL rid"); end
            a = nxt(a, size, len, burst);
            #1 rready = 0;
            if ($urandom_range(0, 3) == 0) begin repeat ($urandom_range(1, 3)) @(posedge aclk); #1; end
        end
    endtask

    function automatic logic [15:0] rand_addr(int len, int size, int burst, bit oor);
        logic [15:0] base = oor ? 16'(16384 + 4096 * $urandom_range(0, 11)) : 16'(4096 * $urandom_range(0, 3));
        int total = (len + 1) << size;
        int off;
        if (burst == 1) off = $urandom_range(0, (4096 - total) >> size) << size;
        else if (burst == 2) off = $urandom_range(0, (4096 >> size) - 1) << size;
        else off = $urandom_range(0, (4096 >> size) - 1) << size;
        return base + 16'(off);
    endfunction

    initial begin
        repeat (4) @(posedge aclk);
        #1 aresetn = 1;
        repeat (2) @(posedge aclk); #1;

        
        do_write(1, 16'h0010, 0, 2, 1, 4'hF);
        do_read (1, 16'h0010, 0, 2, 1);
        // INCR 8 beats, WRAP 4 beats, FIXED 3 beats
        do_write(2, 16'h0100, 7, 2, 1, 4'hF);
        do_read (2, 16'h0100, 7, 2, 1);
        do_write(3, 16'h0208, 3, 2, 2, 4'hF);
        do_read (3, 16'h0208, 3, 2, 2);
        do_write(4, 16'h0300, 2, 2, 0, 4'hF);
        do_read (4, 16'h0300, 2, 2, 0);
        // out of range
        do_write(5, 16'h5000, 3, 2, 1, 4'hF);
        do_read (5, 16'h5000, 3, 2, 1);

        // random mix, in range and out of range, all burst types, all sizes
        repeat (400) begin
            int burst = $urandom_range(0, 2);
            int size  = $urandom_range(0, 2);
            int len   = (burst == 2) ? ((1 << $urandom_range(1, 4)) - 1) : $urandom_range(0, 15);
            bit oor   = ($urandom_range(0, 9) == 0);
            logic [15:0] a = rand_addr(len, size, burst, oor);
            logic [3:0] id = $urandom;
            do_write(id, a, len, size, burst, 4'hF);
            do_read (id, a, len, size, burst);
        end

        $display("DONE: %0d checks, %0d errors", checks, errors);
        if (errors == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
        $finish;
    end

    initial begin #20_000_000; $display("RESULT: FAIL (timeout)"); $finish; end
endmodule
