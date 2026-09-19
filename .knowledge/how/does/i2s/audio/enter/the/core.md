---
status: "unverified"
created_at: "2026-09-20T00:05:07+10:00"
scope: "local"
source: "src/i2s.v:1-75"
---
Status: Green

`i2s_trx` detects BCLK edges in the system-clock domain, shifts incoming stereo serial bits, emits rx_valid and captured left/right samples on an LRCLK boundary, latches outgoing channels, and shifts output bits on falling BCLK edges. Source: src/i2s.v:1-75
