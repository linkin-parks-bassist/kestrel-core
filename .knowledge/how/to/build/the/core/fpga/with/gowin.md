---
status: green
revised_at: "2026-10-06T12:52:54+11:00"
---

Run build_gowin.tcl with the installed gw_sh wrapper from an empty build directory:

```bash
mkdir -p /tmp/kestrel-gowin-build
cd /tmp/kestrel-gowin-build
gw_sh /path/to/kestrel_core/build_gowin.tcl
```

Inputs resolve relative to the script; impl/ belongs to the working directory. It stages the two checked sine/tanh hex files into the build directory's luts/ before synthesis, because RTL readmemh paths resolve there. Missing/unreadable tables abort. It targets carrier GW2AR-LV18QN88C8/I7, top, include/, sysv2017, dude.cst and dude.sdc. It sets timing_driven=1, route_option=1 and use_sspi_as_gpio=1 because dude.cst assigns SCK to pin 55. Dedicated SSPI rejects that location; JTAG/MSPI roles remain. Host installation belongs to global:where/is/gowin/tooling/installed.md.

dude.gprj matches all 39 Tcl inputs in order: atypes.v before package consumers and pwm.v, preprocessing.v, postprocessing.v, polynomial.v and build_registers.v. XML parsing verifies every input exists. GUI compile/configuration settings, especially SSPI GPIO mode, remain unreconciled; matching inputs do not qualify a GUI build. Template files and .vh includes are not standalone units. Undriven/width warnings, generic crystal_d routing and timing coverage require review.

The installed polynomial/SVF/read32 image excludes ENABLE_FILTER and includes ENABLE_POLYNOMIAL/ENABLE_SVF, capability mask 6. Under the existing SYS_CLK 112.499-MHz constraint, comparisons report:

| Variant | Logic | Registers | BSRAM | DSP | Fmax MHz | Setup/hold violated endpoints |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A → B → C baseline | 15996 | 13025 | 20 | 9 | 112.525 | 0 / 0 |
| C → B → A baseline | 16197 | 13025 | 20 | 9 | 109.545 | 158 / 0 |
| Prior C → B → A/Q15 SVF | 16539 | 13023 | 20 | 9 | 86.845 | 1077 / 0 |
| Polynomial/SVF/read32 indexed, route 0 | 15700 | 12692 | 18 | 9 | 95.302 | 627 / 0 |
| Parallel busy selection, route 0 | 15982 | 12692 | 18 | 9 | 104.509 | 328 / 0 |
| Parallel selection, route 1 | 15982 | 12692 | 18 | 9 | 112.572 | 0 / 0 |
| Previous installed: parallel selection, route 1, local control copies | 16037 | 12720 | 18 | 9 | 112.594 | 0 / 0 |
| Minimum-tap build without ROM staging | 15599 | 12682 | 18 | 9 | 110.863 | 25 / 0 |

Capacities: 20736 logic, 15915 registers, 46 BSRAM and 24 DSP. The previous installed and minimum-tap images were built without the sine/tanh ROM files: both logs contain EX3988 Cannot open file for luts/sin_q15_full.hex and luts/tanh_q15.hex. An earlier flanger probe shows changing phase but a constant modulation word 16384 (0.5), consistent with a zero sine table. These images cannot qualify LUT-dependent effects, and their resource/timing results do not qualify a correctly initialized ROM build. The ROM-staged build completes in /tmp/kestrel-gowin-rom-fix/impl, with log /tmp/kestrel-gowin-rom-fix.log. Both staged files match source byte-for-byte and the missing-file warnings are absent. The report includes eight pROM blocks and reports 16209 logic, 13122 registers, 26 BSRAM and 9 DSP, 113.115 MHz against 112.499 MHz, zero setup/hold violations. Bitstream SHA-256 is 9181efde04e2982eacddff0d4db03b48ba7f8c6d2565231f41286cd602697f54. This is now the flash-write-verified carrier image (/tmp/kestrel-rom-fix-fpga-flash.log); powered boot passes with magic 0x4b455354, mask 6 and clean status 0x01; fourteen sine/tanh targets match physical scratchpad reads under the LUT owner. Physical audio and minimum-tap SDRAM checks remain open.

