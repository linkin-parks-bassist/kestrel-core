---
status: "unverified"
created_at: "2026-09-20T00:05:06+10:00"
scope: "local"
source: "src/delay_master.v:79-260"
---
Status: Green

`delay_master` accepts allocation requests while disabled/configuring, rejects too many handles or an allocation exceeding its address space, then assigns contiguous memory starting at alloc_addr. Per-handle metadata stores base, size, delay, position, gain and wrapped state. Reset clears allocation state. Source: src/delay_master.v:79-260
