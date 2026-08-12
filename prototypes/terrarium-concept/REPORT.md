# Concept Prototype Report: Terrarium

> **Date**: 2026-08-02
> **Prototype Path**: HTML
> **Concept File**: design/gdd/game-concept.md

---

## Hypothesis

If the player tends a small terrarium (watering, repositioning objects) and the ecosystem drifts over time between visits, they will feel curious satisfaction noticing what changed — evidenced by spontaneously pointing out a specific change without being prompted, within their first couple of visits.

---

## Riskiest Assumption Tested

That players will find ecosystem changes meaningful enough to care about — the simulation needed to feel alive, not random or static. This was identified as the single biggest risk in the concept doc, since no other system in the game carries the core loop if this fails.

---

## Approach

Built a single self-contained HTML prototype: a jar with 3 moss patches, one creature (a snail), a moisture meter, a "Water" action, a draggable rock (mouse + touch via Pointer Events), and a "Let Time Pass" button that fast-forwards 30 simulation ticks at once to compress a "return visit" into one click.

**Path chosen:** HTML
**Reason for path:** The hypothesis is about whether the simulation logic reads as alive versus random/static — not about timing-sensitive input feel — so browser latency was not a concern, and HTML let the build happen in one sitting with zero install friction.

**Shortcuts taken (intentional):**
- Placeholder shapes/CSS only — no final art, palette, or atmosphere
- Single creature type, single moss color, single decorative object (rock)
- No persistence, no real-time day/night visuals, no audio, no menus/onboarding
- Tuning constants hardcoded at the top of the script for easy adjustment

---

## Result

The tester confirmed the cause-and-effect chain was clear and legible every time: watering raised moisture, moss grew while moisture stayed in the optimal range, the snail appeared and wandered once total moss coverage crossed a threshold, and both the moss and the snail died back when moisture was allowed to run dry. In the tester's words: *"I understood what was happening and could see the relationship between my actions and the ecosystem's response."*

The strongest moment was the snail's appearance and independent wandering after a few water-and-advance cycles: *"It felt like my actions had actually influenced the ecosystem instead of triggering an immediate scripted event."*

The flattest moment came after one full cycle (grow → creature appears → dry out → both disappear) had been observed: *"I felt like I had already discovered the entire state space of the simulation... pressing 'Let Time Pass' no longer created anticipation."* The tester attributed this explicitly to the prototype's deliberately narrow scope (3 moss patches, 1 creature, no environmental variables), not to a flaw in the underlying mechanic.

Separately, the tester noted the experience felt visually "cold" and "artificial" — but attributed this to the intentional lack of final art/atmosphere in a concept prototype, not to the mechanics: *"The 'cold' feeling comes mainly from the current prototype's visual design and color palette rather than the mechanics themselves."*

---

## Metrics

| Metric | Value |
|--------|-------|
| Path used | HTML |
| Iterations to playable | N/A — one-shot HTML build |
| Prototype duration | Single session, well under the 1-day cap |
| Playtesters | 1 internal |
| Feel assessment | Cause-and-effect (watering → moisture → moss growth/decay → creature appearance/departure) was consistently legible and understood — no confusion or perceived randomness reported at any point. Emotional "discovery" payoff dropped off quickly once the small state space (3 patches, 1 creature, binary appear/leave logic) had been fully observed. |
| Hypothesis verdict | PARTIALLY CONFIRMED |

---

## Recommendation: PROCEED

The core loop is sound: tending actions produce fast, legible feedback, while the ecosystem's slower drift was understood as caused by the player's care rather than perceived as arbitrary noise — the central risk (that changes would read as random) did not materialize. However, the full "oh, that's different" discovery feeling was only partially achieved, because the tester exhausted the entire visible state space within a handful of "Let Time Pass" cycles — a direct consequence of the prototype's intentionally minimal scope (3 moss patches, 1 creature, no environmental variables), not a mechanic failure. The tester's own read matches this: proceed with the concept, but treat *possibility-space depth* as a first-class design requirement in the ecosystem system GDD, not an afterthought layered on later.

---

## If Proceeding

- **Core tuning values discovered:** Moisture decay of ~3/tick against a +25 watering action, with a 40-75 optimal growth range, produced clearly legible cause-and-effect — a reasonable starting point for real tuning. A full behavior cycle was fully "discovered" within roughly 5-10 "time pass" presses — this sets a rough floor for how much breadth the real ecosystem needs before repeat visits stop feeling exhausted.
- **Assumptions confirmed:** The concept doc's "balanced reactivity" design (fast tending feedback + slower emergent drift) produces legible, understood cause-and-effect rather than confusing randomness — the central risk from the concept doc did not materialize.
- **Assumptions disproved / refined:** The concept doc's Pillar 1 ("A World in Your Hands") assumed a small, contained world would feel surprising largely on its own. This prototype suggests containment alone isn't sufficient — it's the *richness and variety* of organisms/interactions that sustains the "oh, that's different" feeling over repeated visits. The MVP's planned scope (3 plant/moss types + 2 creature types, per the Scope Tiers in the game concept doc) should be treated as a hard floor for sustaining curiosity, not generous headroom — worth re-examining in `/map-systems` and the ecosystem system GDD.
- **Emergent mechanics worth formalizing:** The snail's condition-based appear/wander/leave behavior (driven by ecosystem state thresholds rather than a fixed schedule or direct player command) was specifically called out as the most convincing moment in the whole prototype. Preserve this exactly as a formal mechanic — creature presence emerges from ecosystem state, never from direct player placement (matches Pillar 3, Care Not Control). The prototype's small "detail" system (rare visual events on moss patches) went unmentioned by the tester — worth explicitly testing at higher density before assuming it lands.

> Note: Visual "coldness" was consistently attributed to intentional placeholder art, not the mechanic — this should be re-validated once `/art-bible` visual direction is applied, but is not a blocker to proceeding with design.

**Next steps:**
1. `/design-review design/gdd/game-concept.md`
2. `/gate-check`
3. `/map-systems`
4. `/design-system [mechanic]` (use learnings in Tuning Knobs and Formulas sections — especially possibility-space depth as a target, not just moisture/growth constants)

---

## Lessons Learned

- **What assumptions were broken by actually building this?** None broken outright — the reactive/emergent balance produced legible cause-and-effect exactly as designed. What shifted is the assumption that a small, contained world (Pillar 1) is inherently enough to sustain surprise on its own; richness of interactions turns out to matter more than raw smallness.
- **What surprised us that didn't show up in the brainstorm?** How quickly even a correctly-functioning system's state space gets exhausted by one attentive tester. Pillar 1's two halves — "small enough to know" and "always surprising" — are in real, concrete tension, not just rhetorical tension, and need explicit design answers (more organisms, more interactions, rarer events) to both hold true simultaneously.
- **What would we test differently next time?** A second, expanded HTML prototype or spike specifically targeting possibility-space depth — add 1-2 more creature types and an environmental variable or two (e.g., light) and measure how many "time pass" cycles it takes before a tester reports the same "I've seen it all" flatness. That number becomes the real design target for the MVP's content scope.

---

> *Prototype code location: `prototypes/terrarium-concept/`*
> *This code is throwaway. Never refactor into production.*
