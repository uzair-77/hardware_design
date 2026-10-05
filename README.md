# UART echo: simulation and FPGA bring-up

A small, typical emulation/bring-up task: build a UART, prove it in simulation, then run it on a board.

## What it does
- `rtl/uart_tx.sv` sends 8N1 bytes (start bit, 8 data bits LSB first, stop bit).
- `rtl/uart_rx.sv` receives them. It syncs the input with 2 flops, samples mid-bit, and flags a bad stop bit.
- `rtl/uart_echo_top.sv` sends back every byte it receives. `led_err` latches on a framing error.
- `tb/tb_uart_echo.sv` acts as the host PC. It sends 5 corner-case bytes and 20 random bytes, checks each echo, and checks the framing-error case.
- `fpga/basys3.xdc` has the pin constraints for a Basys3 board.

## Run
    make sim      # needs Verilator 5+
Expected last line: `RESULT: PASS`.

## Design choices (for questions)
- Baud = clock / CLKS_PER_BIT (100 MHz / 868 = 115200). The testbench uses 16 to keep sim short.
- RX input is asynchronous, so it goes through a 2-flop synchronizer to avoid metastability.
- Sampling mid-bit gives the most margin against baud mismatch. The start bit is re-checked at its middle to reject glitches.
- A 1-byte hold register in the top stops a byte being lost if TX is still busy. Back-to-back bytes at full rate would still need a FIFO.
- I checked the testbench can fail: flipping one RX bit makes it report FAIL.

## On a board
Synthesize `rtl/*.sv` with `fpga/basys3.xdc` in Vivado, program it, open a serial terminal at 115200 8N1, and type. Characters should echo. Not run here (no Vivado in this environment).
