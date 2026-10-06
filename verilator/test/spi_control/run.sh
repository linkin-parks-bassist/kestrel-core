#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
if [[ ${1:-} == --engine ]]; then
    shift
    sources=(../../../src/atypes.v)
    for source in ../../../src/*.v; do
        [[ $source == */atypes.v ]] || sources+=("$source")
    done
    ln -sfn ../../../luts luts
    verilator --cc --exe --build -j 2 -Wno-fatal --top-module test_spi_engine \
        -I../../../include --Mdir obj_dir_engine "${sources[@]}" \
        test_spi_engine.v engine.cpp > obj-build-engine.log 2>&1
    ./obj_dir_engine/Vtest_spi_engine "$@"
    exit
fi
verilator --cc --exe --build -j 2 -Wno-fatal --top-module test_spi_control \
    -I../../../include --Mdir obj_dir ../../../src/atypes.v ../../../src/spi.v \
    ../../../src/controller.v ../../../src/polynomial.v ../../../src/filter.v \
    test_spi_control.v tests.cpp > obj-build.log 2>&1
./obj_dir/Vtest_spi_control "$@"
