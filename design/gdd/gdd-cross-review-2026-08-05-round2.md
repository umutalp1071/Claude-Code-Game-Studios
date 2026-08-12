# Cross-GDD Review Report (Round 2)
Date: 2026-08-05
GDDs Reviewed: 8 (Content Data, Input Abstraction, Object Placement, Ecosystem Simulation, Tending Input, Time & Drift, Creature Behavior, Persistence/Save)
Systems Covered: all 8 currently-Approved MVP GDDs, plus `game-concept.md` and `systems-index.md` as baseline context.

This is a follow-up run to `gdd-cross-review-2026-08-05.md` (round 1), which found 6 blocking issues; all 6 were fixed same-session without a fresh specialist re-review. This round independently re-derives whether those fixes are actually consistent (not just present) and hunts for anything new, including issues the fix round itself may have introduced.

---

### Consistency Issues

#### Blocking (must resolve before architecture begins)

🔴 **`persistence-save.md`'s `CONDITION_STREAK_MAX` is pinned against a stale, already-superseded `N_departure_ticks` range**
`persistence-save.md` (Formulas Variables table and Open Questions) states the coupling as: *"`ecosystem-simulation.md`'s own Tuning Knobs give `N_departure_ticks` a safe range of 4–8."* But `ecosystem-simulation.md`'s own round-16 fix (same session) explicitly replaced that range with **10–30**, and its own Open Questions names the exact companion update owed: *"`persistence-save.md`'s `CONDITION_STREAK_MAX` constant (already flagged there as a tracked cross-GDD coupling pending exactly this value)."* That companion edit never landed. Once the required pre-implementation tuning pass picks a value in the new 10–30 range, `CONDITION_STREAK_MAX=5` will reject every legitimate `condition_streak_ticks` value above 5 — silently discarding valid saves at `save_blob_validity`. **Fix**: update both citations in `persistence-save.md` to the current 10–30 range and flag `CONDITION_STREAK_MAX=5` itself as provisional pending the same tuning pass.

🔴 **`time-drift.md`'s calibration paragraph still asserts the exact claim `ecosystem-simulation.md` identified as the Anti-Pillar violation**
`time-drift.md` Formulas ("Calibration against Ecosystem Simulation's locked values") states: *"...it also safely clears `N_spawn_ticks=3` and can clear `N_departure_ticks=5` for creature debounce purposes — a spawn or departure can plausibly resolve in one visit."* `ecosystem-simulation.md` Core Rule 7's own round-16 correction directly quotes and refutes this: *"`time-drift.md`'s own calibration states this as a deliberate goal... That goal is correct for spawning but wrong for departure... a weekend-length absence... is enough to depart both Snail and Moth, every time... which is what actually trips the Anti-Pillar."* `time-drift.md` was never edited to reflect this (its header still reads "Last Updated: 2026-08-04," predating the round-16 fix). Two Approved documents now make directly contradictory claims about whether the current departure-timing property is safe. **Fix**: correct or caveat `time-drift.md`'s calibration paragraph to note departure is intentionally decoupled from the "resolves within one visit" goal per `ecosystem-simulation.md` Core Rule 7.

#### Warnings (should resolve, but won't block)

⚠️ **`content-data.md` repeatedly claims the `pause_duration_min/max` companion edit to `creature-behavior.md` is still outstanding — it already landed.** Six separate places (Player Fantasy correction, Core Rule 5 note, Dependencies, Tuning Knobs, Open Questions ×2) describe this as owed, but `creature-behavior.md` Formulas already reads per-type values (Snail `[3.0,6.0]`, Moth `[1.5,3.0]`) — fixed in that document's own round 1. Carried over from round 1's warning list, not part of the required 6 fixes.

⚠️ **`systems-index.md` is internally inconsistent about Creature Behavior's dependency on Time & Drift.** The Systems Enumeration table (row 7) correctly lists Time & Drift as a dependency; the separate Dependency Map narrative section (Feature Layer, item 3) still omits it — the round-2 fix (Creature Behavior Core Rule 8 widening) was propagated to one table but not the other in the same file.

⚠️ **`systems-index.md` omits Content Data from Persistence/Save's declared dependencies** in both the Systems Enumeration table and the Dependency Map, despite `persistence-save.md`'s own Dependencies section listing Content Data as a hard dependency. Carried over from round 1, still unfixed.

⚠️ **Object Placement's multi-object AC vs. Persistence/Save's single-object blob schema.** `object-placement.md` AC6a exercises 3+ simultaneously placed objects, but `persistence-save.md`'s Core Rule 1 blob only serializes one object's position — no array schema exists yet. Not reachable at MVP (only the rock exists); carried over from round 1, unfixed.

---

### Game Design Issues

#### Blocking
None.

#### Warnings

