# Run from Vivado Tcl console: source scripts/create_project.tcl
set root [file normalize [file join [file dirname [info script]] ..]]
create_project fir_studio [file join $root build vivado] -part xc7a35ticsg324-1L -force
set_property target_language Verilog [current_project]
add_files [glob [file join $root rtl *.sv]]
add_files -fileset constrs_1 [file join $root constraints arty_a7_35t.xdc]
add_files -fileset sim_1 [glob [file join $root sim *.sv]]
set_property top fir_uart_top [get_filesets sources_1]
set_property top tb_fir_python [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "Project created. Run scripts/run_sim.tcl to stage test vectors and simulate."
