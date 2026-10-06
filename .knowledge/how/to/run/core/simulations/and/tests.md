---
status: green
revised_at: "2026-10-05T11:34:54+11:00"
---

Run ./run_tests.sh for twelve Verilator targets, or pass names: build_registers, polynomial, control_unit, dsp_core, delay_master, filter_master, health_monitor, mixer, multiply_stage, operand_fetch, spi_control, svf. Verilator 5.020 is checked. The coverage owner governs limits.

Core/operand_fetch print cycle/utilization CSV; run.sh accepts an absolute trace filename. OPERAND_FETCH_RTL selects alternate source; CORE_TEST_BUILD/OPERAND_FETCH_BUILD isolate builds. The throughput owner governs comparisons.

From the superproject, tools/test_eff_readback.sh compiles --readback-program FILE. tools/test_eff_svf.sh runs --svf-program FILE for expression/channel cutoff/private states, then --svf-audio-program FILE OUTPUT.wav for 44,100 reference samples/two-tone response. Pass /tmp/svf.wav to retain audio; otherwise outputs are temporary.

./verilator/test/dsp_core/run.sh --render-program PROGRAM.bin INPUT.pcm OUTPUT.pcm [TRACE.csv] renders mono signed16 little-endian PCM. It accepts instruction/register, delay/polynomial allocation/active-write commands and terminal tail-enable; only the final instruction may write c0. Optional CSV captures per-frame fetch, polynomial requests/state/results and channel writes. The polynomial-latency owner specifies counter interpretation. Unsupported commands, polynomial feedback/formats above 17, capacity overflow/out-of-allocation writes reject. Full reset precedes programming; scratchpad then persists.

--render-polynomial-update PROGRAM.bin INPUT.pcm OUTPUT.pcm UPDATE.bin FRAME [UPDATE.bin FRAME ...] requires increasing frames and settles each command for 128 clocks, excluding SPI cadence. tools/test_eff_poly.py checks static/exhaustive live outputs and three bank flips: 459,776 exact samples. It also invokes spi_control/run.sh PROGRAM.bin UPDATE.bin EXPECTED_SUM [UPDATE.bin EXPECTED_SUM ...]. This polynomial fixture starts at -1024, preserves handle 1 at -8192 and uses stubbed health/swap; audio instructions are parsed without execution.

Add --engine before PROGRAM.bin for FIFO/controller, pipelines/resources, health, gains/crossfade/mixer execution. Steady/endpoints and 4,096 stream outputs match at four-frame latency across commits, 2551 clocks/sample, eight phases/two CS patterns. Engine SDRAM uses a bounded responder.

./verilator/test/spi_control/run.sh --engine --read32 checks 96 exact mapped magic/capability words through actual MISO, FIFO/controller and build registers, with eight phases/two request CS patterns. Replies use separate one-byte READOUT transactions and check status restoration. Optional PROGRAM.bin EXPECTED_SAMPLE arguments test constant input 16384 at unity gains, checking the settled output every clock during reads. LEVEL/INVPHASE each pass 96 words at +16384/−16384. End-of-high-half-period sampling leaves master-edge setup/hold and physical rate qualification open.

tools/test_eff_state.py checks exhaustive built-in LUTs/persistent memory. tools/test_eff_delay.py checks taps/startup/feedback/isolation and accepted clamps with a RAM responder, excluding SDRAM hardware. ROMs resolve through run.sh's luts symlink; direct executables run from the Core root.

tools/effect_library.py combines compilation/model/core comparisons, corners, responses and WAVs. Its superproject owner governs use/deployment. Core-strobe modes exclude SPI/controller/mixer/physical audio. For SPI/engine PCM use spi_control/run.sh --engine --render with absolute program/input/output paths. tools/test_eff_engine.py supplies authored cases; --read32 --effect LEVEL --effect INVPHASE --effect SVFLP invokes --render-read32 for 1,536 exact outputs/read words with independent unity/polarity checks. Add --effect memory-state --effect delay-feedback --effect delay-pair for 6,209 exact outputs/read words with independent recurrences. tools/test_eff_engine_updates.py --live --read32 invokes --render-live-read32 for 1,536 outputs/words across live commits. Reads start at cycle 128, or 128 clocks after a same-frame update body; total traffic must fit 2551 clocks. The full-core WAV owner governs oracles/limits. Sources: run_tests.sh, wrappers and named helpers.
