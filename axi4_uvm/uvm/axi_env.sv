class axi_env extends uvm_env;
    `uvm_component_utils(axi_env)
    axi_agent      agent;
    axi_scoreboard scb;
    axi_coverage   cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        agent = axi_agent::type_id::create("agent", this);
        scb   = axi_scoreboard::type_id::create("scb", this);
        cov   = axi_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        agent.mon.ap.connect(scb.imp);
        agent.mon.ap.connect(cov.analysis_export);
    endfunction
endclass
