---
status: green
revised_at: "2026-10-04T00:06:42+10:00"
---

The operand fetch stage is a three-substage ready/valid pipeline. `fetch_1`, `fetch_2`, and `fetch_3` resolve operands C, B, and A respectively while forwarding the complete decoded-instruction payload. Each substage can pass a dependency-free operand in one cycle or latch the instruction, deassert upstream readiness, and wait until its selected channel or accumulator dependency resolves. The final substage is followed by a two-entry skid buffer so downstream backpressure can be absorbed without losing the completed payload.

Each substage holds a mirrored channel array updated by committed channel writes. Register-form operands bypass the channel scoreboard and select the two decoded register values or fixed constants; channel-form operands read the mirrored channel array. An unused operand does not create a channel dependency.

For every channel, each substage maintains a four-bit pending-write count and a derived busy bit. An instruction leaving that substage increments the destination count when it will write a channel; committed writeback decrements the matching count. A needed channel operand stalls while its busy bit is set. While stalled, it resolves when the count reaches zero, or forwards `channel_write_val` when exactly one matching write remains and that write commits in the current cycle. The last substage also stalls an accumulator-reading instruction while accumulator writes remain pending.

Channel 0 has extra accounting: when the last program block leaves a substage, the scoreboard reserves the incoming-sample write. The later sample injection into channel 0 consumes that pending write, preventing the next sample program from observing the previous sample value.

Only instructions that write a channel or accumulator consume a commit ID. The ID assigned by the third substage accompanies the completed instruction so downstream branches can finish at different latencies while `commit_master` retires their side effects in order.

`in_ready` is true only when the substage is not hazard-busy and its output register is empty or being accepted. Therefore a local dependency stall propagates back through all earlier substages. The stage-level `stuck` watchdog counts enabled cycles without a successful final output transfer and asserts after `CYCLES_PER_SAMPLE`.

The C → B → A order moves common A dependencies nearest execution without changing scoreboard, accumulator or commit-ID mechanisms. Focused operand-fetch and actual-core tests check correctness; before/after throughput evidence and its workload limits belong to how/to/measure/core/instruction/throughput.md.

Source: src/operand_fetch.v, src/skid_buffer.v and src/commit_master.v; checked Verilator regressions.
