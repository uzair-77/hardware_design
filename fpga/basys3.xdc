## Basys3 pins for uart_echo_top (100 MHz clock, 115200 baud)
set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 10.000 [get_ports clk]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports rst]          ;# center button
set_property -dict {PACKAGE_PIN B18 IOSTANDARD LVCMOS33} [get_ports uart_rx_pin]   ;# USB-UART RX
set_property -dict {PACKAGE_PIN A18 IOSTANDARD LVCMOS33} [get_ports uart_tx_pin]   ;# USB-UART TX
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports led_err]       ;# LD0
