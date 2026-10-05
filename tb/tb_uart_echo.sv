// Self-checking testbench. Acts as the "host PC": drives bytes on the serial
// line into the DUT and checks that the same bytes come back.
`timescale 1ns/1ps
module tb_uart_echo;
    localparam int CPB = 16;   // short bit time to keep sim fast

    logic clk = 0, rst = 1;
    logic host_tx = 1;         // host -> DUT
    logic host_rx;             // DUT -> host
    logic led_err;
    int errors = 0, checks = 0;

    always #5 clk = ~clk;

    uart_echo_top #(.CLKS_PER_BIT(CPB)) dut (
        .clk, .rst, .uart_rx_pin(host_tx), .uart_tx_pin(host_rx), .led_err
    );

    task automatic send_byte(input logic [7:0] b);
        host_tx = 0; repeat (CPB) @(posedge clk);
        for (int i = 0; i < 8; i++) begin
            host_tx = b[i]; repeat (CPB) @(posedge clk);
        end
        host_tx = 1; repeat (CPB) @(posedge clk);
    endtask

    // Monitor: runs forever, decodes every byte the DUT transmits.
    logic [7:0] rx_q[$];
    int stop_bad = 0;
    initial begin
        logic [7:0] b;
        wait (rst == 0);                             // ignore reset glitches
        repeat (CPB) @(posedge clk);
        forever begin
            wait (host_rx == 0);                     // start bit
            repeat (CPB + CPB/2) @(posedge clk);     // middle of bit 0
            for (int i = 0; i < 8; i++) begin
                b[i] = host_rx; repeat (CPB) @(posedge clk);
            end
            if (host_rx !== 1'b1) stop_bad++;        // middle of stop bit
            rx_q.push_back(b);
            repeat (CPB/2 + 1) @(posedge clk);       // finish stop bit
        end
    end

    task automatic check_echo(input logic [7:0] b);
        logic [7:0] got;
        send_byte(b);
        repeat (CPB * 12) @(posedge clk);            // wait for echo
        checks++;
        if (rx_q.size() == 0) begin
            errors++; $display("FAIL: sent %02h, nothing came back", b);
        end else begin
            got = rx_q.pop_front();
            if (got !== b) begin
                errors++; $display("FAIL: sent %02h got %02h", b, got);
            end else $display("PASS: %02h", b);
        end
    endtask

    initial begin
        repeat (10) @(posedge clk);
        rst = 0;
        repeat (10) @(posedge clk);

        // corner cases
        check_echo(8'h00);
        check_echo(8'hFF);
        check_echo(8'h55);
        check_echo(8'hAA);
        check_echo(8'h41);
        // random bytes
        repeat (20) check_echo(8'($urandom_range(0, 255)));

        // framing error: stop bit forced low, LED must latch
        host_tx = 0; repeat (CPB) @(posedge clk);
        repeat (8) begin host_tx = 0; repeat (CPB) @(posedge clk); end
        host_tx = 0; repeat (CPB) @(posedge clk);   // bad stop bit
        host_tx = 1; repeat (CPB*3) @(posedge clk);
        checks++;
        if (!led_err) begin errors++; $display("FAIL: framing error not flagged"); end
        else $display("PASS: framing error flagged");

        if (stop_bad != 0) begin errors++; $display("FAIL: bad stop bit from DUT"); end
        $display("DONE: %0d checks, %0d errors", checks, errors);
        if (errors == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
        $finish;
    end

    initial begin
        #5_000_000;
        $display("RESULT: FAIL (timeout)");
        $finish;
    end
endmodule
