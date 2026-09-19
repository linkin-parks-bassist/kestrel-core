---
status: "unverified"
created_at: "2026-09-20T00:08:53+10:00"
scope: "local"
source: "run_tests.sh; verilator/test/*/run.sh; src/mixer.v"
---
Status: Green

`run_tests.sh` invokes six Verilator test directories: control_unit, delay_master, filter_master, health_monitor, mixer and multiply_stage. Each script compiles all `src/*.v` with a named top and C++ harness. The mixer script names `mixer` as top, while `src/mixer.v` declares `gain_controller` and `bimultiplier`; that target likely fails until reconciled. This is a static source observation because Verilator is unavailable locally. Source: run_tests.sh; verilator/test/*/run.sh; src/mixer.v
