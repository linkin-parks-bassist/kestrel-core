#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
for flags in {0..7}; do
    definitions=(-DKESTREL_CUSTOM_BUILD)
    ((flags & 1)) && definitions+=(-DENABLE_FILTER)
    ((flags & 2)) && definitions+=(-DENABLE_POLYNOMIAL)
    ((flags & 4)) && definitions+=(-DENABLE_SVF)
    verilator --cc --exe --build -j 2 -Wno-fatal --top-module build_registers \
        -I../../../include "${definitions[@]}" --Mdir "obj_dir_$flags" \
        ../../../src/build_registers.v tests.cpp -CFLAGS "-DEXPECT_FLAGS=$flags" > "obj-build-$flags.log" 2>&1
    "./obj_dir_$flags/Vbuild_registers"
    # Every advertised combination must also elaborate the corresponding engines.
    verilator --lint-only -Wno-fatal --top-module filter_master -I../../../include \
        "${definitions[@]}" ../../../src/atypes.v ../../../src/polynomial.v \
        ../../../src/filter.v > "obj-lint-$flags.log" 2>&1
done
