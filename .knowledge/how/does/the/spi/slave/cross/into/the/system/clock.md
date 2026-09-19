---
status: "unverified"
created_at: "2026-09-20T00:05:06+10:00"
scope: "local"
source: "src/spi.v:1-95"
---
Status: Green

`sync_spi_slave` samples CS, SCK and MOSI through synchronizer registers clocked by the FPGA system clock, detects the configured sample edge, shifts MOSI bits into a byte and emits data_valid after eight bits. It latches the MISO response byte at chip select. Source: src/spi.v:1-95
