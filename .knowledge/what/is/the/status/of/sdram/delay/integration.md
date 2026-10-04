---
status: green
revised_at: "2026-09-20T00:04:48+10:00"
---

The README says the SDRAM controller was not connected when written. Current RTL wires each pipeline delay_master to the shared sdram_interface in src/engine.v; that arbiter sends read, write and refresh requests to the controller exposed through src/top.v. The delay path is therefore connected in source. Actual synthesis, board behavior, and usable delay capacity have not been verified here, so the README capacity figure is stale evidence. Source: README.md; src/pipeline.v:200-300; src/engine.v:380-445; src/top.v.