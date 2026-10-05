// UART receiver: 8N1, LSB first. Samples in the middle of each bit.
module uart_rx #(
    parameter int CLKS_PER_BIT = 868
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       rx,
    output logic [7:0] data,
    output logic       valid,        // 1-cycle pulse, data is good
    output logic       frame_err     // 1-cycle pulse, stop bit was not 1
);
    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state;
    logic [$clog2(CLKS_PER_BIT)-1:0] clk_cnt;
    logic [2:0] bit_idx;
    logic [7:0] shreg;
    logic rx_s1, rx_s2;              // 2-FF synchronizer (rx is asynchronous)

    always_ff @(posedge clk) begin
        rx_s1 <= rx;
        rx_s2 <= rx_s1;
    end

    always_ff @(posedge clk) begin
        valid     <= 1'b0;
        frame_err <= 1'b0;
        if (rst) begin
            state   <= IDLE;
            clk_cnt <= '0;
            bit_idx <= '0;
        end else begin
            case (state)
                IDLE: begin
                    clk_cnt <= '0;
                    if (!rx_s2) state <= START;   // falling edge = start bit
                end
                START: begin
                    // wait half a bit, then re-check the start bit is still low
                    if (clk_cnt == (CLKS_PER_BIT-1)/2) begin
                        clk_cnt <= '0;
                        if (!rx_s2) begin
                            bit_idx <= '0;
                            state   <= DATA;
                        end else state <= IDLE;   // glitch, ignore
                    end else clk_cnt <= clk_cnt + 1'b1;
                end
                DATA: begin
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt        <= '0;
                        shreg[bit_idx] <= rx_s2;
                        if (bit_idx == 3'd7) state <= STOP;
                        else bit_idx <= bit_idx + 1'b1;
                    end else clk_cnt <= clk_cnt + 1'b1;
                end
                STOP: begin
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt   <= '0;
                        data      <= shreg;
                        valid     <= rx_s2;
                        frame_err <= !rx_s2;
                        state     <= IDLE;
                    end else clk_cnt <= clk_cnt + 1'b1;
                end
            endcase
        end
    end
endmodule
