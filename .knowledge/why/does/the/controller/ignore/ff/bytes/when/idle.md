---
status: green
revised_at: "2026-09-20T00:10:48+10:00"
---

A controller comment explains that 0xFF bytes are used to clock out status flags. When not receiving a command payload, the control unit ignores/drains them so the SPI input FIFO does not fill with status reads. Source: src/controller.v:290-305
