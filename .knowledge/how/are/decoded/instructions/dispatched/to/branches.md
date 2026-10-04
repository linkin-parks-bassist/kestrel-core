---
status: green
revised_at: "2026-09-20T00:04:27+10:00"
---

`branch_router` latches one instruction and its operands/metadata, raises one valid bit indexed by the decoded branch, and accepts a new instruction only if no branch output is pending or the selected branch is ready. The branch count and indices are defined in include/instr_dec.vh. Source: src/branch_router.v:7-140; include/instr_dec.vh
