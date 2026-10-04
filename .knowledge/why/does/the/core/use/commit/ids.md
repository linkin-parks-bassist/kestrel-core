---
status: green
revised_at: "2026-09-19T23:57:07+10:00"
---

Independent instruction branches can complete out of issue order. The commit master uses issued commit IDs to apply side effects in order, preserving program semantics.

Source: README.md; src/commit_master.v
