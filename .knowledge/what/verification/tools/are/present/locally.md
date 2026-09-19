---
status: "unverified"
created_at: "2026-09-20T00:08:16+10:00"
scope: "local"
source: "command -v checks; verilator/test inventory"
---
Status: Green

This checkout has `make` but `verilator` and `idf.py` were not found on PATH during the 2026-09-20 audit. Core test shell scripts exist under `verilator/test`, but they cannot run without Verilator. This is host environment state, not a claim about CI or another machine. Source: command -v checks; verilator/test inventory
