# Requires the project created by create_project.tcl to be open.
set_property top fir_uart_top [get_filesets sources_1]
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
puts "Implementation status: [get_property STATUS [get_runs impl_1]]"
