sim:
	verilator --binary --timing -Wall -Wno-fatal -Irtl --top-module tb_uart_echo \
	  rtl/uart_tx.sv rtl/uart_rx.sv rtl/uart_echo_top.sv tb/tb_uart_echo.sv -o sim
	./obj_dir/sim

clean:
	rm -rf obj_dir
