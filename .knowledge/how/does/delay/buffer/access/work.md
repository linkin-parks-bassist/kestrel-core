---
status: green
revised_at: "2026-10-04T12:31:15+11:00"
---

Delay modulation happens on the read. The Interface assembler exposes delay_read $d dest (zero modulation), delay_mread $d a b dest and delay_write value $d. There is no delay_mwrite. Both read forms use opcode 17; writes use 18 and advance the circular write position.

delay_master allocates buffers sequentially in its 20-bit word-addressed memory space. Allocation carries size and base delay as two 24-bit programming fields, truncated to the implemented address width. The firmware compiler converts requested units to samples, enforces at least delay+4 words, and adds 4−(size%4), including four words when already divisible by four. The declared 32-word/8-sample fixture therefore programs 36 words.

Reads multiply signed16 A/B, shift down by 15, multiply by the upper sixteen bits of buffer size, shift down by 11 in the 20-bit-address build, add base delay, then clamp to ±(size−1). The scale drops size's low four bits. Reads use one integer memory address and apply the per-buffer gain to the returned word; there is no interpolation or read-ahead cache.

David requires negative A to be clamped to zero. The unit explicitly interprets the packed A word as signed before comparing it with one; zero and negative A therefore leave the configured base delay unchanged, regardless of B. Independent tap checks cover negative A with both signs of B.

B remains signed. The final offset still clamps to ±(size−1), but its address comparison mixes signed delta and unsigned position. A negative final offset can address outside the allocated buffer: the compiled 36-word buffer with base delay 8, A=+1 and B=−1 reads address 60 at position zero. tools/test_eff_delay.py reproduces this remaining defect in the actual unit/core with per-handle bounds checks. The sample model rejects that invalid access instead of supplying plausible audio. Negative-A clamping does not settle how negative final offsets produced by B should behave; that repair remains separate.

Allocation starts gain at zero. After the first complete traversal, each subsequent write increases gain by 64 toward Q14 unity 16384. This suppresses unwritten memory and fades the delay in over 256 writes. The test responder initializes RAM to nonzero words so zero-initialized simulator memory cannot hide a muting error.

Writes do not go through commit_master: the resource branch advances after request acceptance, while delay_master waits for the memory write acknowledgement before accepting its next operation. Preserve the serialized delay-unit order. The renderer drains outstanding delay work before the next simulated sample and includes that drain in its cycle cost.

Compiled tests check fixed taps/startup gain independently, modulation whose final offset remains nonnegative, paired isolated allocations, and half-gain feedback against an independent recurrence. A delayed RAM transaction responder varies completion over 3–11 clocks. It is not a simulation of the SDRAM controller, arbiter, pins or physical timing.

David accepts the delay ISA, has enjoyed its flanging, and does not want an exact-offset read instruction. Long-delay modulation remains permitted but discouraged because integer tap quantization becomes objectionable. Fractional interpolation is future work; 24-bit improvement remains unqualified. Older eff/flanger.eff retains obsolete write-modulation syntax and is outside the verified batch; README, assembler and RTL describe the current read-modulation forms.

Sources: src/atypes.v, src/delay_master.v, src/instr_dec.v, src/ext_rw.v; Interface components/fpga/kest_fpga_instr.c and kest_fpga_encoding.c; compiled fixtures and tools/test_eff_delay.py. Source wiring and physical integration limits belong to the SDRAM data-path/integration owners.
