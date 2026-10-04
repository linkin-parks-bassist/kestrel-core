---
status: green
revised_at: "2026-09-20T00:05:06+10:00"
---

`lut_master` accepts a pending request, selects built-in sin or tanh by handle, waits for base and next LUT samples, and runs sequential interpolation using fractional input bits. Other handles raise req_invalid; the source comment says allocated LUT support is for later. Source: src/lut_master.v:17-170
