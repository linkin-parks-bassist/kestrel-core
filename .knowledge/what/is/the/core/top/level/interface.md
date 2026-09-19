---
status: "unverified"
created_at: "2026-09-19T23:57:08+10:00"
scope: "local"
source: "src/top.v"
---
Status: Green

src/top.v module top connects SPI pins, I2S audio and clocks, LEDs, codec enable and on-chip SDRAM pins. It instantiates dsp_engine and adapts clock/reset for hardware versus Verilator.

Source: src/top.v
