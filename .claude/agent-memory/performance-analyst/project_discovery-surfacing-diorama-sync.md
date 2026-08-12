---
name: discovery-surfacing-diorama-sync
description: Cross-doc drift between discovery-surfacing.md and diorama-rendering.md on concurrent-cue count used for the ≤500 draw call budget claim
metadata:
  type: project
---

`design/gdd/discovery-surfacing.md` corrected its "concurrent cues at
tuning-knob extremes" figure from 2-3 to 5 during its round-1
`/design-review` (2026-08-05, performance-analyst/godot-specialist
finding, see Tuning Knobs and Open Question 3). `design/gdd/diorama-rendering.md`
line 426 was NOT updated to match — it still says "2-3 concurrent cues" and
uses that stale number to justify an unverified confidence claim ("stays
well within the ≤500 draw call budget"). Diorama Rendering's own budget
statement was written/confirmed against the wrong input.

**Why:** This is a real-world example of exactly the failure mode budget
tracking exists to catch — a downstream doc's risk claim silently going
stale when an upstream doc corrects a number mid-review. Discovery
Surfacing's Open Question 3 defers the actual profiling to a future named
`/smoke-check` gating Diorama Rendering's implementation story, rather than
requiring it now, before either doc's confidence claim is verified.

**How to apply:** When reviewing any GDD whose Formulas/Tuning Knobs get
corrected mid-review, always grep sibling/downstream docs for the same
numeric claim before considering the correction complete — round-1 fixes to
one doc do not propagate automatically. When a downstream doc states "stays
well within budget" as a fact rather than flagging it for profiling, treat
that as a red flag if it cites a number that could plausibly be stale.
Prefer making the profiling item BLOCKING (not just an Open Question) when
a downstream doc has already shipped an unverified confidence claim based
on a wrong number — one wrong number already reaching a "no special
handling needed" conclusion is evidence the smoke-check-later pattern
already failed once here.
