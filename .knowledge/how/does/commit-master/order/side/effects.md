---
status: green
revised_at: "2026-10-04T10:16:29+11:00"
---

Each execution branch must present results strictly in its own instruction order. David identifies this as a crucial architectural invariant: commit_master selects only a branch head whose commit ID equals next_commit_id; it does not search behind that head or repair within-branch overtaking. If a later result hides an earlier one on the same branch, retirement can wedge.

Every branch presents result, destination and commit ID. commit_master asserts readiness only for a valid branch whose ID equals next_commit_id, except during sample_tick. Accepted IDs advance in sequence; delayed writeback writes channel or MAC accumulator. A sample tick injects the input sample into channel 0.

Filter, polynomial and SVF remain one INSTR_BRANCH_FILT through rsp_req_str_filter in src/ext_rw.v. That stage accepts a result-producing instruction only in IDLE, waits in REQ for its response, then holds result/destination/commit ID in DONE until downstream acceptance before returning to IDLE. Extracting polynomial_unit behind filter_master does not add a parallel instruction branch or a completion merger. The master's active request selects a unit and holds subsequent result requests until response. SVF update has no channel result and follows its existing acknowledgement path; subsequent SVF reads wait for the unit's corresponding output. Internal calculation overlap must not be mistaken for permission to reorder branch results.

Sources: David's explicit branch-linearity requirement; src/commit_master.v, src/core.v, src/ext_rw.v and src/filter.v. Separate polynomial and SVF numerical tests do not constitute a dedicated mixed-operation retirement/backpressure regression.
