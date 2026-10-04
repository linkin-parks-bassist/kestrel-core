# Run from an empty build directory: gw_sh /path/to/kestrel_core/build_gowin.tcl
# Generated impl/ outputs are written beneath the working directory.
set core_root [file dirname [file normalize [info script]]]
set_device GW2AR-LV18QN88C8/I7
add_file [file join $core_root src/atypes.v]
add_file [file join $core_root src/biquad.v]
add_file [file join $core_root src/branch_router.v]
add_file [file join $core_root src/build_registers.v]
add_file [file join $core_root src/commit_master.v]
add_file [file join $core_root src/commit_stage.v]
add_file [file join $core_root src/controller.v]
add_file [file join $core_root src/core.v]
add_file [file join $core_root src/delay_master.v]
add_file [file join $core_root src/engine.v]
add_file [file join $core_root src/ext_rw.v]
add_file [file join $core_root src/fifo.v]
add_file [file join $core_root src/filter.v]
add_file [file join $core_root src/polynomial.v]
add_file [file join $core_root src/gowin_rpll/gowin_rpll.v]
add_file [file join $core_root src/health_monitor.v]
add_file [file join $core_root src/i2s.v]
add_file [file join $core_root src/instr_dec.v]
add_file [file join $core_root src/instr_fetch_decode.v]
add_file [file join $core_root src/linterp.v]
add_file [file join $core_root src/lut.v]
add_file [file join $core_root src/lut_master.v]
add_file [file join $core_root src/madd.v]
add_file [file join $core_root src/misc.v]
add_file [file join $core_root src/mixer.v]
add_file [file join $core_root src/operand_fetch.v]
add_file [file join $core_root src/pipeline.v]
add_file [file join $core_root src/regfile.v]
add_file [file join $core_root src/rr_arbiter.v]
add_file [file join $core_root src/sdram.v]
add_file [file join $core_root src/sdram_interface.v]
add_file [file join $core_root src/skid_buffer.v]
add_file [file join $core_root src/spi.v]
add_file [file join $core_root src/top.v]
add_file [file join $core_root dude.cst]
add_file [file join $core_root dude.sdc]
add_file [file join $core_root src/pwm.v]
add_file [file join $core_root src/preprocessing.v]
add_file [file join $core_root src/postprocessing.v]
set_option -include_path [file join $core_root include]
set_option -verilog_std sysv2017
set_option -top_module top
set_option -output_base_name kestrel
set_option -use_sspi_as_gpio 1
set_option -timing_driven 1
set_option -route_option 1
run all
