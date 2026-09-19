---
status: "unverified"
created_at: "2026-09-20T00:05:06+10:00"
scope: "local"
source: "src/delay_master.v:260-395"
---
Status: Green

A read request checks handle initialization, computes a delay address from current position, base delay and modulation arguments, clamps the offset, waits for memory read, applies per-buffer gain and returns a response. A write request writes at base plus current position, advances circular position, updates metadata and waits for memory acknowledgement. Invalid handles raise invalid_read or invalid_write. Source: src/delay_master.v:260-395
