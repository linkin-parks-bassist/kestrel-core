---
status: green
revised_at: "2026-10-05T01:19:38+11:00"
---

The Core is a fixed-point programmable audio processor for Gowin GW2AR FPGA. Two DSP pipelines execute instructions. SPI bytes enter the engine FIFO/controller; the inactive pipeline is programmed, warmed up under health monitoring and crossfaded into use through gain control and the mixer.

Each pipeline contains the core and resource masters. engine.v arbitrates external SDRAM requests; the sample path includes preprocessing and postprocessing. The core-process and resource owners specify numeric, reset and readback contracts.

spi_control --engine executes production-compiled polynomial instructions and live updates through this hierarchy. Its bounded steady-output/endpoint checks do not establish general descriptor acceptance, SDRAM, I2S/converters or transition sound. The tests owner records scope. The engine's declared invalid_command output has no source assignment; the fixture checks controller status bits, FIFO capacity and pipeline errors instead of relying on that port.

Sources: src/engine.v, pipeline.v, mixer.v and verilator/test/spi_control.
