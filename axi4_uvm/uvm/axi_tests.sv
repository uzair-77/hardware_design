class axi_base_test extends uvm_test;
    `uvm_component_utils(axi_base_test)
    axi_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        env = axi_env::type_id::create("env", this);
    endfunction

    // derived tests override this
    virtual task run_seqs();
    endtask

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        run_seqs();
        repeat (50) @(env.agent.drv.vif.cb);   // let the last response drain
        phase.drop_objection(this);
    endtask
endclass

class axi_random_test extends axi_base_test;
    `uvm_component_utils(axi_random_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_seqs();
        axi_random_seq s = axi_random_seq::type_id::create("s");
        s.n = 500;
        s.start(env.agent.sqr);
    endtask
endclass

class axi_wr_rd_test extends axi_base_test;
    `uvm_component_utils(axi_wr_rd_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_seqs();
        axi_wr_rd_seq s = axi_wr_rd_seq::type_id::create("s");
        s.start(env.agent.sqr);
    endtask
endclass

class axi_strobe_test extends axi_base_test;
    `uvm_component_utils(axi_strobe_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_seqs();
        axi_strobe_seq s = axi_strobe_seq::type_id::create("s");
        s.start(env.agent.sqr);
    endtask
endclass

class axi_error_test extends axi_base_test;
    `uvm_component_utils(axi_error_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_seqs();
        axi_error_seq s = axi_error_seq::type_id::create("s");
        s.start(env.agent.sqr);
    endtask
endclass

// Everything, one after another: used for the coverage report
class axi_regress_test extends axi_base_test;
    `uvm_component_utils(axi_regress_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_seqs();
        axi_wr_rd_seq    s1 = axi_wr_rd_seq::type_id::create("s1");
        axi_strobe_seq   s2 = axi_strobe_seq::type_id::create("s2");
        axi_error_seq    s3 = axi_error_seq::type_id::create("s3");
        axi_random_seq   s4 = axi_random_seq::type_id::create("s4");
        s4.n = 1000;
        s1.start(env.agent.sqr);
        s2.start(env.agent.sqr);
        s3.start(env.agent.sqr);
        s4.start(env.agent.sqr);
    endtask
endclass
