#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
rtl=${OPERAND_FETCH_RTL:-../../../src/operand_fetch.v}
build=${OPERAND_FETCH_BUILD:-obj_dir}
mkdir -p "$build"
if ! verilator --cc --exe --build -j 2 -Wall -Wno-fatal \
    --top-module operand_fetch_test --Mdir "$build" \
    -I../../../include ../../../include/defs.vh "$rtl" ../../../src/skid_buffer.v operand_fetch_test.v \
    "$PWD/tests.cpp" > "$build/build.log" 2>&1; then
    cat "$build/build.log" >&2
    exit 1
fi
"$build/Voperand_fetch_test" "$@"
