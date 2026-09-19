---
status: "unverified"
created_at: "2026-09-20T00:05:06+10:00"
scope: "local"
source: "src/pipeline.v:200-300; src/engine.v:380-445; src/top.v"
---
Status: Green

Each dsp_pipeline instantiates delay_master with SDRAM request/response ports. `dsp_engine` joins the two pipeline requests in sdram_interface, and `top` connects its controller-facing signals to the embedded SDRAM controller. This is a source wiring observation; board timing/capacity have not been measured. Source: src/pipeline.v:200-300; src/engine.v:380-445; src/top.v
