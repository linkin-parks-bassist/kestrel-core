#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
build=${CORE_TEST_BUILD:-obj_dir}
rtl=${OPERAND_FETCH_RTL:-../../../src/operand_fetch.v}
sources=(../../../src/atypes.v)
for source in ../../../src/*.v; do
    case "$source" in
        */atypes.v) ;;
        */operand_fetch.v) sources+=("$rtl") ;;
        *) sources+=("$source") ;;
    esac
done
mkdir -p "$build"
if ! verilator --cc --exe --build -j 2 -Wall -Wno-fatal \
    --top-module core_test --Mdir "$build" -I../../../include \
    "${sources[@]}" core_test.v "$PWD/tests.cpp" > "$build/build.log" 2>&1; then
    cat "$build/build.log" >&2
    exit 1
fi
"$build/Vcore_test" "$@"
