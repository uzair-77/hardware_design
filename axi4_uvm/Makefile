# TEST = axi_random_test | axi_wr_rd_test | axi_strobe_test | axi_error_test | axi_regress_test
TEST ?= axi_regress_test
SEED ?= 1
SRC  = rtl/axi4_mem.sv rtl/axi_checker.sv uvm/axi_if.sv uvm/axi_pkg.sv uvm/tb_top.sv
INC  = +incdir+uvm

# Open-source check of the DUT + assertions only (no UVM). Runs anywhere with Verilator 5.
smoke:
	verilator --binary --timing --assert -Wno-fatal -Wno-lint -Wno-style -Irtl \
	  --top-module dut_smoke rtl/axi4_mem.sv rtl/axi_checker.sv tb/dut_smoke.sv -o smoke
	./obj_dir/smoke

# Questa
questa:
	vlog -sv -mfcu $(INC) -cover bcesf $(SRC)
	vsim -c -coverage -sv_seed $(SEED) tb_top +UVM_TESTNAME=$(TEST) \
	  -do "coverage save -onexit cov_$(TEST).ucdb; run -all; quit -f"
	vcover report -details cov_$(TEST).ucdb > cov_$(TEST).txt

# Synopsys VCS
vcs:
	vcs -sverilog -full64 -ntb_opts uvm-1.2 -timescale=1ns/1ps -cm line+cond+fsm+tgl+assert \
	  $(INC) $(SRC) -o simv
	./simv +UVM_TESTNAME=$(TEST) +ntb_random_seed=$(SEED) -cm line+cond+fsm+tgl+assert

# Cadence Xcelium
xrun:
	xrun -64bit -sv -uvm -timescale 1ns/1ps -coverage all $(INC) $(SRC) \
	  +UVM_TESTNAME=$(TEST) -svseed $(SEED)

clean:
	rm -rf obj_dir work transcript *.ucdb simv* csrc ucli.key vcs.key xcelium.d cov_work vsim.wlf cov_*.txt
