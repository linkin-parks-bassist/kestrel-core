#!/bin/bash

PASS=0
FAIL=0

if [ $# -gt 0 ]; then
    MODULES=("$@")
else
    MODULES=()
    for d in verilator/test/*; do
        if [ -d "$d" ]; then
            MODULES+=("$(basename "$d")")
        fi
    done
fi

for mod in "${MODULES[@]}"; do
    d="verilator/test/$mod"

    if [ ! -d "$d" ]; then
        echo "Skipping $mod: no such test directory"
        FAIL=$((FAIL+1))
        echo
        continue
    fi

    echo "======================================"
    echo "Module: $mod"
    echo "======================================"

    if (cd "$d" && ./run.sh); then
        echo "PASS: $mod"
        PASS=$((PASS+1))
    else
        echo "FAIL: $mod"
        FAIL=$((FAIL+1))
    fi

    echo
done

echo "======================================"
echo "SUMMARY"
echo "======================================"
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [ $FAIL -ne 0 ]; then
    exit 1
fi
