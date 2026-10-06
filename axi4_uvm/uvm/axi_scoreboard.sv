// Reference model: a byte-addressed associative array.
// Every observed write updates it; every observed read is checked against it.
class axi_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(axi_scoreboard)
    uvm_analysis_imp #(axi_item, axi_scoreboard) imp;

    bit [7:0] ref_mem [int];
    int n_wr, n_rd, n_err_resp, n_mismatch;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        imp = new("imp", this);
    endfunction

    function void write(axi_item t);
        if (t.is_write) check_write(t); else check_read(t);
    endfunction

    function void check_write(axi_item t);
        bit [1:0] exp_resp = t.oor ? 2'b10 : 2'b00;
        n_wr++;
        if (t.resp[0] !== exp_resp) begin
            n_mismatch++;
            `uvm_error("SCB", $sformatf("%s: BRESP %0b, expected %0b", t.convert2string(), t.resp[0], exp_resp))
        end
        if (t.oor) begin n_err_resp++; return; end    // nothing is written
        for (int i = 0; i <= t.len; i++) begin
            bit [15:0] a = t.beat_addr(i) & ~16'd3;   // word address
            for (int l = 0; l < 4; l++)
                if (t.strb[i][l]) ref_mem[a + l] = t.data[i][8*l +: 8];
        end
    endfunction

    function void check_read(axi_item t);
        n_rd++;
        for (int i = 0; i <= t.len; i++) begin
            bit [15:0] a = t.beat_addr(i);
            bit [1:0]  exp_resp = t.oor ? 2'b10 : 2'b00;
            if (t.resp[i] !== exp_resp) begin
                n_mismatch++;
                `uvm_error("SCB", $sformatf("%s beat %0d: RRESP %0b, expected %0b",
                                            t.convert2string(), i, t.resp[i], exp_resp))
                continue;
            end
            if (t.oor) begin n_err_resp++; continue; end
            for (int l = 0; l < 4; l++) begin
                bit [3:0] lanes = t.lane_mask(i);
                bit [7:0] exp_b = ref_mem.exists((a & ~16'd3) + l) ? ref_mem[(a & ~16'd3) + l] : 8'h00;
                if (lanes[l] && t.data[i][8*l +: 8] !== exp_b) begin
                    n_mismatch++;
                    `uvm_error("SCB", $sformatf("%s beat %0d lane %0d: got %02h, expected %02h",
                                                t.convert2string(), i, l, t.data[i][8*l +: 8], exp_b))
                end
            end
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SCB", $sformatf("writes=%0d reads=%0d error-responses=%0d mismatches=%0d",
                                   n_wr, n_rd, n_err_resp, n_mismatch), UVM_NONE)
        if (n_mismatch == 0 && n_wr + n_rd > 0) `uvm_info("SCB", "TEST PASSED", UVM_NONE)
        else `uvm_error("SCB", "TEST FAILED")
    endfunction
endclass
