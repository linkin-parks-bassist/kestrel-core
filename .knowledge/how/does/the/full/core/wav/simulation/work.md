---
status: "unverified"
created_at: "2026-09-20T00:08:53+10:00"
scope: "local"
source: "verilate.sh; run_sim.sh; verilator/sim_main.cpp"
---
Status: Green

`verilate.sh` builds `top` with a C++ harness and libkest linkage; `run_sim.sh` runs Vtop against input/output WAV paths. The harness reads 16-bit mono PCM WAV, drives simulated SPI/I2S and writes a 16-bit mono output WAV. This path requires Verilator and a built libkest. Source: verilate.sh; run_sim.sh; verilator/sim_main.cpp
