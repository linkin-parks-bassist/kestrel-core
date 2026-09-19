---
status: "unverified"
updated_at: "2026-09-20T00:13:25+10:00"
---
Status: Green

The Core tree now maps every first-party src/*.v module by role and captures fetch/decode/scoreboard/commit, controller, crossfade, SDRAM delay, LUT, filter, mixer, I2S and SPI paths. The RTL, configuration headers, LUTs, harnesses and test scripts remain unmodified. Source shows SDRAM delay connected through processing hierarchy; README capacity/integration text is stale. Some surfaces remain incomplete, including allocated LUT operations and an empty svf.v module; see their focused leaves. No Verilator simulation or synthesis was run because verilator is absent on this host. Source-level protocol numbers align with Interface definitions, but hardware operation is unverified.
