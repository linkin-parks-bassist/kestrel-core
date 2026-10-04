---
status: green
revised_at: "2026-10-04T10:10:49+11:00"
---

Resource branches handle lookup tables, memory, delay buffers and the selected filter/polynomial/SVF units. LUT handles 0 and 1 select sin(2πx) and tanh(4x). Delay operations use allocated handles; normal-filter and polynomial coefficients use the existing SPI allocation/write/update/commit commands. SVF carries cutoff/damping in its invocation and uses private ordinal state. include/build.vh selects independent ENABLE_FILTER/POLYNOMIAL/SVF options; polynomial and SVF are enabled by default. SPI read32 at address 4 reports their bits, as specified by the controller SPI owner.

Source: README.md; src/lut_master.v; include/instr_dec.vh
