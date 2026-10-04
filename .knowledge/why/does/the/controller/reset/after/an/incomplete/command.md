---
status: green
revised_at: "2026-09-20T00:10:49+10:00"
---

`CONTROLLER_TIMEOUT_CYCLES` is set to 112500000. Its comment explains that a wait state with no new bytes can result from software alignment error or transfer corruption; timeout recovery prevents the command FSM from staying locked indefinitely. Source: include/controller.vh:25-31; src/controller.v
