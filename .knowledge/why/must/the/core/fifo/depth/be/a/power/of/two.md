---
status: green
revised_at: "2026-09-20T00:10:48+10:00"
---

`src/fifo.v` derives a bank/address split assuming a power-of-two depth and deliberately makes nonconforming parameter values trigger a compile-time division-by-zero error. Preserve this constraint when changing SPI FIFO length or other FIFO instances. Source: src/fifo.v:1-35
