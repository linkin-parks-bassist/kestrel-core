---
status: green
revised_at: "2026-09-20T00:10:34+10:00"
---

Core instruction comments state that only the MAC branch writes the accumulator; MAC accumulation is performed in the commit stage. Therefore the MAC branch does not wait on the accumulator as an operand dependency, allowing successive MAC instructions to issue at high throughput. Source: kestrel_core/include/instr_dec.vh:29-37; kestrel_core/README.md
