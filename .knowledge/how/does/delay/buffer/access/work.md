---
status: green
revised_at: "2026-10-06T12:42:07+11:00"
---

Delay modulation happens on the read. The Interface assembler exposes delay_read $d dest (zero modulation), delay_mread $d a b dest and delay_write value $d. Both read forms use opcode 17; writes use 18 and advance the circular write position. delay_mwrite/fractional interpolation are absent.

delay_master allocates buffers sequentially in its 20-bit word-addressed memory space. Allocation carries size and base delay as two 24-bit fields, truncated to the implemented address width. The compiler converts units to samples, enforces at least delay+4 words, and adds 4−(size%4), including four words when already divisible by four. A declared 32-word/8-sample fixture therefore programs 36 words.

Reads clamp negative signed16 A to zero, multiply A by signed16 B, shift down by 15, multiply by the upper sixteen bits of buffer size, shift down by 11 in the 20-bit-address build, add base delay, and clamp the final tap to 1..size−1. Scaling drops size's low four bits. Zero or negative A leaves the configured base delay before that final clamp. B remains signed and can shorten the tap, but cannot move it below one sample.

David explicitly requires this minimum-one rule and rejects wrapping a negative delay into a near-full-buffer delay. The write position names the next slot to overwrite: offset 0 is therefore the oldest sample, whereas offset 1 is the latest completed write. Clamping zero/negative final offsets to 1 avoids that discontinuity. Internal circular address wrap for an ordinary positive tap remains necessary; it is not permission to wrap a negative requested offset. The source sets delay_addr_delta_min to 1, retaining the existing upper clamp and serialized pipeline.

Reads use one integer memory address and multiply the returned word by per-buffer gain. Allocation starts gain at zero. After the first complete traversal, each subsequent write increases gain by 64 toward Q14 unity 16384, fading in over 256 writes. Test RAM starts with nonzero words so zero-initialized simulation memory cannot hide a muting error.

Writes bypass commit_master: the resource branch advances after request acceptance, while delay_master waits for memory acknowledgement before accepting its next operation. Preserve that serialized order. The renderer drains pending delay work before the next sample and includes it in cycle cost.

tools/test_eff_delay.py checks eleven 4096-sample compiled cases: fixed/modulated taps, startup fade, feedback, isolated buffers, negative A with both B signs, exact-zero/negative final offsets, and a literal zero base delay. All 45,056 outputs agree exactly with the model; independent tap and feedback recurrences check intended behavior. The former address-60/outside-36-word case now returns the minimum-one tap. RAM completion varies over 3–11 clocks with per-handle bounds checks. This does not simulate the SDRAM controller, arbiter, refresh, pins or physical timing. Carrier flash includes this repair; physical tap checks remain open. Core's build owner identifies it.

David accepts the delay ISA, has enjoyed flanging, and does not want an exact-offset read instruction. Long-delay modulation remains permitted but discouraged because integer tap quantization becomes objectionable. Fractional interpolation is future work; 24-bit improvement remains unqualified. Older eff/flanger.eff uses obsolete write-modulation syntax and is outside the verified batch.

Sources: David's explicit A-clamp/no-negative-wrap/minimum-one decisions; src/atypes.v, src/delay_master.v, src/instr_dec.v, src/ext_rw.v; Interface assembler/encoder; compiled fixtures and /tmp/kestrel-delay-minimum-check.log. SDRAM integration owners govern physical limits.
