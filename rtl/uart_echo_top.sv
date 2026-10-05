// FPGA top: echoes every received byte back. Used for board bring-up.
module uart_echo_top #(
    parameter int CLKS_PER_BIT = 868
)(
    input  logic clk,
    input  logic rst,
    input  logic uart_rx_pin,
    output logic uart_tx_pin,
    output logic led_err          // lights on a framing error (latched)
);
    logic [7:0] rx_data;
    logic       rx_valid, rx_ferr, tx_busy;

    // one-byte holding register so a byte is not lost if tx is still busy
    logic [7:0] hold;
    logic       hold_full, tx_start;

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (
        .clk, .rst, .rx(uart_rx_pin),
        .data(rx_data), .valid(rx_valid), .frame_err(rx_ferr)
    );

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
        .clk, .rst, .data(hold), .start(tx_start),
        .tx(uart_tx_pin), .busy(tx_busy)
    );

    always_ff @(posedge clk) begin
        tx_start <= 1'b0;
        if (rst) begin
            hold_full <= 1'b0;
            led_err   <= 1'b0;
        end else begin
            if (rx_valid) begin
                hold      <= rx_data;
                hold_full <= 1'b1;
            end
            if (hold_full && !tx_busy && !tx_start) begin
                tx_start  <= 1'b1;
                hold_full <= 1'b0;
            end
            if (rx_ferr) led_err <= 1'b1;
        end
    end
endmodule
