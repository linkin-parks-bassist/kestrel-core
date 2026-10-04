---
status: green
revised_at: "2026-10-04T10:42:52+11:00"
---

Each operand-fetch substage stores channel values and tracks pending writes per channel plus accumulator pending writes. Issuing a write increments the destination count; commit writeback decrements it. Busy bits gate fetch when a source depends on an in-flight result. Channel 0 has special accounting for the incoming sample write.

The current source selects the source-channel busy bit as a parallel comparison/reduction: source_busy[channel] = (src == channel) && busy_bits[channel], then arg_pending_write = |source_busy. This is the same Boolean selection as busy_bits[src] for valid channel indices; it adds no state or stage. Counter accounting, forwarding and hazard rules remain unchanged. Both spellings describe a multiplexer. Different descriptions can lead to different synthesis mapping, LUT packing and placement/routing; the mapped topology has not been established, so a claim that the original definitely became a deeper mux is unsupported.

With unchanged routing options, the parallel spelling reports 104.509 MHz against 95.302 MHz for the indexed spelling in the polynomial/SVF/read32 build. This measured whole-build difference does not isolate mapping from placement/routing effects or guarantee a repeatable gain for other builds. All five actual-core workloads retain identical cycle and stall statistics; the throughput owner gives their scope.

Sources: src/operand_fetch.v, /tmp/kestrel-timing-parallel-hazard-tests.log, /tmp/kestrel-gowin-timing-hazard and /tmp/kestrel-gowin-poly-read32-final reports.
