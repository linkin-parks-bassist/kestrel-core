---
status: "unverified"
created_at: "2026-09-20T00:08:16+10:00"
scope: "local"
source: "src/biquad.v; src/filter.v"
---
Status: Green

`src/biquad.v` defines a biquad pipeline and stage with coefficient banks, but the main filter path also lives in `src/filter.v`. Treat this as a separate RTL implementation candidate until an instantiation trace establishes live integration. Source: src/biquad.v; src/filter.v
