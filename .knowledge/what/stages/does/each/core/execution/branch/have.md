---
status: green
revised_at: "2026-10-04T10:42:54+11:00"
---

`dsp_core` (`src/core.v`) runs a front end of `block_fetcher` → `block_buffer` → `instr_decode_stage` (grouped as `block_fetch_decode_stage`), then operand fetch `fetch_1` → `fetch_2` → `fetch_3` → a two-entry skid buffer, then `branch_router`. In current src/operand_fetch.v these fetch C, B and A respectively. Each substage has its own channel/pending-write state and passes instruction metadata and fetched values onward. The final substage alone checks accumulator readiness and supplies the externally used commit ID; its counter increments for instructions that write a channel or accumulator. The C → B → A wiring is implemented; measured cycle results and limits belong to how/to/measure/core/instruction/throughput.md.

The router dispatches to seven branches, numbered in include/instr_dec.vh:

- 0 MADD (madd_pipeline): multiply → shift_1 → shift_2 (the embedded mac_pipeline) → add → saturate. Handles madd/arsh and assembler aliases add, sub, mul and mov.
- 1 MAC (mac_pipeline): multiply → shift_1 → shift_2. Handles macz, umacz, mac and umac, and is the only writer of the accumulator.
- 2 MISC (misc_branch): stage_1 → stage_2 → stage_3. Handles lsh, rsh, abs, min, max, clamp and the mov_acc variants. The README calls these single-stage, but RTL chains three stages.
- 3 DELAY, 4 LUT and 6 FILT (rsp_req_str, rsp_req_str_filter) and 5 MEM (resource_branch) are request/response stages. Latency depends on delay_master, lut_master and filter_master in dsp_pipeline, or memory in the core.

Each branch and its commit buffer use preserved local enable/reset register copies, updated on the same cycles as the original controls, without extra stages. MADD retains its original split shift; DSP barrel mapping remains unresolved. Each branch feeds its own commit_stage skid buffer; the MAC stage is accumulator-width. All seven feed commit_master, which accepts only the valid branch whose commit ID equals next_commit_id, and never during sample_tick. Writes occur on the following cycle: channel writes reach the channel file and scoreboards, and MAC results write or add into the accumulator.

Sources: src/core.v, src/operand_fetch.v, src/madd.v, src/misc.v, src/commit_master.v and include/instr_dec.vh.
