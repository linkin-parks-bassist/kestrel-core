---
status: green
revised_at: "2026-10-03T23:49:47+10:00"
---

This host has make, g++, Verilator 5.020, system CMake 3.28.3 and Ninja 1.11.1, Gowin EDA V1.9.11.03 Education and openFPGALoader v1.1.1. Python serial support is installed for UART tooling. Verilator is available at /usr/bin/verilator. Core test scripts under verilator/test use it; individual harness/source issues still need qualification rather than assuming every suite passes.

The vendor CLI/GUI and a complete GW2AR-LV18QN88C8/I7 smoke-design flow work. Installation paths, Ubuntu compatibility wrappers and USB access setup are owned by global:where/is/gowin/tooling/installed.md and global:where/is/openfpgaloader/installed.md. No supported USB programmer was found by the validation scan; physical programming is unverified. The Core Gowin build procedure owns project-specific results and configuration gaps.

ESP-IDF 5.3.3 and ESP32-P4 tools are installed; source the SDK export.sh to expose idf.py. Installation belongs to global:where/is/esp-idf/installed.md, and the successful carrier firmware build belongs to the Interface how/to/build/and/run/the/interface.md leaf. Compilation does not establish hardware interoperability.

Sources: package installation and executable version checks, vendor CLI/GUI/full-flow checks, openFPGALoader version/board-list/USB scan, Core test inventory and verified SDK export/build.