⚠️ **Same-session feedback asymmetry favors Object Placement over Ecosystem Simulation, the system explicitly designated the "core hypothesis."** Object Placement has a complete real-time reward loop (drag-follow, hit-test, wobble, snap-back) every visit; Ecosystem Simulation's growth payoff is deferred to the *next* session's catch-up batch by design (`ecosystem-simulation.md`/`tending-input.md`'s own 2026-08-05 corrections). Nothing prevents the secondary, aesthetic system becoming the de facto moment-to-moment loop by default of feedback timing alone. Recommend a Vertical Slice playtest question on this, and consider richening the still-open watering-cue treatment specifically to narrow the gap.

⚠️ **Attention-budget spike at session start with no pacing system yet designed.** Up to 5 simultaneous "notice this" signals (plant states, creature presence, detail events, save-confirmation cue) land in one atomic, unstaggered render, per Time & Drift's own AC11. Discovery Surfacing — the system that owns "what changed" — is `Not Started`. This is in tension with Pillar 4 (small persistent details, not one big reveal). Recommend locking staggered/sequenced reveal as a hard requirement in Discovery Surfacing's own GDD.

⚠️ **Moisture convergence makes `light_level` causally inert for most of a real absence.** `light_level`'s three-state formula is overridden by DECAYING whenever moisture is out of range, "regardless of light." Per `time-drift.md`'s own per-plant exit-tick trace, moisture exits every plant's tolerance band within 6–12 ticks of an unwatered absence — meaning `light_level`'s influence on outcomes is only live for that initial window, and pure unobservable noise for the remainder of any longer catch-up (up to `max_catchup_ticks=84`). This compounds with the already-tracked dormancy-convergence limitation and light's ~40-tick memorizable period into a stronger flatness risk than either tracked item alone states. The currently-drafted fix (`light_phase_offset`) targets light's texture, not moisture's convergence dominance — recommend the Vertical Slice exit criteria explicitly test this compounded mechanism, with a candidate fix aimed at moisture's own convergence (e.g. per-plant decay floors), not only light's phase.

⚠️ **Object Placement's creature-wander influence is arithmetically real but likely imperceptible.** The excluded destination-sampling disc around the rock (`footprint_size + CREATURE_CLEARANCE = 12` units) is ≈2.4% of the jar's ≈18,850 sq-unit sampling area; repositioning the rock redistributes at most ~5% of wander probability mass. The "real, not purely aesthetic" resolution (round 13) is true on paper but unlikely to be felt by a player. Recommend either softening the Player Fantasy claim to "subtle/statistical," or strengthening `CREATURE_CLEARANCE`'s effect if the design wants this to read as meaningful.

⚠️ **Watering's zero-cost, zero-cooldown, wide-tolerance design gives the player no skill floor for the game's primary care action**, and no same-session feedback to distinguish "good" from "mediocre" tending — connects directly to the same-session feedback asymmetry above.

⚠️ **Player-identity skew toward "operator" rather than "witness."** The frequent, clear, same-session action (watering) is causal-operator; the diffuse, rare, cross-session payoff (growth) is the intended "witness" identity Ecosystem Simulation's Player Fantasy names. Recommend an explicit Vertical Slice playtest question on which identity the player actually reports.

---

### Cross-System Scenario Issues

Scenarios walked: 3
- Session start after a long absence (Time & Drift → Ecosystem Simulation → Creature Behavior → Persistence/Save)
- Content Data update removes a referenced CreatureTypeDef (Content Data → Persistence/Save)
- Tab backgrounded mid-drag, then closed (Input Abstraction → Object Placement → Persistence/Save)

#### Blockers
None promoted to blocker (the race below is reachable but gated behind the same unverified-mechanism class already flagged BLOCKING upstream — logged as a warning against that existing gate, not a new independent blocker).

#### Warnings

⚠️ **Tab backgrounded mid-drag, then closed — Input Abstraction, Object Placement, Persistence/Save.** A mid-drag interruption is detected by two *independently* unverified browser-bridging mechanisms: Object Placement's revert relies on Input Abstraction's `Window.focus_exited` (Core Rule 8); Persistence/Save's backgrounding write relies on `visibilitychange`/`pagehide` via `JavaScriptBridge` (Core Rule 5). Both are separately flagged BLOCKING-pending-verification in their own documents, but neither states which fires first or whether Object Placement's synchronous revert-to-last-committed-position is guaranteed to complete before Persistence/Save reads "current" position for its write. Object Placement's own Drag-follow formula is explicitly unclamped during a drag, so a save captured mid-race could persist an uncommitted, never-validated position. No AC in either document exercises this interaction. **Recommendation**: fold this ordering question into the same throwaway verification prototype already planned for both mechanisms individually (owner: technical-director) rather than treating them as two separate unknowns.

#### Info
ℹ️ **Content Data update removes a referenced CreatureTypeDef** — confirmed correctly handled by `persistence-save.md`'s existing last-known-good scope correction (AC12c); both blob tiers fail identically, falling to default-init. No action needed.
ℹ️ **Detail event vs. STALLED visual cue** — mutually exclusive by formula construction (a detail event requires strict GROWING; STALLED is a different branch), so no rendering conflict is possible at the two states' intersection.

---

### GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| persistence-save.md | `CONDITION_STREAK_MAX`/coupling note cites the pre-widening `N_departure_ticks` range (4-8, now 10-30) | Consistency | Blocking |
| time-drift.md | Calibration paragraph still asserts the departure-timing claim `ecosystem-simulation.md` corrected as an Anti-Pillar violation | Consistency | Blocking |
| systems-index.md | Two internal inconsistencies (Creature Behavior↔Time & Drift dependency row; Persistence/Save missing Content Data) | Consistency | Warning |
| content-data.md | Repeatedly claims `pause_duration_min/max` companion edit is outstanding; it already landed | Consistency | Warning |
| object-placement.md | Player Fantasy overstates the felt magnitude of creature-wander influence | Design Theory | Warning |

---

### Verdict: FAIL

Two blocking consistency issues survive — both are half-applied companion edits from the round-16 `N_departure_ticks` widening fix, not new design defects. No blocking game-design or scenario issues were found; 7 design-theory warnings and 1 scenario warning are tracked but do not block architecture.

### Required actions before re-running

1. `persistence-save.md`: update `CONDITION_STREAK_MAX`'s coupling citations from "4-8" to "10-30," and flag the constant's own value (5) as provisional pending the deferred tuning pass.
2. `time-drift.md`: correct or caveat the calibration paragraph's "can clear `N_departure_ticks=5`... plausibly resolve in one visit" claim to match `ecosystem-simulation.md`'s Core Rule 7 correction.

Both are small, text-only, same-class fixes as the round-16 session that introduced the gap — no design rework required.
