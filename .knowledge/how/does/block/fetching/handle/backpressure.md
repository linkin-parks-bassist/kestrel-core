---
status: green
revised_at: "2026-09-27T22:47:11+10:00"
---

`block_fetcher` cycles the instruction read address through `n_blocks_running`, resets it when no blocks run, and uses a skid register for the fetched instruction/register payload if downstream is stalled. It tracks lack of address progress up to CYCLES_PER_SAMPLE as a stuck signal. Source: src/instr_fetch_decode.v:8-120

The address wraps to block 0 without waiting for `sample_tick`. Only backpressure gates fetch. Consequently the next sample's program runs ahead: every block that does not read c0 executes before the new sample arrives. The first reader of c0 then stalls in operand fetch on the channel-0 reservation (see how/does/the/operand/fetch/stage/work.md), and backpressure parks everything behind it until the tick. In flanger.eff, for example, the whole LFO update (blocks 0–12) completes early and `madd c7 [gain] c0 c0` waits in fetch_3.
