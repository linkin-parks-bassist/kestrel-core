---
status: green
revised_at: "2026-10-05T02:46:19+11:00"
---

I2S delivers a sample to the engine. Each core reads instructions from block RAM; operand fetch uses a scoreboard to stall hazards; the branch router dispatches arithmetic or resource operations; the commit path orders channel/accumulator results; the mixer applies gains and combines the two pipelines.

The engine's sampled preprocessing, core output, postprocessing and final output registers introduce frame latency beyond instruction execution cycles. spi_control --engine checks the compiled quadratic/constant polynomial fixture at 2551 clocks/sample: 4,096 continuous changing outputs match an independent truncated-power reference with a fixed four-frame delay, across eight SPI phases/two CS patterns and three live commits. This is bounded source-level evidence, not I2S/converter or general resource/transition qualification.

Register-bank commit flips active_regfile without invalidating fetched instruction/register tuples. Fetch/buffer/decode/operand stages retain queued values. Preprocessing feeds the previous input: dispatch in engine frame n executes input n−1; core.sample_out latches the completed result on the next tick. The composed engine output delay is four frames.

Continuous LEVEL/SVFLP/SVFHP fixtures send updates at input frames 128/256/384. Dispatch traces show activation at 136/264/392 for LEVEL and 132/260/388 for both SVFs. These eight/four-input delays are fixture-specific. The full-core WAV owner specifies the passing stateful comparison conditioned on dispatch registers; exact general activation timing remains unqualified.

Scratchpad instructions access the core's private mem array through its memory resource branch. Resource-format instructions carry a 12-bit address field; the actual core memory address width follows memory_size. Values persist between samples. A normal reset clears channel state and control, but does not initialize every memory word. full_reset walks the memory and instruction arrays, writing zeros before ready rises. A simulator starting a new program must exercise that full reset rather than treating incidental simulator zero initialization as product behavior. External scratchpad readback remains write snooping; how/does/the/core/return/scratchpad/memory/reads.md owns that distinct contract.

Sources: src/core.v, engine.v, preprocessing.v, postprocessing.v, instr_fetch_decode.v; verilator/test/spi_control/engine.cpp.
