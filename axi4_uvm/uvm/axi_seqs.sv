// Random mix of reads and writes (about 10% out of range, from the item constraints)
class axi_random_seq extends uvm_sequence #(axi_item);
    `uvm_object_utils(axi_random_seq)
    int unsigned n = 200;
    function new(string name = "axi_random_seq"); super.new(name); endfunction
    task body();
        repeat (n) begin
            req = axi_item::type_id::create("req");
            start_item(req);
            if (!req.randomize()) `uvm_fatal("SEQ", "randomize failed")
            finish_item(req);
        end
    endtask
endclass

// Write N random bursts, then read every one back. Catches lost or corrupted data.
class axi_wr_rd_seq extends uvm_sequence #(axi_item);
    `uvm_object_utils(axi_wr_rd_seq)
    int unsigned n = 50;
    function new(string name = "axi_wr_rd_seq"); super.new(name); endfunction
    task body();
        axi_item wr[$];
        repeat (n) begin
            req = axi_item::type_id::create("req");
            start_item(req);
            if (!req.randomize() with { is_write == 1; oor == 0; }) `uvm_fatal("SEQ", "randomize failed")
            finish_item(req);
            wr.push_back(req);
        end
        foreach (wr[i]) begin
            req = axi_item::type_id::create("req");
            start_item(req);
            if (!req.randomize() with { is_write == 0; addr == wr[i].addr; len == wr[i].len;
                                        size == wr[i].size; burst == wr[i].burst; oor == 0; })
                `uvm_fatal("SEQ", "randomize failed")
            finish_item(req);
        end
    endtask
endclass

// Single-beat writes with random byte strobes, each read straight back
class axi_strobe_seq extends uvm_sequence #(axi_item);
    `uvm_object_utils(axi_strobe_seq)
    int unsigned n = 40;
    function new(string name = "axi_strobe_seq"); super.new(name); endfunction
    task body();
        bit [15:0] a;
        repeat (n) begin
            a = 16'($urandom_range(0, 16383)) & ~16'd3;
            repeat (3) begin   // same word, different strobes
                req = axi_item::type_id::create("req");
                start_item(req);
                if (!req.randomize() with { is_write == 1; oor == 0; addr == a; len == 0; size == 2; })
                    `uvm_fatal("SEQ", "randomize failed")
                finish_item(req);
            end
            req = axi_item::type_id::create("req");
            start_item(req);
            if (!req.randomize() with { is_write == 0; oor == 0; addr == a; len == 0; size == 2; })
                `uvm_fatal("SEQ", "randomize failed")
            finish_item(req);
        end
    endtask
endclass

// Only out-of-range accesses: every response must be SLVERR
class axi_error_seq extends uvm_sequence #(axi_item);
    `uvm_object_utils(axi_error_seq)
    int unsigned n = 40;
    function new(string name = "axi_error_seq"); super.new(name); endfunction
    task body();
        repeat (n) begin
            req = axi_item::type_id::create("req");
            start_item(req);
            if (!req.randomize() with { oor == 1; }) `uvm_fatal("SEQ", "randomize failed")
            finish_item(req);
        end
    endtask
endclass
