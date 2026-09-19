---
status: "unverified"
created_at: "2026-09-20T00:04:27+10:00"
scope: "local"
source: "src/instr_fetch_decode.v:8-120"
---
Status: Green

`block_fetcher` cycles the instruction read address through `n_blocks_running`, resets it when no blocks run, and uses a skid register for the fetched instruction/register payload if downstream is stalled. It tracks lack of address progress up to CYCLES_PER_SAMPLE as a stuck signal. Source: src/instr_fetch_decode.v:8-120
