---
status: "unverified"
created_at: "2026-09-20T00:05:07+10:00"
scope: "local"
source: "src/preprocessing.v; src/postprocessing.v; src/mixer.v"
---
Status: Green

`preprocessing_stage` applies global and per-pipeline input gains. `postprocessing_stage` applies global and per-pipeline output gains, adds the two results, then saturates to the sample width. `gain_controller` changes per-pipeline gains across sample ticks for crossfade or tail-preserving swap. Source: src/preprocessing.v; src/postprocessing.v; src/mixer.v