Previous installed worst setup slack is +0.008 ns on SVF product to factor_b: a narrow vendor-report margin, not physical qualification. The prior Q15 worst path is pipeline_a fetch_2 busy_bits to scoreboard enable at −2.626 ns. David requests closure without lowering the clock. The scoreboard owner governs equivalent parallel selection and attribution limits; same-cycle enable/reset branch copies include commit buffers.

Previous installed artifacts are /tmp/kestrel-gowin-timing-control-copies/impl and its sibling .log. impl/pnr/kestrel.fs SHA-256 is 9ccf0dd5116c54994a9e3941222e3bf52919c168f348147cc7d67c910572557e. /tmp/kestrel-timing-fpga-flash.log records full flash-write verification. This image predates the signed negative-A and final minimum-one delay source fixes. Core f679e823 contains those source changes. Its build completes synthesis, placement, routing and bitstream generation in /tmp/kestrel-gowin-minimum-tap/impl, with log /tmp/kestrel-gowin-minimum-tap.log. Bitstream SHA-256 is 429864bd3ac2d9563de8d09ea3908ac4caaf11696820115772d5b95d8b35882c. This source saves 438 logic cells and 38 registers against the previous installed image, with BSRAM/DSP unchanged, but reports 110.863 MHz against 112.499 MHz, 25 setup violations and no hold violations. It has not been flashed. Focused compiled delay tests pass; numerical simulation does not resolve this routing-report shortfall.

A whole MADD shift experiment is reverted: it reported 105.683 MHz and 128 setup violations, with unchanged DSP primitive counts. Automatic barrel-shifter mapping was not demonstrated. The original split shift remains. Evidence is /tmp/kestrel-gowin-timing-whole-shift and /tmp/kestrel-timing-whole-shift-tests.log; supported primitives and actual mapping must precede a native-shift decision.

The previous installed-image source passed all eleven Verilator targets in /tmp/kestrel-timing-final-full-tests.log, with compiled SVF/readback checks in /tmp/kestrel-timing-final-svf.log and /tmp/kestrel-timing-final-readback.log. Focused tests qualify delay/static polynomials, not physical timing.

For flashing, disconnect external carrier power before connecting Tang USB-C; unplug Tang USB before restoring power. Routine powered diagnostics use ESP32 USB. openFPGALoader -b tangnano20k --detect identifies GW2A(R)-18(C), IDCODE 0x81b, Sipeed FTDI2232 serial 2025030317; flash is W25Q64, 0xef4017, 8 MiB. Rollback: /tmp/kestrel-fpga-before-rom-fix.bin, 8388608 bytes, SHA-256 b6ff1ee0c879eaf59cf880fa0dfa1b6a62d673e18514f686a3ddb9800dee12ea; /tmp/kestrel-fpga-before-rom-fix.log verifies its complete read. Older backup: /tmp/kestrel-fpga-before-svf.bin, SHA-256 92ea010ac6cd52dc5e6990fe697a81a905d9363f88d55111ba57e80fbf7dd412.

The Interface installed-firmware owner governs current MCU identity and boot evidence. Prior paired-image /tmp/kestrel-flange-poly-live-hil.log verifies polynomial Bass Flange activation and clean FPGA status. Polynomial instructions do not require those ROMs; earlier HIL scopes do not qualify the new image. Live reads return magic 0x4b455354 and mask 0x00000006. The superproject example-effects owner holds subsequent Bass Flange UI activation, 27 blocks, live phase readbacks and clean status 0x01; the earlier empty preset-14 check is not current selection. These checks establish transport/activation, not instrumented audio qualification. David's clean low-cutoff/smooth-control SVF feedback concerns the prior paired Q15 image.

Prior Q15 artifacts are /tmp/kestrel-gowin-svf-q15/impl and sibling .log, bitstream SHA-256 93f2793e76fd3685dcb8022f295defc5b4e635b820ceb9acbf80136c35525c0a. Earlier comparison directories are /tmp/kestrel-gowin-cba/impl and /tmp/kestrel-gowin-core-check/impl. Regenerate temporary evidence with this flow.

Sources: Tcl, constraints, synthesis/routing reports, verified loader outputs, focused tests, carrier HIL logs and David's power/timing guidance.
