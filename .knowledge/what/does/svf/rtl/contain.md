---
status: green
revised_at: "2026-10-04T10:10:46+11:00"
---

src/svf.v is empty. The working Chamberlin implementation is filter_unit_svf in src/filter.v, instantiated by filter_master. Production pipeline.v connects that master to dsp_core; instr_dec.v routes SVF update and low/band/high reads to the filter branch. ENABLE_SVF in include/build.vh now gates both the module and its master instantiation. It is enabled by default alongside ENABLE_POLYNOMIAL; the optional normal filter is excluded by default. KESTREL_CUSTOM_BUILD allows command-line selection.

The filter-engine owner specifies the Q15 coefficient contract, state scheme and numerical coverage. Changes should target the real implementation rather than populating the empty placeholder.

Sources: src/svf.v, src/filter.v, src/pipeline.v, src/core.v, src/instr_dec.v, include/build.vh, include/defs.vh and repository-wide ENABLE_SVF search.
