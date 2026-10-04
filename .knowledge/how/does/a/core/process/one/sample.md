---
status: green
revised_at: "2026-10-04T11:45:29+11:00"
---

I2S delivers a sample to the engine. Each core reads instructions from block RAM; operand fetch uses a scoreboard to stall hazards; the branch router dispatches arithmetic or resource operations; the commit path orders channel/accumulator results; the mixer applies gains and combines the two pipelines.

Scratchpad instructions access the core's private mem array through its memory resource branch. Resource-format instructions carry a 12-bit address field; the actual core memory address width follows memory_size. Values persist between samples. A normal reset clears channel state and control, but does not initialize every memory word. full_reset walks the memory and instruction arrays, writing zeros before ready rises. A simulator starting a new program must exercise that full reset rather than treating incidental simulator zero initialization as product behavior. External scratchpad readback remains write snooping; how/does/the/core/return/scratchpad/memory/reads.md owns that distinct contract.

Sources: README.md; src/core.v memory array, memory resource branch, reset/full_reset walk; src/instr_dec.v format-B address decoding; src/engine.v.
