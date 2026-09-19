---
status: "unverified"
created_at: "2026-09-20T00:08:16+10:00"
scope: "local"
source: "src/svf.v; include/filter.vh; src/filter.v"
---
Status: Green

`src/svf.v` is an empty placeholder in the current checkout; SVF-related instruction constants and filter paths exist elsewhere, so a future SVF change should trace `src/filter.v`, `src/core.v` and `include/filter.vh` rather than assuming this file implements it. Source: src/svf.v; include/filter.vh; src/filter.v
