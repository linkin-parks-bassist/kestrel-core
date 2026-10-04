---
status: green
revised_at: "2026-09-20T00:04:27+10:00"
---

`health_monitor` follows sample magnitude and counts consecutive rail hits and high-envelope samples. It latches health false on peak or envelope threshold detection; reset restores health true. The mixer separately uses envelope followers during tail swapping. Source: src/health_monitor.v:1-145; src/mixer.v
