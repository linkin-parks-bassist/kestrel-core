---
status: "unverified"
created_at: "2026-09-20T00:04:26+10:00"
scope: "local"
source: "src/operand_fetch.v:120-235"
---
Status: Green

Each operand-fetch substage stores channel values and tracks pending writes per channel plus accumulator pending writes. Issuing a write increments the destination count; commit writeback decrements it. Busy bits gate fetch when a source depends on an in-flight result. Channel 0 has special accounting for the incoming sample write. Source: src/operand_fetch.v:120-235
