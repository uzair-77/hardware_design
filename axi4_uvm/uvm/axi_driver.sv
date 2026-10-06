class axi_driver extends uvm_driver #(axi_item);
    `uvm_component_utils(axi_driver)
    virtual axi_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "axi_if not set for driver")
    endfunction

    task run_phase(uvm_phase phase);
        vif.init_master();
        @(posedge vif.aresetn);
        forever begin
            seq_item_port.get_next_item(req);
            repeat (req.gap) @(vif.cb);
            if (req.is_write) drive_write(req); else drive_read(req);
            seq_item_port.item_done();
        end
    endtask

    task drive_write(axi_item t);
        fork
            begin   // address channel
                vif.cb.awid <= t.id;       vif.cb.awaddr <= t.addr;
                vif.cb.awlen <= t.len;     vif.cb.awsize <= t.size;
                vif.cb.awburst <= t.burst; vif.cb.awvalid <= 1;
                do @(vif.cb); while (!vif.cb.awready);
                vif.cb.awvalid <= 0;
            end
            begin   // data channel
                for (int i = 0; i <= t.len; i++) begin
                    if ($urandom_range(0, 3) == 0) repeat ($urandom_range(1, 3)) @(vif.cb);
                    vif.cb.wdata <= t.data[i]; vif.cb.wstrb <= t.strb[i];
                    vif.cb.wlast <= (i == t.len); vif.cb.wvalid <= 1;
                    do @(vif.cb); while (!vif.cb.wready);
                    vif.cb.wvalid <= 0;
                end
                vif.cb.wlast <= 0;
            end
        join
        // response channel, with a random delay on BREADY
        repeat ($urandom_range(0, 3)) @(vif.cb);
        vif.cb.bready <= 1;
        do @(vif.cb); while (!vif.cb.bvalid);
        vif.cb.bready <= 0;
    endtask

    task drive_read(axi_item t);
        vif.cb.arid <= t.id;       vif.cb.araddr <= t.addr;
        vif.cb.arlen <= t.len;     vif.cb.arsize <= t.size;
        vif.cb.arburst <= t.burst; vif.cb.arvalid <= 1;
        do @(vif.cb); while (!vif.cb.arready);
        vif.cb.arvalid <= 0;
        for (int i = 0; i <= t.len; i++) begin
            if ($urandom_range(0, 3) == 0) repeat ($urandom_range(1, 3)) @(vif.cb);
            vif.cb.rready <= 1;
            do @(vif.cb); while (!vif.cb.rvalid);
            vif.cb.rready <= 0;
        end
    endtask
endclass
