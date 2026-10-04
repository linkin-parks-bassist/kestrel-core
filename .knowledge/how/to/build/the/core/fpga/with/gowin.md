---
status: green
revised_at: "2026-10-04T13:51:18+11:00"
---

Run build_gowin.tcl with the installed gw_sh wrapper from an empty build directory:

```bash
mkdir -p /tmp/kestrel-gowin-build
cd /tmp/kestrel-gowin-build
gw_sh /path/to/kestrel_core/build_gowin.tcl
```

The script resolves inputs relative to itself and writes impl/ beneath the working directory. It stages the two checked sine/tanh hex files into the build directory's luts/ before synthesis, because RTL readmemh paths resolve there. Missing/unreadable source tables abort the Tcl rather than silently yielding an image. It targets carrier GW2AR-LV18QN88C8/I7, top, include/, sysv2017, dude.cst and dude.sdc. It sets timing_driven=1, route_option=1 and use_sspi_as_gpio=1 because dude.cst assigns SCK to pin 55. Dedicated SSPI rejects that location; JTAG/MSPI roles remain. Host installation belongs to global:where/is/gowin/tooling/installed.md.

The tracked dude.gprj source list matches all 39 batch Tcl inputs in order, including atypes.v before package consumers and pwm.v, preprocessing.v, postprocessing.v, polynomial.v and build_registers.v. XML parsing verifies every input exists. The saved GUI's separate compile/configuration settings still need reconciliation, especially SSPI GPIO mode; this input-list check does not establish a GUI build. Template files and .vh includes are not standalone units. Undriven/width warnings, generic crystal_d routing and timing coverage require review.

The installed polynomial/SVF/read32 image excludes ENABLE_FILTER and includes ENABLE_POLYNOMIAL/ENABLE_SVF, capability mask 6. Under the existing SYS_CLK 112.499-MHz constraint, comparisons report:

| Variant | Logic | Registers | BSRAM | DSP | Fmax MHz | Setup/hold violated endpoints |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A → B → C baseline | 15996 | 13025 | 20 | 9 | 112.525 | 0 / 0 |
| C → B → A baseline | 16197 | 13025 | 20 | 9 | 109.545 | 158 / 0 |
| Prior C → B → A/Q15 SVF | 16539 | 13023 | 20 | 9 | 86.845 | 1077 / 0 |
| Polynomial/SVF/read32 indexed, route 0 | 15700 | 12692 | 18 | 9 | 95.302 | 627 / 0 |
| Parallel busy selection, route 0 | 15982 | 12692 | 18 | 9 | 104.509 | 328 / 0 |
| Parallel selection, route 1 | 15982 | 12692 | 18 | 9 | 112.572 | 0 / 0 |
| Installed: parallel selection, route 1, local control copies | 16037 | 12720 | 18 | 9 | 112.594 | 0 / 0 |
| Current source: negative-A/minimum-one delay fixes | 15599 | 12682 | 18 | 9 | 110.863 | 25 / 0 |

Device capacities are 20736 logic, 15915 registers, 46 BSRAM and 24 DSP. The installed and minimum-tap images were built without the sine/tanh ROM files: both logs contain EX3988 Cannot open file for luts/sin_q15_full.hex and luts/tanh_q15.hex. A physical flanger probe shows changing phase but a constant modulation word 16384 (0.5), consistent with a zero sine table. These images cannot qualify LUT-dependent effects, and their resource/timing results do not qualify a correctly initialized ROM build. The ROM-staged build completes in /tmp/kestrel-gowin-rom-fix/impl, with log /tmp/kestrel-gowin-rom-fix.log. Both staged files match source byte-for-byte and the missing-file warnings are absent. The report includes eight pROM blocks and reports 16209 logic, 13122 registers, 26 BSRAM and 9 DSP, 113.115 MHz against 112.499 MHz, zero setup/hold violations. Bitstream SHA-256 is 9181efde04e2982eacddff0d4db03b48ba7f8c6d2565231f41286cd602697f54. It is not flashed; physical lookup checks remain required. /tmp/kestrel-flange-probe-hil.log holds the live evidence; the temporary probe was removed from the active preset, restoring the original Bass Flange.

