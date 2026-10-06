`timescale 1ns/1ps
module tb_top;
    import uvm_pkg::*;
    import axi_pkg::*;

    logic aclk = 0, aresetn = 0;
    always #5 aclk = ~aclk;
    initial begin
        repeat (5) @(posedge aclk);
        aresetn <= 1;
    end

    axi_if vif (.aclk, .aresetn);

    axi4_mem dut (
        .aclk, .aresetn,
        .awid(vif.awid), .awaddr(vif.awaddr), .awlen(vif.awlen), .awsize(vif.awsize),
        .awburst(vif.awburst), .awvalid(vif.awvalid), .awready(vif.awready),
        .wdata(vif.wdata), .wstrb(vif.wstrb), .wlast(vif.wlast),
        .wvalid(vif.wvalid), .wready(vif.wready),
        .bid(vif.bid), .bresp(vif.bresp), .bvalid(vif.bvalid), .bready(vif.bready),
        .arid(vif.arid), .araddr(vif.araddr), .arlen(vif.arlen), .arsize(vif.arsize),
        .arburst(vif.arburst), .arvalid(vif.arvalid), .arready(vif.arready),
        .rid(vif.rid), .rdata(vif.rdata), .rresp(vif.rresp), .rlast(vif.rlast),
        .rvalid(vif.rvalid), .rready(vif.rready)
    );

    // protocol assertions watch the same wires
    axi_checker chk (
        .aclk, .aresetn,
        .awid(vif.awid), .awaddr(vif.awaddr), .awlen(vif.awlen), .awsize(vif.awsize),
        .awburst(vif.awburst), .awvalid(vif.awvalid), .awready(vif.awready),
        .wdata(vif.wdata), .wstrb(vif.wstrb), .wlast(vif.wlast),
        .wvalid(vif.wvalid), .wready(vif.wready),
        .bid(vif.bid), .bresp(vif.bresp), .bvalid(vif.bvalid), .bready(vif.bready),
        .arid(vif.arid), .araddr(vif.araddr), .arlen(vif.arlen), .arsize(vif.arsize),
        .arburst(vif.arburst), .arvalid(vif.arvalid), .arready(vif.arready),
        .rid(vif.rid), .rdata(vif.rdata), .rresp(vif.rresp), .rlast(vif.rlast),
        .rvalid(vif.rvalid), .rready(vif.rready)
    );

    initial begin
        uvm_config_db#(virtual axi_if)::set(null, "*", "vif", vif);
        run_test();
    end
endmodule
