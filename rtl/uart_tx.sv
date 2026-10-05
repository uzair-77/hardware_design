// UART transmitter: 8N1, LSB first.
module uart_tx #(
    parameter int CLKS_PER_BIT = 868   // 100 MHz / 115200
)(
    input  logic       clk,
    input  logic       rst,
    input  logic [7:0] data,
    input  logic       start,   // pulse 1 cycle to send data
    output logic       tx,
    output logic       busy
);
    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state;
    logic [$clog2(CLKS_PER_BIT)-1:0] clk_cnt;
    logic [2:0] bit_idx;
    logic [7:0] shreg;

    assign busy = (state != IDLE);

    always_ff @(posedge clk) begin
        if (rst) begin
            state   <= IDLE;
            tx      <= 1'b1;
            clk_cnt <= '0;
            bit_idx <= '0;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    if (start) begin
                        shreg   <= data;
                        clk_cnt <= '0;
                        state   <= START;
                    end
                end
                START: begin
                    tx <= 1'b0;
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= '0;
                        bit_idx <= '0;
                        state   <= DATA;
                    end else clk_cnt <= clk_cnt + 1'b1;
                end
                DATA: begin
                    tx <= shreg[bit_idx];
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= '0;
                        if (bit_idx == 3'd7) state <= STOP;
                        else bit_idx <= bit_idx + 1'b1;
                    end else clk_cnt <= clk_cnt + 1'b1;
                end
                STOP: begin
                    tx <= 1'b1;
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= '0;
                        state   <= IDLE;
                    end else clk_cnt <= clk_cnt + 1'b1;
                end
            endcase
        end
    end
endmodule
