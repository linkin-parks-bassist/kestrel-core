---
status: "unverified"
created_at: "2026-09-19T23:57:07+10:00"
scope: "local"
source: "README.md; src/core.v; src/engine.v"
---
Status: Green

I2S delivers a sample to the engine. Each core reads instructions from block RAM; operand fetch uses a scoreboard to stall hazards; the branch router dispatches arithmetic or resource operations; the commit path orders side effects; the mixer applies gains and combines the two pipelines.

Source: README.md; src/core.v; src/engine.v
