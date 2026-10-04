#!/bin/bash
set -e

verilator -Wall --trace -Wno-fatal \
    --top-module health_monitor \
    -Gdata_width=16 \
    --cc ../../../src/*.v \
    -I../../../src -I../../../include \
    --exe sim_main.cpp tests.cpp \
    -CFLAGS "-fpermissive -Wno-error -DTRACE" \
    -LDFLAGS "-lm"

make -C obj_dir -f Vhealth_monitor.mk

./obj_dir/Vhealth_monitor
