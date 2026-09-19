---
status: "unverified"
created_at: "2026-09-20T00:05:06+10:00"
scope: "local"
source: "src/sdram_interface.v:1-165"
---
Status: Green

The shared `sdram_interface` assigns pipeline 0 the lower half and pipeline 1 the upper half of address space. It latches request edges, prioritizes refresh when due, then alternates priority between clients on serviced requests. It returns per-client read_valid or write_ack. Source: src/sdram_interface.v:1-165
