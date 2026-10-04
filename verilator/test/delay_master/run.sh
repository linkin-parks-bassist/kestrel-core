#!/bin/bash
set -e

verilator -Wall --trace -Wno-fatal \
    --top-module delay_master \
    -Gdata_width=16 \
    --cc ../../../src/*.v \
    -I../../../src -I../../../include \
    --exe sim_main.cpp tests.cpp \
    -CFLAGS "-fpermissive -Wno-error -DTRACE" \
    -LDFLAGS "-lm"

make -C obj_dir -f Vdelay_master.mk

./obj_dir/Vdelay_master
