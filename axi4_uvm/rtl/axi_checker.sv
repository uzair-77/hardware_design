`timescale 1ns/1ps
// Protocol assertions (SVA). Plain ports so it works in any simulator.
module axi_checker #(
    parameter int ADDR_W = 16, DATA_W = 32, ID_W = 4
)(
    input logic aclk, aresetn,
    input logic [ID_W-1:0] awid,  input logic [ADDR_W-1:0] awaddr,
    input logic [7:0] awlen,      input logic [2:0] awsize, input logic [1:0] awburst,
    input logic awvalid, awready,
    input logic [DATA_W-1:0] wdata, input logic [DATA_W/8-1:0] wstrb,
    input logic wlast, wvalid, wready,
    input logic [ID_W-1:0] bid,   input logic [1:0] bresp, input logic bvalid, bready,
    input logic [ID_W-1:0] arid,  input logic [ADDR_W-1:0] araddr,
    input logic [7:0] arlen,      input logic [2:0] arsize, input logic [1:0] arburst,
    input logic arvalid, arready,
    input logic [ID_W-1:0] rid,   input logic [DATA_W-1:0] rdata,
    input logic [1:0] rresp,      input logic rlast, rvalid, rready
);
    default clocking cb @(posedge aclk); endclocking

    // 1. VALID must stay high, and the payload stable, until READY (all 5 channels)
    a_aw_stable: assert property (disable iff (!aresetn) awvalid && !awready |=> awvalid && $stable({awid,awaddr,awlen,awsize,awburst}));
    a_w_stable:  assert property (disable iff (!aresetn) wvalid  && !wready  |=> wvalid  && $stable({wdata,wstrb,wlast}));
    a_b_stable:  assert property (disable iff (!aresetn) bvalid  && !bready  |=> bvalid  && $stable({bid,bresp}));
    a_ar_stable: assert property (disable iff (!aresetn) arvalid && !arready |=> arvalid && $stable({arid,araddr,arlen,arsize,arburst}));
    a_r_stable:  assert property (disable iff (!aresetn) rvalid  && !rready  |=> rvalid  && $stable({rid,rdata,rresp,rlast}));

    // 2. no X on control signals once out of reset
    a_no_x: assert property (disable iff (!aresetn) !$isunknown({awvalid,awready,wvalid,wready,bvalid,bready,
                                          arvalid,arready,rvalid,rready}));

    // 3. valid signals are low during reset
    a_reset: assert property (!aresetn |=> !awvalid && !wvalid && !arvalid && !bvalid && !rvalid);

    // 4. burst type 2'b11 is reserved
    a_awburst: assert property (disable iff (!aresetn) awvalid |-> awburst != 2'b11);
    a_arburst: assert property (disable iff (!aresetn) arvalid |-> arburst != 2'b11);

    // 5. WRAP length must be 2, 4, 8 or 16 beats
    a_wrap_aw: assert property (disable iff (!aresetn) awvalid && awburst == 2'b10 |-> awlen inside {1,3,7,15});
    a_wrap_ar: assert property (disable iff (!aresetn) arvalid && arburst == 2'b10 |-> arlen inside {1,3,7,15});

    // 6. no INCR burst crosses a 4 KB boundary
    a_4k_aw: assert property (disable iff (!aresetn) awvalid && awburst == 2'b01 |->
                 (int'(awaddr[11:0]) + ((int'(awlen) + 1) << awsize)) <= 4096);
    a_4k_ar: assert property (disable iff (!aresetn) arvalid && arburst == 2'b01 |->
                 (int'(araddr[11:0]) + ((int'(arlen) + 1) << arsize)) <= 4096);

    // 7. WLAST on the right beat
    int unsigned w_beats;
    logic [7:0]  w_len_q;
    always_ff @(posedge aclk) begin
        if (!aresetn) w_beats <= 0;
        else begin
            if (awvalid && awready) w_len_q <= awlen;
            if (wvalid && wready) w_beats <= wlast ? 0 : w_beats + 1;
        end
    end
    // WLAST pairs with the AW already accepted (DUT waits for AW before WREADY)
    a_wlast: assert property (disable iff (!aresetn) wvalid && wready |-> (wlast == (w_beats == int'(w_len_q))));

    // functional cover points for the checker itself
    c_b_slverr: cover property (disable iff (!aresetn) bvalid && bready && bresp == 2'b10);
    c_r_slverr: cover property (disable iff (!aresetn) rvalid && rready && rresp == 2'b10);
    c_overlap:  cover property (disable iff (!aresetn) wvalid && wready && rvalid && rready);
endmodule