Installed worst setup slack is only +0.008 ns on SVF product to factor_b: a narrow vendor-report margin, not physical qualification. The prior Q15 worst path is pipeline_a fetch_2 busy_bits to scoreboard enable at −2.626 ns. David requests closure without lowering the clock. The scoreboard owner governs equivalent parallel selection and attribution limits; same-cycle enable/reset branch copies include commit buffers.

Installed artifacts are /tmp/kestrel-gowin-timing-control-copies/impl and its sibling .log. impl/pnr/kestrel.fs SHA-256 is 9ccf0dd5116c54994a9e3941222e3bf52919c168f348147cc7d67c910572557e. /tmp/kestrel-timing-fpga-flash.log records full flash-write verification. This image predates the signed negative-A and final minimum-one delay source fixes. Core f679e823 contains those source changes. Its build completes synthesis, placement, routing and bitstream generation in /tmp/kestrel-gowin-minimum-tap/impl, with log /tmp/kestrel-gowin-minimum-tap.log. Bitstream SHA-256 is 429864bd3ac2d9563de8d09ea3908ac4caaf11696820115772d5b95d8b35882c. This source saves 438 logic cells and 38 registers against the installed image, with BSRAM/DSP unchanged, but reports 110.863 MHz against 112.499 MHz, 25 setup violations and no hold violations. It has not been flashed. Focused compiled delay tests pass; numerical simulation does not resolve this routing-report shortfall.

A whole MADD shift experiment is reverted: it reported 105.683 MHz and 128 setup violations, with unchanged DSP primitive counts. Automatic barrel-shifter mapping was not demonstrated. The original split shift remains. Evidence is /tmp/kestrel-gowin-timing-whole-shift and /tmp/kestrel-timing-whole-shift-tests.log; supported primitives and actual mapping must precede a native-shift decision.

The installed-image source passed all eleven Verilator targets in /tmp/kestrel-timing-final-full-tests.log, with compiled SVF/readback checks in /tmp/kestrel-timing-final-svf.log and /tmp/kestrel-timing-final-readback.log. Later focused tests qualify delay and static polynomial source behavior under the tests owner; they do not re-establish the installed image's timing or physical operation.

For flashing, disconnect external carrier power before connecting Tang USB-C; unplug Tang USB before restoring power. Routine powered diagnostics use ESP32 USB. openFPGALoader -b tangnano20k --detect identifies GW2A(R)-18(C), IDCODE 0x81b, Sipeed FTDI2232 serial 2025030317; flash is W25Q64, 0xef4017, 8 MiB. The prior full flash backup is /tmp/kestrel-fpga-before-svf.bin, 8388608 bytes, SHA-256 92ea010ac6cd52dc5e6990fe697a81a905d9363f88d55111ba57e80fbf7dd412.

Installed Interface firmware is 335bb1a3f4bb52247317c6baad17f52bb9db08f36310a0267176d02fdaeea025, including polynomial-resource programming and safe parser diagnostics. /tmp/kestrel-flange-poly-firmware-flash.log verifies its flash and /tmp/kestrel-flange-poly-live-hil.log verifies boot, the polynomial Bass Flange and clean FPGA status. The FPGA itself remains the earlier ROM-deficient image; polynomial instructions do not require those tables. Live reads return magic 0x4b455354 and mask 0x00000006. The superproject example-effects owner holds subsequent Bass Flange UI activation, 27 blocks, live phase readbacks and clean status 0x01; the earlier empty preset-14 check is not current selection. These checks establish transport/activation, not instrumented audio qualification. David's clean low-cutoff/smooth-control SVF feedback concerns the prior paired Q15 image.

Prior Q15 artifacts are /tmp/kestrel-gowin-svf-q15/impl and sibling .log, bitstream SHA-256 93f2793e76fd3685dcb8022f295defc5b4e635b820ceb9acbf80136c35525c0a. Earlier comparison directories are /tmp/kestrel-gowin-cba/impl and /tmp/kestrel-gowin-core-check/impl. Temporary artifacts are evidence locations; regenerate with the recorded flow.

Sources: Tcl, constraints, synthesis/routing reports, verified loader outputs, focused tests, carrier HIL logs and David's power/timing guidance.
