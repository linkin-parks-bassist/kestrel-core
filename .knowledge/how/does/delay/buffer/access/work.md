---
status: green
revised_at: "2026-10-04T10:54:39+11:00"
---

Delay modulation happens on the read, not the write. The Interface assembler exposes three forms:

- delay_read $d dest: read the configured delay, with modulation argument A fixed at zero.
- delay_mread $d a b dest: read using a modulated offset.
- delay_write value $d: store one sample and advance the circular write position.

There is no delay_mwrite in the current assembler. delay_read and delay_mread share BLOCK_INSTR_DELAY_READ; delay_write uses BLOCK_INSTR_DELAY_WRITE.

For a read, delay_master multiplies the modulation operands after replacing negative A with zero, scales the result by buffer size, adds the configured base delay, and clamps the offset to the buffer. It computes one integer memory address, waits for one returned sample, applies the per-buffer gain and returns the result. READ_1 through READ_9, including READ_2_5 and the memory wait, implement this path. It does not interpolate between adjacent samples or keep a read-ahead cache. Consequently smooth changes to an expression need not produce a smoothly interpolated delay tap. Fractional-delay interpolation could be an implementation change without necessarily adding opcodes; no such change is selected.

Writes carry A as the sample and advance position after storing it. They finish through the resource branch's write acknowledgement rather than receiving a commit ID or passing through commit_master. Preserve ordering when evaluating read/write behavior; do not assume commit_master orders those writes.

The instruction descriptors currently assign numeric_audio to both delay read forms and delay_write. David accepts the delay ISA and does not want an exact-offset read instruction. He has tested current modulation for flanging and likes its sound. Recommend against long-delay modulation because quantization becomes objectionable; the operation remains permitted, without promising good sound. A possible improvement in 24-bit mode is unverified. Fractional delay is a future feature, not prerequisite to the effect library.

Core README, eff/flanger.eff and the instruction table retain older descriptions of delay_mwrite, write-side modulation or different operand counts. Treat the assembler descriptors and RTL as evidence of current behavior, not those examples.

Sources: src/delay_master.v IDLE/READ_1–READ_9/write states, src/instr_dec.v and src/ext_rw.v; Interface components/fpga/kest_fpga_instr.c and components/parser/kest_asm_parser.c; David's current ISA/delay guidance. SDRAM wiring and integration limits belong to what/is/the/current/sdram/data/path.md and what/is/the/status/of/sdram/delay/integration.md.
