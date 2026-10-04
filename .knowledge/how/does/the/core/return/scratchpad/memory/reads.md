---
status: green
revised_at: "2026-10-04T03:43:50+11:00"
---

A DATA_REQ_MEM request is a live write observation, not an immediate lookup of the stored scratchpad contents. The controller collects the two address bytes and forwards the request to the current pipeline. The pipeline routes it to dsp_core; the core retains the requested address and waits for mem_write_enable with a matching mem_write_addr. It then returns mem_write_val, asserts data_return_valid and clears the active request.

David explicitly requires preserving this design. Readback snoops values as they are written and must not take control of the BRAM read-address registers, interrupt BRAM operation or disturb DSP functioning/data flow. Exposed values are refreshed at least once per processing cycle; values not written are not exposed to the end user. Callers therefore observe ordinary live-value reads while the hardware avoids arbitration of its working memory ports.

A request to an address the running program never writes can wait indefinitely in RTL; firmware's bounded poll can return -5 without a controller fault. Qualification must target a known-written exposed address. Do not replace write snooping with intrusive BRAM reads or treat an arbitrary inactive address as evidence of failure.

Source: src/controller.v COMMAND_READ forwarding, src/pipeline.v DATA_REQ_MEM routing, src/core.v DATA_REQ_MEM completion condition. David's explicit write-snooping rationale and preservation instruction. This is source-established behavior, not independent qualification of the installed FPGA bitstream.
