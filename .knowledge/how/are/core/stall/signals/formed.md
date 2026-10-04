---
status: green
revised_at: "2026-09-20T00:04:27+10:00"
---

Fetch, operand fetch, branch router and commit master each have a counter bounded by CYCLES_PER_SAMPLE and expose `stuck` after insufficient progress. Core/pipeline wiring aggregates stage and resource stuck bits for status readout. Source: src/instr_fetch_decode.v; src/operand_fetch.v; src/branch_router.v; src/commit_master.v; src/core.v; src/pipeline.v
