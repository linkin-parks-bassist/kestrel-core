---
status: "unverified"
created_at: "2026-09-19T23:57:08+10:00"
scope: "local"
source: "run_tests.sh; verilate.sh; run_sim.sh"
---
Status: Green

./run_tests.sh runs every verilator/test/*/run.sh, or selected module names passed as arguments. ./verilate.sh builds top with Verilator and ./run_sim.sh invokes obj_dir/Vtop with input/output WAV paths.

Source: run_tests.sh; verilate.sh; run_sim.sh
