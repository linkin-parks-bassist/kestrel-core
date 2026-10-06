---
status: green
revised_at: "2026-10-05T01:35:34+11:00"
---

Normal-filter and polynomial units retain per-handle A/B coefficient memories. Ordinary writes target the active bank, updates target the inactive bank, and commit flips that handle's bank. Polynomial writes neither initialize both banks nor copy unchanged coefficients on commit: populate the complete replacement bank or explicitly maintain its contents.

Interface control stages every coefficient of an affected handle, coalesces duplicates and emits one commit. Sparse updates lost an unchanged linear coefficient; complete-bank replay preserves it. tools/test_eff_poly.py checks exact bytes, static/exhaustive live sweeps and three successive flips: 459,776 reference outputs, maximum 64 cycles/sample. That renderer settles commands for 128 clocks. spi_control separately drives the actual SPI slave/controller and two filter masters at 10-MHz/112.5-MHz cadence across eight phases/two CS patterns. Its optional production-body mode is exercised by test_eff_poly.py across three successive updates, preserving -8192 on handle 1. The default fixed-input carrier values below match before/after four commits; staged writes retain old output and the second handle stays unchanged. That mode stubs health/swap. --engine executes compiled polynomial audio through actual FIFO/controller, pipelines/resources, health, gain/crossfade and mixer. Steady/endpoints and 4,096 stream outputs match with four-frame latency at 2551 clocks/sample. Engine tests eight phases/two CS patterns; SDRAM, MISO timing and transition sound remain unqualified.

The installed repair also passes numerical carrier HIL through ordinary UI/smoothing/control/SPI: silent KTPOLY evaluates input 0.5 with {shape,0.25,-shape}, adds a separate constant polynomial -0.25, and writes scratchpad. Shape 0.125/+0.5/-0.5/0/+0.5 produces -1024/8192/-16384/-4096/8192, with matching unsigned direct reads and clean status. This bounded fixture establishes unchanged-coefficient/other-handle preservation through repeated live commits; it does not qualify every degree/format, maximum-load pacing, overlaps or audible transitions. Interface's periodic-read owner owns the 44-step procedure and cleanup evidence.

Polynomial storage is feed-forward only and ignores out-of-allocation indices, with no filter history. General-filter history remains behind ENABLE_FILTER. SVF has private state without coefficient banks. The filter-engine owner governs selection.

Sources: RTL/unit/core tests, Interface updater/KTPOLY fixture; /tmp/kestrel-polynomial-repeated-regression.log and polynomial-probe-script-hil.log.
