---
status: "unverified"
updated_at: "2026-09-20T00:13:25+10:00"
---
Status: Green

Kestrel Core is the FPGA DSP engine for the pedal, targeting Gowin GW2AR. `src` contains Verilog top-level, dual-engine processing, instruction pipeline, commit logic, mixer, resource engines and I/O. `include` holds opcode, command and configuration headers; `verilator` has simulation harnesses and unit tests; `luts` holds LUT data and `eff` example programs.

The `what/` branch covers architecture, encoding, resources, configuration, every first-party RTL source by role and focused behavior/gaps. `how/` traces sample processing and simulation; `where/` locates commands; `why/` explains commit and throughput choices. Source review shows SDRAM delay wired through pipeline, engine and top despite the stale README statement. Hardware correctness remains unverified. Retrieve the focused leaf and current RTL before changing a path.
