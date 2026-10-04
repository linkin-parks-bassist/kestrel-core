---
status: green
revised_at: "2026-10-04T12:23:21+11:00"
---

Each pipeline's delay_master is wired to the shared sdram_interface in src/engine.v, which sends read, write and refresh transactions to the controller exposed through src/top.v. README documents this source connection; it does not establish usable physical capacity or timing.

The compiled actual-core renderer now instantiates the real delay_master and supplies a delayed RAM transaction responder. Fixed/nonnegative taps, startup fade, feedback and buffer isolation have exact model/RTL and independent behavioral checks; negative final offsets reproduce a buffer-bounds defect. That responder does not exercise sdram_interface arbitration, the embedded controller, refresh, pins or board timing. The tests and delay-behavior owners specify coverage and the pending signedness decision.

Sources: src/pipeline.v, src/engine.v, src/top.v, README.md, verilator/test/dsp_core and superproject tools/test_eff_delay.py.
