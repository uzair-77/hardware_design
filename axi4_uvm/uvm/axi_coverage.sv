// Functional coverage, sampled on every observed transaction.
class axi_coverage extends uvm_subscriber #(axi_item);
    `uvm_component_utils(axi_coverage)
    axi_item cur;
    bit [3:0] one_strb;

    covergroup cg_txn;
        option.per_instance = 1;
        cp_dir:   coverpoint cur.is_write { bins read = {0}; bins write = {1}; }
        cp_burst: coverpoint cur.burst    { bins fixed = {0}; bins incr = {1}; bins wrap = {2}; }
        cp_size:  coverpoint cur.size     { bins b1 = {0}; bins b2 = {1}; bins b4 = {2}; }
        cp_len:   coverpoint cur.len      { bins single = {0}; bins short_ = {[1:3]};
                                          bins mid = {[4:7]}; bins long_ = {[8:15]}; }
        cp_oor:   coverpoint cur.oor      { bins in_range = {0}; bins out_of_range = {1}; }
        cp_id:    coverpoint cur.id;
        cp_page:  coverpoint cur.addr[13:12] iff (!cur.oor) { bins page[] = {[0:3]}; }
        cp_resp:  coverpoint cur.resp[0]  { bins okay = {0}; bins slverr = {2}; }

        x_dir_burst: cross cp_dir, cp_burst;
        x_burst_len: cross cp_burst, cp_len {
            illegal_bins wrap_single = binsof(cp_burst.wrap) && binsof(cp_len.single);
        }
        x_dir_size:  cross cp_dir, cp_size;
        x_dir_oor:   cross cp_dir, cp_oor;
    endgroup

    covergroup cg_strobe;
        cp_strb: coverpoint one_strb {
            bins none   = {4'h0};
            bins all    = {4'hF};
            bins single = {4'h1, 4'h2, 4'h4, 4'h8};
            bins lower  = {4'h3};
            bins upper  = {4'hC};
            bins other  = default;
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_txn = new();
        cg_strobe = new();
    endfunction

    function void write(axi_item t);
        cur = t;
        cg_txn.sample();
        if (t.is_write) foreach (t.strb[i]) begin one_strb = t.strb[i]; cg_strobe.sample(); end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("COV", $sformatf("txn coverage = %0.1f%%, strobe coverage = %0.1f%%",
                                   cg_txn.get_inst_coverage(), cg_strobe.get_inst_coverage()), UVM_NONE)
    endfunction
endclass
