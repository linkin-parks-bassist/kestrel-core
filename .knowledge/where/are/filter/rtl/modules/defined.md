---
status: green
revised_at: "2026-10-04T10:10:48+11:00"
---

src/filter.v defines filter_unit_normal and filter_unit_normal_fixed under ENABLE_FILTER, filter_unit_svf under ENABLE_SVF, and the always-present filter_master dispatcher. src/polynomial.v defines polynomial_unit under ENABLE_POLYNOMIAL. include/build.vh owns the selections. The filter-engine owner describes their behavior and limitations.

Sources: src/filter.v, src/polynomial.v and include/build.vh.
