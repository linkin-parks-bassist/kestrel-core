---
status: green
revised_at: "2026-10-04T10:10:48+11:00"
---

The enabled normal filter in src/filter.v and polynomial_unit in src/polynomial.v retain per-handle configuration and A/B coefficient memories. Existing SPI allocation and write/update/commit commands reach both enabled units; allocation order supplies handles. Ordinary writes target the active bank, updates target the inactive bank, and commit flips the selected bank for that handle.

The polynomial unit reserves only feed-forward coefficient storage and ignores coefficient indices beyond its allocation. It evaluates powers without filter-history memory. The original general engine retains its feed-forward/feedback history and capacity checks behind ENABLE_FILTER. SVF has private ordinal state and no coefficient allocation or control-written coefficient banks. The filter-engine owner governs build selection and execution.

Sources: src/filter.v and src/polynomial.v; polynomial bank-update/handle-isolation tests.
