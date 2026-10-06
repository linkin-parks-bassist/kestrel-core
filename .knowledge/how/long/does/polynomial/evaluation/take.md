---
status: green
revised_at: "2026-10-05T11:34:54+11:00"
---

For the compiled one-instruction shipped degree-seven sine, polynomial acknowledgement to result takes 17 clocks in the current Core test trace:

- 2 clocks fetching configuration and 1 startup clock;
- 8 coefficient clocks: FIRST_SAMPLE plus seven FEED_FORWARD clocks;
- 1 accumulator flush;
- 4 normalization clocks for shift 14: shifts by 8, 4 and 2, then state exit;
- 1 result-send clock.

The cold frame observes acknowledgement at cycle 14, polynomial result at 31, filter-master result at 32 and final c0 write at 36. The renderer reports 37 because it advances/counts one more tick after observing that write. Warm frames observe acknowledgement/result/write at 9/26/31 and report 32. Eight edge/interior samples show the same 17-clock unit latency and four normalization clocks.

Thus 37 is a whole-Core cold-frame maximum, including fetch/router/request/commit and the observation tick, not 37 clocks inside polynomial_unit or per coefficient. At nominal 112.5 MHz it represents about 0.329 µs and 1.45% of 2551 clocks/sample. Those are nominal conversions, not physical timing qualification.

Trace with dsp_core --render-program PROGRAM.bin INPUT.pcm OUTPUT.pcm TRACE.csv. Cycle zero is the snapshot after input injection; CSV captures fetch/request/ack/state/result/channel-write signals before each counted tick. For delays the renderer's maximum also includes pending transaction drain; the trace covers the output-search loop.

Evidence: /tmp/kestrel-poly-trace.csv and /tmp/kestrel-poly-trace-summary.json; test-only wrapper/C++ instrumentation; src/polynomial.v. Default core workloads pass. The instrumented build reproduces all 65,536 shipped-sine outputs byte-for-byte, still reporting maximum 37. Production RTL is unchanged. Degree/coefficient format affect latency; this is not a universal polynomial cost.
