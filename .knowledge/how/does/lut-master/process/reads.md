---
status: green
revised_at: "2026-10-04T11:57:00+11:00"
---

lut_master accepts a pending request, selects built-in sine (handle 0) or tanh (handle 1), waits for base and next ROM samples, then runs sequential interpolation. Other handles raise req_invalid; allocated LUT support remains unimplemented.

Both built-in ROMs have 2048 signed16 words, loaded from luts/sin_q15_full.hex and luts/tanh_q15.hex. Sine takes index x[14:4], fractional bits x[3:0], and wraps the next index to zero. Its signed input spans two equal periods. Tanh indexes (x + 0x8000)[15:5], uses x[4:1] as fraction, and clamps the next index at 2047.

The four-bit sequential interpolator forms a signed16 difference. Its top fractional bit contributes arithmetic difference>>1; subsequent terms halve signed magnitudes with truncation toward zero. This differs from one rounded linear multiply. The superproject sample model reproduces those steps using the actual ROM words. Exhaustive compiled sine/tanh fixtures match all 65536 input codes each; independent quadrant/periodicity and tanh monotonicity/endpoints checks complement the shared-ROM comparison. These tests do not establish allocated tables or physical audio.

Sources: src/lut_master.v, src/lut.v, src/linterp.v, include/lut.vh, luts/*.hex and superproject tools/test_eff_state.py.
