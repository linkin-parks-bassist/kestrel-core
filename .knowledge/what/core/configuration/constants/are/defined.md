---
status: green
revised_at: "2026-10-04T10:10:46+11:00"
---

include/defs.vh sets 16-bit sample/data width, 18-bit coefficient arithmetic, 256 blocks, 16 channels, 112.5 MHz clock, 44.1 kHz sample rate, 16-entry SPI FIFO, and 16 slots each for filters, delays and SVF.

include/build.vh selects independently compiled ENABLE_FILTER, ENABLE_POLYNOMIAL and ENABLE_SVF. Defaults are polynomial and SVF enabled, normal filter excluded. Define KESTREL_CUSTOM_BUILD to suppress default selection, then define the desired ENABLE_* macros. Capability bits 0, 1 and 2 respectively are computed from those exact macros; SPI read32 at address 4 exposes the mask. Address 0 exposes magic 0x4b455354 (KEST). The controller SPI owner defines framing and response behavior.

Sources: include/defs.vh, include/build.vh and src/build_registers.v.
