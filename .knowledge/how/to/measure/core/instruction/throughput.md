---
status: green
revised_at: "2026-10-04T10:42:54+11:00"
---

Run ./run_tests.sh operand_fetch dsp_core. Both harnesses print CSV containing workload, total cycles, retirements, dependency-busy cycles and occupied cycles for each of the three operand substages. Instrumentation stays in test-only wrappers; production RTL has no added counters.

The operand_fetch harness uses an ordered eight-cycle execution/writeback sink to isolate fetch costs. The core harness programs the real dsp_core through its control-data/register/instruction ports, commits the register bank, and runs the actual decoder, fetch stages, router, arithmetic branches and commit master. Programs consume channel 0 at entry and write it at exit; three changing input samples test sample-boundary accounting. Outputs and destinations, one-at-a-time ordered retirement and six-bit commit-ID wraparound are checked. Resource-engine requests, physical audio and SPI are outside this harness.

To compare identical workloads, save the old operand_fetch.v outside the checkout, set OPERAND_FETCH_RTL to its absolute path, and use CORE_TEST_BUILD=/tmp/core-baseline or OPERAND_FETCH_BUILD=/tmp/fetch-baseline. Keep headers, harnesses and other RTL identical. Pass an absolute trace filename to ./verilator/test/dsp_core/run.sh or ./verilator/test/operand_fetch/run.sh for cycle evidence.

The C → B → A comparison with Verilator 5.020 establishes the following cold-frame results for 96 useful instructions:

| Actual core workload | A → B → C cycles | C → B → A cycles |
| --- | ---: | ---: |
| MADD A dependency chain | 1348 | 1158 |
| MADD B dependency chain | 1253 | 1253 |
| MADD C dependency chain | 1158 | 1348 |
| Independent MADD | 113 | 113 |
| Independent mixed MADD/ABS | 113 | 113 |

A chains save 190 cycles across 95 instruction-to-instruction dependencies: two cycles per link, 14.1% less elapsed time and 16.4% more useful retirements per cycle (0.0712 → 0.0829). At the configured integer budget of 2551 cycles/sample, this cold-frame workload occupies 52.8% → 45.4% of the budget; nominal headroom grows 1203 → 1393 cycles. These are simulation cycle counts, not qualified physical clock performance. Busy stage-cycles sum to 1247 → 1055 for this workload; busy includes dependency resolution and is not a separate additive timing saving.

The isolated A chain measures 1248 → 1058 cycles with the fixed sink; B is unchanged and C pays the inverse cost. Independent, register/constant, unused-busy-operand, accumulator, backpressure and enable-pause cases pass. Output backpressure can dominate and eliminate the cycle gain. Complete trace timelines support two combined cycles here, not four by adding overlapping intervals. David expects real .effs to contain long A dependency chains; compiled .eff measurements remain required before generalizing this synthetic workload to product effects.

The parallel busy-bit selection and same-cycle branch control copies retain all five core cycle counts and stall statistics above. The eleven-target suite passes after restoring the original MADD shift. Evidence includes /tmp/kestrel-timing-final-full-tests.log and /tmp/kestrel-timing-control-copies-tests.log; this establishes no extra simulated cycles in these workloads, not exhaustive equivalence.

Evidence: verilator/test/operand_fetch and verilator/test/dsp_core sources; checked before/after simulation logs and traces. Gowin physical resource/timing qualification belongs to how/to/build/the/core/fpga/with/gowin.md.
