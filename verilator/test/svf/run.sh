#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
verilator --cc --exe --build -j 2 -Wno-fatal --top-module test_svf \
    -I../../../include -I../../../src --Mdir obj_dir \
    ../../../src/atypes.v test_svf.v tests.cpp
./obj_dir/Vtest_svf
