// Watches the bus and rebuilds each burst into an axi_item.
// Also checks protocol details that need transaction context (ids, last flags).
class axi_monitor extends uvm_monitor;
    `uvm_component_utils(axi_monitor)
    virtual axi_if vif;
    uvm_analysis_port #(axi_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        ap = new("ap", this);
        if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "axi_if not set for monitor")
    endfunction

    task run_phase(uvm_phase phase);
        @(posedge vif.aresetn);
        fork
            mon_write();
            mon_read();
        join
    endtask

    task mon_write();
        axi_item t;
        forever begin
            // AW handshake
            do @(vif.mon_cb); while (!(vif.mon_cb.awvalid && vif.mon_cb.awready));
            t = axi_item::type_id::create("wr_item");
            t.is_write = 1;
            t.id = vif.mon_cb.awid;       t.addr = vif.mon_cb.awaddr;
            t.len = vif.mon_cb.awlen;     t.size = vif.mon_cb.awsize;
            t.burst = vif.mon_cb.awburst;
            t.data = new[t.len + 1];      t.strb = new[t.len + 1];
            // W beats
            for (int i = 0; i <= t.len; ) begin
                @(vif.mon_cb);
                if (vif.mon_cb.wvalid && vif.mon_cb.wready) begin
                    t.data[i] = vif.mon_cb.wdata;
                    t.strb[i] = vif.mon_cb.wstrb;
                    if (vif.mon_cb.wlast != (i == t.len))
                        `uvm_error("MON", $sformatf("WLAST wrong on beat %0d of %0d", i, t.len + 1))
                    i++;
                end
            end
            // B response
            do @(vif.mon_cb); while (!(vif.mon_cb.bvalid && vif.mon_cb.bready));
            t.resp = new[1];
            t.resp[0] = vif.mon_cb.bresp;
            if (vif.mon_cb.bid != t.id)
                `uvm_error("MON", $sformatf("BID %0d != AWID %0d", vif.mon_cb.bid, t.id))
            t.oor = (t.addr >= axi_item::MEM_BYTES);
            ap.write(t);
        end
    endtask

    task mon_read();
        axi_item t;
        forever begin
            do @(vif.mon_cb); while (!(vif.mon_cb.arvalid && vif.mon_cb.arready));
            t = axi_item::type_id::create("rd_item");
            t.is_write = 0;
            t.id = vif.mon_cb.arid;       t.addr = vif.mon_cb.araddr;
            t.len = vif.mon_cb.arlen;     t.size = vif.mon_cb.arsize;
            t.burst = vif.mon_cb.arburst;
            t.data = new[t.len + 1];      t.resp = new[t.len + 1];
            for (int i = 0; i <= t.len; ) begin
                @(vif.mon_cb);
                if (vif.mon_cb.rvalid && vif.mon_cb.rready) begin
                    t.data[i] = vif.mon_cb.rdata;
                    t.resp[i] = vif.mon_cb.rresp;
                    if (vif.mon_cb.rlast != (i == t.len))
                        `uvm_error("MON", $sformatf("RLAST wrong on beat %0d of %0d", i, t.len + 1))
                    if (vif.mon_cb.rid != t.id)
                        `uvm_error("MON", $sformatf("RID %0d != ARID %0d", vif.mon_cb.rid, t.id))
                    i++;
                end
            end
            t.oor = (t.addr >= axi_item::MEM_BYTES);
            ap.write(t);
        end
    endtask
endclass
