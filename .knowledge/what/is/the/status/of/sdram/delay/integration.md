---
status: green
revised_at: "2026-10-04T13:10:37+11:00"
---

Each pipeline's delay_master is wired to the shared sdram_interface in src/engine.v, which sends read, write and refresh transactions to the controller exposed through src/top.v. README documents this source connection; it does not establish usable physical capacity or timing.

The compiled actual-core renderer now instantiates the real delay_master and supplies a delayed RAM transaction responder. Fixed/modulated taps, startup fade, feedback and buffer isolation have exact model/RTL and independent behavioral checks, including David's negative-A clamp and minimum-one final taps. Zero/negative requested final offsets return the latest completed write rather than wrapping into a long delay; the production source repair is not yet flashed. That responder does not exercise sdram_interface arbitration, the embedded controller, refresh, pins or board timing. The tests and delay-behavior owners specify coverage and the selected A clamp and minimum-one rule.

Sources: src/pipeline.v, src/engine.v, src/top.v, README.md, verilator/test/dsp_core and superproject tools/test_eff_delay.py.
