---
status: green
revised_at: "2026-10-01T06:43:38+10:00"
---

`src/top.v` connects SPI pins, I2S audio and clocks, LEDs, codec enable and on-chip SDRAM pins. It instantiates `dsp_engine` and adapts clock/reset for hardware versus Verilator.

The checked configuration in `include/defs.vh` uses 16-bit I2S samples and 16-bit DSP samples. Top averages the two input channels using `(left >>> 1) + (right >>> 1)` and sends the same DSP output to both transmit channels. A mono board feeding only one ADC channel would therefore halve its input amplitude; its channel routing must be changed or both ADC channels deliberately fed.

For the hardware build, the committed 27 MHz PLL configuration produces a nominal 112.5 MHz system clock. Divider logic yields MCLK = sys_clk/10, BCLK = sys_clk/40 and LRCLK = sys_clk/2560: nominally 11.25 MHz, 2.8125 MHz and 43,945.3125 Hz. MCLK/LRCLK is 256 and BCLK/LRCLK is 64. The diagnostic LRCLK constant of 44,100 does not establish an exact 44.1 kHz sample rate. Simulation uses a different BCLK toggle condition, so accelerated WAV simulation does not prove hardware clock timing.

The authorized integrated-board revision requires new ADC/DAC integration; its converter selection and hardware requirements are owned by the superproject. The current RTL has not been migrated or verified against those converters. Sources: `src/top.v`, `include/defs.vh`, `src/gowin_rpll/gowin_rpll.v`.
