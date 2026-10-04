#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
verilator --cc --exe --build -j 2 -Wno-fatal --top-module test_polynomial \
    -I../../../include --Mdir obj_dir ../../../src/atypes.v \
    ../../../src/polynomial.v ../../../src/filter.v test_polynomial.v tests.cpp > obj-build.log 2>&1
./obj_dir/Vtest_polynomial
