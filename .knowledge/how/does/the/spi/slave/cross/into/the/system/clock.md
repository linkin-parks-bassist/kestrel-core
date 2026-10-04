---
status: green
revised_at: "2026-10-04T00:08:24+10:00"
---

`sync_spi_slave` currently samples CS, SCK and MOSI through synchronizer registers clocked by SYS_CLK. It detects the configured normalized SCK edge, shifts MOSI into a byte and pulses data_valid after eight sampled bits. It snapshots the MISO response byte at chip select and updates the MISO bit in the system-clocked logic. There is no SCK-clocked shifter or byte-level asynchronous crossing in the present RTL.

David reports reliability disappearing as SCK is increased and requests an SCK-clocked frontend with explicit synchronization into SYS_CLK, expecting a higher reliable SCK limit. That replacement is planned, not implemented; the Core spec/plan own its requirements. The source comment's claim that 10 MHz works is not an independently measured maximum or qualification result. Exact SPI setup/hold, framing, clock-domain/reset and response-transfer contracts need validation before implementation.

Source: src/spi.v; David's explicit planned SPI change and reliability report.
