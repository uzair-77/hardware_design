`timescale 1ns/1ps
// AXI4 interface with clocking blocks (driver drives cb, monitor samples mon_cb)
interface axi_if #(parameter int ADDR_W = 16, DATA_W = 32, ID_W = 4)
                  (input logic aclk, input logic aresetn);
    logic [ID_W-1:0]     awid, bid, arid, rid;
    logic [ADDR_W-1:0]   awaddr, araddr;
    logic [7:0]          awlen, arlen;
    logic [2:0]          awsize, arsize;
    logic [1:0]          awburst, arburst, bresp, rresp;
    logic                awvalid, awready, wvalid, wready, wlast, bvalid, bready;
    logic                arvalid, arready, rvalid, rready, rlast;
    logic [DATA_W-1:0]   wdata, rdata;
    logic [DATA_W/8-1:0] wstrb;

    clocking cb @(posedge aclk);
        default input #1step output #1;
        output awid, awaddr, awlen, awsize, awburst, awvalid;
        output wdata, wstrb, wlast, wvalid, bready;
        output arid, araddr, arlen, arsize, arburst, arvalid, rready;
        input  awready, wready, bid, bresp, bvalid, arready, rid, rdata, rresp, rlast, rvalid;
    endclocking

    clocking mon_cb @(posedge aclk);
        default input #1step;
        input awid, awaddr, awlen, awsize, awburst, awvalid, awready;
        input wdata, wstrb, wlast, wvalid, wready;
        input bid, bresp, bvalid, bready;
        input arid, araddr, arlen, arsize, arburst, arvalid, arready;
        input rid, rdata, rresp, rlast, rvalid, rready;
    endclocking

    // idle values for the master side
    task automatic init_master();
        awvalid = 0; wvalid = 0; bready = 0; arvalid = 0; rready = 0;
        awid = 0; awaddr = 0; awlen = 0; awsize = 0; awburst = 0;
        wdata = 0; wstrb = 0; wlast = 0;
        arid = 0; araddr = 0; arlen = 0; arsize = 0; arburst = 0;
    endtask
endinterface
