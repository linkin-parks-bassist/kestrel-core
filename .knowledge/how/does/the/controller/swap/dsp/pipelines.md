---
status: "unverified"
created_at: "2026-09-20T00:04:27+10:00"
scope: "local"
source: "src/controller.v:155-210; src/mixer.v:21-190"
---
Status: Green

The controller distinguishes front and back pipeline by `current_pipeline`. Its FSM includes programming, warmup, swap wait and reset states, with health input and tail-enable state. The gain controller performs either regular CROSSFADE or tail-preserving ramp/decay/close states after swap_pipelines, moving per-pipeline gains on sample ticks. Source: src/controller.v:155-210; src/mixer.v:21-190
