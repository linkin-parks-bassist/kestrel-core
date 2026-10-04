---
status: green
revised_at: "2026-10-04T06:39:18+11:00"
---

Each core has 16 channels. Channel zero carries the sample between effects; channels 1–15 hold intermediate values. The wide accumulator is updated by MAC instructions.

Each block has two registers read as instruction operands. They are written through programming/live-update commands, rather than by DSP instructions. Two register banks let commands update the inactive bank; reg_writes_commit switches the active bank and starts copying its contents into the other bank. For a multi-block program, copying follows block traversal and signals regfile_syncing until the address sequence wraps; merely waiting with an unstarted core does not make it finish. Single-block programs have a special completion path, and empty programs do not start copying. Do not issue further live writes into a bank while it is synchronizing.

The bare core's instruction fetcher traverses continuously once enabled. Its enclosing pipeline supplies sample ticks. A direct-core test must account for repeated traversals and in-flight instructions when checking live updates. Scratchpad external writes do not retire through the channel commit master; commit IDs are allocated for channel/accumulator writes.

Source: src/core.v, src/regfile.v, src/instr_fetch_decode.v, src/operand_fetch.v, src/ext_rw.v; verilator/test/dsp_core/tests.cpp compiled readback check.
