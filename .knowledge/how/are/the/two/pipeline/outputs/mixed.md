---
status: green
revised_at: "2026-10-06T02:51:39+11:00"
---

Kestrel already implements smooth pipeline transitions and optional tail-preserving swaps. David reports audibly seamless transitions working before 2026, with tails added deliberately to extend them; recent descriptor-reload qualification is not the origin or qualification boundary of that established transition engine.

`preprocessing_stage` applies global and per-pipeline input gains. `postprocessing_stage` applies global and per-pipeline output gains, sums the two results and saturates to sample width. `gain_controller` in src/mixer.v changes the pipeline gains on sample ticks.

For an ordinary crossfade, it ramps the outgoing output down while ramping the incoming output up. With swap_tail_enable, it instead ramps the outgoing input down while bringing the incoming output up, leaving the outgoing pipeline's stored audio/state to decay. The decay phase reduces the outgoing output gradually and then closes it when its envelope is low or gain reaches zero; closure restores its input gain for reuse. This uses the two existing pipelines rather than discarding a sounding delay's state at the switch.

Interface emits COMMAND_ENABLE_TAIL before applicable pipeline changes in components/core/kest_pipeline.c and kest_update.c; Core controller.v carries that choice to the mixer. Preserve this behavior when extending descriptor hotswap/loading. Codec power-cycle pops and the planned postprocessing declicker concern separate boundaries.

Source: src/{preprocessing,postprocessing,mixer,controller}.v and the Interface command/transition call sites. Audible maturity is David's direct report; it does not claim exhaustive automated coverage of every future reload/schema case.
