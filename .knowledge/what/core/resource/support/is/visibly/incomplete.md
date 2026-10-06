---
status: green
revised_at: "2026-10-05T11:24:56+11:00"
---

Allocated LUTs are excluded from scope at David's direction: he considers the SPI machinery needed to load them excessive and prefers the polynomial cruncher for programmable function approximation. They are not deferred requirements or gaps blocking supported-resource verification.

David also questions keeping the existing RTL LUT machinery and suggests polynomial/Taylor approximations instead. Removal of built-in LUTs is not yet selected or implemented. Compare bounded sine/tanh approximation error, coefficient quantization, fixed-point intermediate ranges, cycles and ROM/DSP utilization before choosing replacements. Taylor versus other polynomial fits is open; no universal error or speed advantage is established.

Built-in sine (handle 0) and tanh (handle 1) remain implemented in current source. Their ROM initialization and installed-image qualification belong to the LUT-master and build owners. Polynomial coefficient programming and fixed-point arithmetic belong to the filter-engine and compiler/verification owners. The shipped polynomial sine already supplies a bounded approximation example; the shared effect-verification owner records its exhaustive error evidence.

Interface has no authored allocated-table resource type. Core lut_master marks other handles invalid; its default branch remains in PROCESSING until reset. These unsupported paths are not allocation/upload features to implement. Built-in tests do not qualify arbitrary handles.

Sources: David's scope/rationale and tentative replacement direction, src/lut_master.v, Interface components/parser/kest_dict_extract.c and components/core/kest_resource.c, and shared verification guidance.
