---
status: "unverified"
created_at: "2026-09-20T00:08:16+10:00"
scope: "local"
source: "src/filter.v"
---
Status: Green

`src/filter.v` defines normal/fixed filter units with per-handle configuration and coefficient memories. Separate A/B coefficient banks allow writes to the inactive bank and a commit operation to switch the active coefficients; allocation checks filter and memory capacity. The filter engine executes feed-forward and feedback products through a run-state pipeline. Source: src/filter.v
