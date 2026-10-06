`timescale 1ns/1ps
// AXI4 slave memory (DUT for the UVM env).
//  - 32-bit data, 16-bit address, 16 KB of memory at 0x0000-0x3FFF
//  - FIXED / INCR / WRAP bursts, byte strobes, aligned addresses
//  - one write and one read in flight at a time (writes and reads can overlap)
//  - access outside 16 KB returns SLVERR and writes nothing
//  - STALL=1 adds random wait states on WREADY and RVALID
module axi4_mem #(
    parameter int ADDR_W    = 16,
    parameter int DATA_W    = 32,
    parameter int ID_W      = 4,
    parameter int MEM_BYTES = 16384,
    parameter bit STALL     = 1
)(
    input  logic              aclk,
    input  logic              aresetn,
    // write address
    input  logic [ID_W-1:0]   awid,
    input  logic [ADDR_W-1:0] awaddr,
    input  logic [7:0]        awlen,
    input  logic [2:0]        awsize,
    input  logic [1:0]        awburst,
    input  logic              awvalid,
    output logic              awready,
    // write data
    input  logic [DATA_W-1:0] wdata,
    input  logic [DATA_W/8-1:0] wstrb,
    input  logic              wlast,
    input  logic              wvalid,
    output logic              wready,
    // write response
    output logic [ID_W-1:0]   bid,
    output logic [1:0]        bresp,
    output logic              bvalid,
    input  logic              bready,
    // read address
    input  logic [ID_W-1:0]   arid,
    input  logic [ADDR_W-1:0] araddr,
    input  logic [7:0]        arlen,
    input  logic [2:0]        arsize,
    input  logic [1:0]        arburst,
    input  logic              arvalid,
    output logic              arready,
    // read data
    output logic [ID_W-1:0]   rid,
    output logic [DATA_W-1:0] rdata,
    output logic [1:0]        rresp,
    output logic              rlast,
    output logic              rvalid,
    input  logic              rready
);
    localparam int BPW    = DATA_W/8;
    localparam int WORDS  = MEM_BYTES/BPW;
    localparam logic [1:0] FIXED = 2'b00, INCR = 2'b01, WRAP = 2'b10;
    localparam logic [1:0] OKAY  = 2'b00, SLVERR = 2'b10;

    logic [DATA_W-1:0] mem [WORDS];
    initial for (int i = 0; i < WORDS; i++) mem[i] = '0;

    // next beat address, from the AXI spec
    function automatic logic [ADDR_W-1:0] next_addr(
        input logic [ADDR_W-1:0] a, input logic [2:0] size,
        input logic [7:0] len, input logic [1:0] burst);
        logic [ADDR_W-1:0] nbytes, total;
        nbytes = ADDR_W'(1) << size;
        total  = ADDR_W'(len + 9'd1) << size;
        case (burst)
            INCR:    next_addr = a + nbytes;
            WRAP:    next_addr = (a & ~(total - 1'b1)) | ((a + nbytes) & (total - 1'b1));
            default: next_addr = a;
        endcase
    endfunction

    // small LFSR for random wait states
    logic [15:0] lfsr;
    always_ff @(posedge aclk)
        if (!aresetn) lfsr <= 16'hACE1;
        else          lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

    // ---------------- write path ----------------
    typedef enum logic [1:0] {W_IDLE, W_DATA, W_RESP} wstate_t;
    wstate_t wst;
    logic [ID_W-1:0]   w_id;
    logic [ADDR_W-1:0] w_addr;
    logic [7:0]        w_len;
    logic [2:0]        w_size;
    logic [1:0]        w_burst;
    logic              w_err;

    assign awready = (wst == W_IDLE);
    assign wready  = (wst == W_DATA) && (!STALL || lfsr[0] || lfsr[3]);
    assign bvalid  = (wst == W_RESP);
    assign bid     = w_id;
    assign bresp   = w_err ? SLVERR : OKAY;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            wst <= W_IDLE;
            w_err <= 1'b0;
        end else begin
            case (wst)
                W_IDLE: if (awvalid) begin
                    w_id <= awid;  w_addr <= awaddr; w_len <= awlen;
                    w_size <= awsize; w_burst <= awburst;
                    w_err <= 1'b0;
                    wst <= W_DATA;
                end
                W_DATA: if (wvalid && wready) begin
                    if (int'(w_addr) >= MEM_BYTES) w_err <= 1'b1;
                    else begin
                        for (int i = 0; i < BPW; i++)
                            if (wstrb[i]) mem[w_addr/BPW][8*i +: 8] <= wdata[8*i +: 8];
                    end
                    w_addr <= next_addr(w_addr, w_size, w_len, w_burst);
                    if (wlast) wst <= W_RESP;
                end
                W_RESP: if (bready) wst <= W_IDLE;
                default: wst <= W_IDLE;
            endcase
        end
    end

    // ---------------- read path ----------------
    typedef enum logic {R_IDLE, R_DATA} rstate_t;
    rstate_t rst_s;
    logic [ID_W-1:0]   r_id;
    logic [ADDR_W-1:0] r_addr;
    logic [7:0]        r_len, r_cnt;
    logic [2:0]        r_size;
    logic [1:0]        r_burst;

    assign arready = (rst_s == R_IDLE);
    assign rid     = r_id;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            rst_s  <= R_IDLE;
            rvalid <= 1'b0;
            rlast  <= 1'b0;
            rdata  <= '0;
            rresp  <= OKAY;
        end else begin
            case (rst_s)
                R_IDLE: if (arvalid) begin
                    r_id <= arid; r_addr <= araddr; r_len <= arlen;
                    r_size <= arsize; r_burst <= arburst; r_cnt <= 8'd0;
                    rst_s <= R_DATA;
                end
                R_DATA: begin
                    if (!rvalid && (!STALL || lfsr[1] || lfsr[4])) begin
                        // present next beat
                        rvalid <= 1'b1;
                        rlast  <= (r_cnt == r_len);
                        if (int'(r_addr) >= MEM_BYTES) begin
                            rdata <= '0;  rresp <= SLVERR;
                        end else begin
                            rdata <= mem[r_addr/BPW];  rresp <= OKAY;
                        end
                    end else if (rvalid && rready) begin
                        rvalid <= 1'b0;
                        r_addr <= next_addr(r_addr, r_size, r_len, r_burst);
                        r_cnt  <= r_cnt + 8'd1;
                        if (rlast) rst_s <= R_IDLE;
                    end
                end
            endcase
        end
    end
endmodule
