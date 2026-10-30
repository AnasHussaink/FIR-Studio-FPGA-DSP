

# Arty 100 MHz clock
set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk [get_ports clk]

# USB-UART: PC to FPGA
set_property PACKAGE_PIN A9 [get_ports uart_rx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx_pin]

# USB-UART: FPGA to PC
set_property PACKAGE_PIN D10 [get_ports uart_tx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_pin]

# BTN0: active-high reset
set_property PACKAGE_PIN D9 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]
