---
status: green
revised_at: "2026-10-04T10:47:43+11:00"
---

Run the portable repository entry point build_gowin.tcl with the installed gw_sh wrapper from an empty build directory:

```bash
mkdir -p /tmp/kestrel-gowin-build
cd /tmp/kestrel-gowin-build
gw_sh /path/to/kestrel_core/build_gowin.tcl
```

The script resolves inputs relative to itself and runs the vendor flow, writing impl/ beneath the working directory. It targets carrier GW2AR-LV18QN88C8/I7, top module top, include path include, SystemVerilog sysv2017, dude.cst and dude.sdc. Host installation belongs to global:where/is/gowin/tooling/installed.md.

The tracked dude.gprj source list is incomplete: src/atypes.v must precede types_pkg consumers; src/pwm.v, src/preprocessing.v and src/postprocessing.v are required. The batch script includes them; the GUI project remains unreconciled. Template files and .vh includes are not independent compilation units. Synthesis warns about undriven ports and width mismatches; compilation does not establish correct behavior.

The script sets use_sspi_as_gpio=1 because dude.cst assigns sck to pin 55. Dedicated SSPI use rejects that location. This changes configuration, not physical pin assignment; JTAG and MSPI roles are preserved.

The current polynomial/SVF/read32 worktree completes synthesis, placement, routing, reports and bitstream generation. Resource/timing comparisons under the same device, input list, stated flow options and SYS_CLK 112.499-MHz constraint are:

| Source variant | Logic | Registers | BSRAM | DSP | Reported SYS_CLK Fmax | Setup/hold violated endpoints |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A → B → C comparison baseline | 15996/20736 | 13025/15915 | 20/46 | 9/24 | 112.525 MHz | 0 / 0 |
| C → B → A comparison baseline | 16197/20736 | 13025/15915 | 20/46 | 9/24 | 109.545 MHz | 158 / 0 |
| Prior C → B → A/Q15 SVF | 16539/20736 | 13023/15915 | 20/46 | 9/24 | 86.845 MHz | 1077 / 0 |
| Polynomial/SVF/read32, indexed lookup, route 0 | 15700/20736 | 12692/15915 | 18/46 | 9/24 | 95.302 MHz | 627 / 0 |
| Parallel busy selection, route 0 | 15982/20736 | 12692/15915 | 18/46 | 9/24 | 104.509 MHz | 328 / 0 |
| Parallel selection, route 1 | 15982/20736 | 12692/15915 | 18/46 | 9/24 | 112.572 MHz | 0 / 0 |
| Current: parallel selection, route 1, local control copies | 16037/20736 | 12720/15915 | 18/46 | 9/24 | 112.594 MHz | 0 / 0 |

The prior Q15 variant's worst setup slack is -2.626 ns from pipeline_a fetch_2 busy_bits to its channel-scoreboard clock enable. This is a vendor report, not a measured operating limit. David now requests timing closure; the current build meets the existing constraint without lowering the clock. Its worst setup slack is only +0.008 ns, on SVF product to factor_b, so this is a narrow report margin, not physical qualification. Generic crystal_d clock routing, synthesis warnings and timing coverage remain qualification questions.

Current artifacts are /tmp/kestrel-gowin-timing-control-copies/impl and /tmp/kestrel-gowin-timing-control-copies.log. Its impl/pnr/kestrel.fs has SHA-256 9ccf0dd5116c54994a9e3941222e3bf52919c168f348147cc7d67c910572557e. The default excludes ENABLE_FILTER and includes ENABLE_POLYNOMIAL/ENABLE_SVF, reporting capability mask 6 through read32. The batch source list includes src/polynomial.v and src/build_registers.v; the GUI list must include these too. Relative to the prior Q15 variant, the current whole image saves 502 logic cells, 303 registers and two BSRAMs, with DSP count unchanged. It is installed with full flash-write verification in /tmp/kestrel-timing-fpga-flash.log. Normal carrier power and ESP32 USB are restored, with Tang USB disconnected.

The Tcl explicitly sets timing_driven=1 and route_option=1. Timing-driven routing was already enabled by default; route option 1 spends more compile time seeking a better route than default option 0. Preserved per-branch enable/reset registers in src/core.v copy their original signals on the same cycles, including branch commit buffers. The scoreboard owner explains the equivalent parallel busy selection and limits on attributing the measured gain.

A full product shift in MADD's first shift stage, with the second retaining rounding, was tested but is not retained: that build reports 105.683 MHz and 128 setup violations. DSP primitive counts stayed unchanged; automatic DSP barrel-shifter mapping was not demonstrated. The original split shift is restored. Native DSP shift implementation remains unresolved; inspect supported primitives and actual mapping before selecting an implementation. Evidence: /tmp/kestrel-gowin-timing-whole-shift and /tmp/kestrel-timing-whole-shift-tests.log. The installed DSP guide's barrel-shifter description alone does not establish inference of a variable Verilog shift.

All eleven current Verilator targets pass in /tmp/kestrel-timing-final-full-tests.log. Compiled SVF and scratchpad fixtures also pass in /tmp/kestrel-timing-final-svf.log and /tmp/kestrel-timing-final-readback.log. These do not establish SPI clock-domain correctness, board timing or instrumented audio qualification.

Prior Q15 artifacts are /tmp/kestrel-gowin-svf-q15/impl and /tmp/kestrel-gowin-svf-q15.log. Bitstream impl/pnr/kestrel.fs has SHA-256 93f2793e76fd3685dcb8022f295defc5b4e635b820ceb9acbf80136c35525c0a. Reports are kestrel.rpt.txt and kestrel_tr_content.html in that directory. Comparison artifacts are /tmp/kestrel-gowin-cba/impl and /tmp/kestrel-gowin-core-check/impl. Temporary files are evidence locations, not permanent repository artifacts; regenerate with the recorded flow.

For flashing, disconnect external carrier power before connecting Tang USB-C; disconnect Tang USB before restoring normal power. The power restriction belongs to the superproject effect-verification specification. Routine powered diagnostics use ESP32 HIL.

openFPGALoader -b tangnano20k --detect identifies Gowin GW2A(R)-18(C), IDCODE 0x81b, using Sipeed FTDI2232 serial 2025030317. Flash detection identifies Winbond W25Q64, JEDEC 0xef4017, 8 MiB. The previous entire FPGA flash is backed up at /tmp/kestrel-fpga-before-svf.bin (8388608 bytes, SHA-256 92ea010ac6cd52dc5e6990fe697a81a905d9363f88d55111ba57e80fbf7dd412).

The installed FPGA image is the current polynomial/SVF/read32 artifact above. Its matching Interface firmware has ELF SHA-256 bdb20270635d37f60fbc7d44d7b13dac92b2307c4c8f8e7f591d3747ada40948 and hash-verified flash evidence in /tmp/kestrel-timing-read32-firmware-flash.log. Live UART/SPI checks in /tmp/kestrel-timing-read32-hil.log return 0x4b455354 at address 0 and 0x00000006 at address 4. FPGA status is 0x01, initialized with no timeout, programming, bad or command-error flags. The current selected preset is 14; dsp lists no effects. These checks establish installed-image boot and addressed-read transport, not active DSP/audio qualification of this image. David's clean low-cutoff/smooth-movement listening evidence belongs to the prior paired Q15 image; instrumented response/modulation/overload checks remain open.

Sources: portable Tcl, constraints, current synthesis/routing reports, loader detection/dump/verified-programming outputs and David's power/timing guidance.
