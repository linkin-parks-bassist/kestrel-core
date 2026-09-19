---
status: "unverified"
updated_at: "2026-09-20T00:13:25+10:00"
---
Status: Green

Use the Core leaves for the user-led spec workshop, especially instruction/resource scope, delay requirements and intended behavior of incomplete LUT/filter surfaces. Do not infer desired product features from existing RTL. For implementation work, review source-level assumptions and then run focused Verilator simulation or synthesis on a host with those tools. Specifically verify SDRAM timing/capacity on hardware before relying on current RTL wiring or README claims, and resolve the mixer test/top mismatch before treating that test as coverage. Refresh affected leaves and state after changes.
