#!/bin/bash
set -e

verilator -Wall --trace -Wno-fatal \
    --top-module multiply_stage \
    -Gdata_width=16 \
    --cc ../../../src/*.v \
    -I../../../src -I../../../include \
    --exe sim_main.cpp tests.cpp \
    -CFLAGS "-fpermissive -Wno-error -DTRACE" \
    -LDFLAGS "-lm"

make -C obj_dir -f Vmultiply_stage.mk

./obj_dir/Vmultiply_stage
