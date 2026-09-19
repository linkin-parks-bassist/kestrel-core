---
status: "unverified"
created_at: "2026-09-20T00:04:27+10:00"
scope: "local"
source: "src/controller.v:8-100; include/controller.vh"
---
Status: Green

`control_unit` exposes one status byte: initialized, listen, timeout, programming, bad health, data ready, command error and swapping bits. During a readout it multiplexes returned data bytes in place of flags. Command IDs and data requests are in include/controller.vh. Source: src/controller.v:8-100; include/controller.vh
