---
status: green
revised_at: "2026-10-04T10:10:47+11:00"
---

control_unit exposes one status byte: initialized, listen, timeout, programming, bad health, data ready, command error and swapping bits. During readout it multiplexes returned data bytes in place of flags. Command IDs and data requests are in include/controller.vh.

The listen bit is exactly state == LISTEN: the controller is collecting command payload bytes. It is not a persistent communications-enable flag. READY accepts a new command; status-only 0xFF bytes are drained when outside LISTEN. Thus initialized=1 and listen=0 between commands is not evidence that the controller ignores commands or is wedged.

read32 is command 40, followed by three address bytes MSB first. The controller pulses read32_req with the complete 24-bit byte address, outside the pipeline-data path, and waits for read32_valid/read32_data from an external responder. It sets data_ready and uses the existing READOUT command 20 to emit four bytes MSB first. Only one read result occupies that existing slot; a new addressed or legacy read selects the corresponding response source. Reset clears the addressed wait. Future read24/read16/read8 are not implemented.

src/engine.v connects that interface to src/build_registers.v. Exact word-aligned address 0 returns 0x4b455354 (KEST); address 4 returns ENABLE_FILTER/POLYNOMIAL/SVF in bits 0/1/2, default 6. Unmapped or unaligned addresses receive no response. Other addresses are not aliases: all 24 bits are preserved. The responder uses compile-time constants from include/build.vh and returns a registered valid pulse. Narrower future reads will still use this word-aligned address scheme.

Scratchpad requests wait for a matching DSP write rather than returning stored memory immediately; how/does/the/core/return/scratchpad/memory/reads.md owns that distinction.

Source: src/controller.v flags assignments, READY/LISTEN state handling and 0xFF drain; include/controller.vh, include/build.vh, src/build_registers.v, src/engine.v and controller/build-register tests. Current RTL source does not establish the identity of the installed FPGA bitstream.
