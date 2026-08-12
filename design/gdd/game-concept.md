# Game Concept: Terrarium

*Created: 2026-08-02*
*Status: Draft*

---

## Elevator Pitch

> It's a cozy ecosystem-tending sim where you care for a single living terrarium in a jar — a tiny, fully-knowable world that keeps quietly changing, building a calm daily ritual you return to indefinitely.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Cozy sim / ecosystem simulation (terrarium care sim) |
| **Platform** | Web / Browser |
| **Target Audience** | See Target Player Profile below |
| **Player Count** | Single-player |
| **Session Length** | Short (5-15 min) typical; occasional longer browsing sessions |
| **Monetization** | None yet — TBD, likely premium or free |
| **Estimated Scope** | Medium (4–6 months, solo, full vision); MVP rebaselined 2026-08-09 — original "2-4 weeks" was a pre-design estimate, now stale against 11 fully-specified MVP GDDs (see Scope Tiers). Concrete MVP timeline pending `/estimate` against epics/stories once Technical Setup produces them. |
| **Comparable Titles** | Tiny Glade, Viridi, Stardew Valley (for the "small persistent world" feeling) |

---

## Core Fantasy

You are the quiet caretaker of a tiny living world in a jar — entirely yours, always changing, and never demanding. Unlike open-world survival or farming sims, the whole world here is small enough to fully know, which is what makes its ongoing surprises feel personal rather than overwhelming.

---

## Unique Hook

It's like a bonsai/aquarium sim, AND ALSO a slow-burn ecosystem simulation — moss spreads, bugs move in, light shifts with real seasons, so the *same jar* looks different every time you check on it, without ever punishing you for looking away.

---

## Visual Identity Anchor

**Selected Direction**: Diorama Realism — photoreal-adjacent lighting and material detail within the tiny frame of the jar, like a nature macro photograph you could stare at for an hour. Simplified fidelity for the MVP; full macro-photoreal polish deferred to a post-MVP pass (see Scope Tiers).

**One-line visual rule**: "If it wouldn't survive a macro-lens close-up, it doesn't belong in the jar."

**Supporting visual principles**:
1. **Material truth** — glass, moss, water, and wood must read as real materials, even in the simplified/lower-detail MVP form.
   *Design test*: Torn between a flat cartoon shader vs. a simplified-but-physically-lit material? Choose the physically-lit option even at lower resolution.
2. **Scale intimacy** — camera and framing should always emphasize the tiny scale of the world (macro-lens language: shallow depth of field, close framing).
   *Design test*: Torn between a wide establishing shot vs. close macro framing? Choose macro framing.
3. **Light as mood** — lighting communicates time of day/season more than UI does.
   *Design test*: Torn between a UI weather icon vs. an actual lighting change in the scene? Choose the scene lighting change.

**Color philosophy**: A grounded, naturalistic palette (greens, browns, glass-blue) that shifts subtly with season and light rather than saturated "gamey" colors — believability over vibrancy.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (sensory pleasure) | 1 (co-primary) | Diorama-realism lighting/material detail, ambient nature soundscape |
| **Fantasy** (make-believe, role-playing) | 4 | Caretaker identity, present but secondary |
| **Narrative** (drama, story arc) | N/A | No plot |
| **Challenge** (obstacle course, mastery) | N/A | No fail state, no mastery-based difficulty |
| **Fellowship** (social connection) | N/A | Single-player, no social systems |
| **Discovery** (exploration, secrets) | 2 | Emergent ecosystem surprises, small persistent details |
| **Expression** (self-expression, creativity) | 3 | Arranging objects, light personalization of the jar |
| **Submission** (relaxation, comfort zone) | 1 (co-primary) | Low-stress tending loop, no schedule or urgency |

### Key Dynamics (Emergent player behaviors)
- Players will develop personal rituals around checking the terrarium (e.g., "morning coffee, check the jar").
- Players will start recognizing individual inhabitants (a particular snail, a moss patch) and treat them as consistent little characters.
- Players will experiment with placement and arrangement for their own aesthetic satisfaction, independent of "optimal" ecosystem outcomes.

### Core Mechanics (Systems we build)
1. **Tending actions** — gentle, tactile input: water/mist, reposition objects. (Adding organic matter was an early concept-stage idea; **corrected 2026-08-09** — no MVP system implements it, see MVP Definition. Post-MVP stretch mechanic, not yet designed.)
2. **Ecosystem simulation** — moisture and light drive moss growth, insect population, and decay cycles (**corrected 2026-08-09**: the approved `ecosystem-simulation.md` GDD's two-axis model is moisture+light, not moisture+light+organic-matter); balanced between reactive (fast feedback) and emergent (self-directed) behavior.
3. **Time-based drift** — a day/night (and eventually seasonal) cycle changes the terrarium even when the player is away.
4. **Detail/discovery surfacing** — small persistent changes are made noticeable each visit, with no fail state and no urgency attached.

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, meaningful choice) | No schedule, no imposed goals — freeform tending and arrangement | Core |
| **Competence** (mastery, skill growth) | Learning the ecosystem's internal cause-and-effect logic over time | Supporting |
| **Relatedness** (connection, belonging) | Attachment to a specific place and its small consistent inhabitants, rather than to characters or other players | Supporting |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Explorers** (discovery, understanding systems, finding secrets) — How: uncovering the ecosystem's emergent interactions over time
- [x] **Achievers** (goal completion, collection, progression) — How: light completionist appeal (seeing all organism types), never the core draw
- [ ] **Socializers** (relationships, cooperation, community) — Not served; no fellowship pillar
- [ ] **Killers/Competitors** (domination, PvP, leaderboards) — Explicitly excluded (see Anti-Pillars)

### Flow State Design

- **Onboarding curve**: The first few minutes let the player try each tending tool with zero fail risk, learning by doing rather than by instruction.
- **Difficulty scaling**: No traditional difficulty curve; "growth" is the ecosystem's rising complexity (more organisms, more interactions) over time, not player skill demand.
- **Feedback clarity**: Visual and audio cues gently highlight what's new or changed since the last visit.
- **Recovery from failure**: N/A by design — nothing in the ecosystem is ever "worse," only "different" (see Anti-Pillars).

---

## Core Loop

### Moment-to-Moment (30 seconds)
Check what's changed since the last visit (surfaced immediately via the staggered discovery reveal), perform 2-3 small tending actions (water/mist, reposition — see MVP Definition; adding organic matter is a post-MVP stretch mechanic, not yet designed or implemented), and feel the tactile response of each action land right away — watering visibly raises moisture and triggers its own cue on the spot, repositioning snaps/wobbles into place live. **Corrected 2026-08-09**: growth/decay itself is never live within a session (`time-drift.md` Core Rule 6 — ticks, and therefore `growth_stage` changes, only ever resolve between visits); what's immediate is the tending feedback and the discovery reveal of what already changed, not new growth happening as you watch.

### Short-Term (5-15 minutes)
A visit: examine the ecosystem closely, do a round of tending, maybe rearrange something for personal satisfaction, and take in the discovery feed revealing what changed since last time (new moss patch, a bug has moved in) — all surfaced at visit-start, not appearing mid-visit. "One more thing to check" comes from that slow discovery feed, not a task list.

### Session-Level (30-120 minutes)
Rare by design for this genre — a longer session is several 5-minute visits chained with idle browsing and a larger layout change (moving rocks, replanting). Natural stopping point: once you've "seen what's new," nothing forces you to stay.

### Long-Term Progression
The ecosystem itself grows in complexity and diversity: more organisms move in, new interactions emerge (moss attracts bugs, bugs attract a small creature, decay creates new moss), and possibly new jars/terrariums become available alongside the first. "Done" is loose by design, like Stardew Valley — no forced end, just deepening richness.

### Retention Hooks
- **Curiosity**: What changed in the jar since I last looked? What new organism or interaction might appear?
- **Investment**: A jar shaped by weeks of small personal arrangement choices, and the small "residents" the player has come to recognize.
- **Social**: None by design (see Anti-Pillars).
- **Mastery**: Understanding of the ecosystem's internal logic (what causes what) deepens over time.

---

## Game Pillars

### Pillar 1: A World in Your Hands
The terrarium must always feel small enough to fully know, but alive enough to keep surprising you.

*Design test*: Torn between making the terrarium bigger/more complex vs. making an existing element deeper? We choose depth over size.

### Pillar 2: Nothing Is Ever Finished, Nothing Is Ever Late
No schedules, no fail states, no urgency. The terrarium waits for you exactly as you left it — plus whatever it quietly became on its own.

*Design test*: Torn between a decay mechanic that punishes neglect vs. one that just makes things look different after time away? We always choose "different," never "punished."

### Pillar 3: Care, Not Control
Player actions nudge the ecosystem; they never fully dictate it.

*Design test*: Torn between a direct "place creature here" tool vs. an indirect "create conditions where a creature might appear"? We choose indirect.

### Pillar 4: Every Detail Rewards Attention
Small, easy-to-miss details matter more than big flashy events.

*Design test*: Torn between one big visual spectacle vs. several small persistent details? Budget goes to small details first.

### Anti-Pillars (What This Game Is NOT)

- **NOT punishing**: We will not add fail states, timers, or neglect-punishing decay — it would compromise *Nothing Is Ever Finished, Nothing Is Ever Late*.
- **NOT god-mode**: We will not give the player direct control over ecosystem outcomes (e.g., spawn any creature on demand) — it would compromise *Care, Not Control*.
- **NOT sprawling**: We will not expand into multiple large, separate biomes/worlds in the base scope — it would compromise *A World in Your Hands*.
- **NOT competitive**: We will not add competitive, social, or comparison features (leaderboards, sharing scores) — they would compromise the private, personal-space fantasy at the game's core.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Tiny Glade | Small-scope, detail-obsessed diorama building with no fail state | We add a living, simulated ecosystem rather than a static building toy | Validates the commercial appeal of tiny, calm, highly-detailed games |
| Viridi | Terrarium/plant-care sim, calm daily ritual | We add an emergent creature ecosystem and stronger visual fidelity | Validates the terrarium-care niche directly |
| Stardew Valley | Villager-like personality applied to small persistent elements; daily ritual structure | We compress the "world" down to a single jar rather than a full valley | Validates that small persistent details can carry emotional weight without an open world |

**Non-game inspirations**: Macro nature photography, real-world terrarium/bonsai care as a hobby, ASMR nature videos, quiet nature documentaries (close-up nature segments).

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 18-40 |
| **Gaming experience** | Casual to mid-core — comfortable with light systems, not seeking high challenge |
| **Time availability** | Short daily sessions (5-15 min), occasionally longer browsing sessions on weekends |
| **Platform preference** | Browser, often during short breaks |
| **Current games they play** | Stardew Valley, Minecraft, Tiny Glade, Animal Crossing |
| **What they're looking for** | A low-pressure, beautiful space to decompress that doesn't demand a large time commitment |
| **What would turn them away** | Forced dailies/streaks, monetization pressure, any punishing mechanic, need for a large time investment to "keep up" |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | TBD — run `/setup-engine`; Web/Browser target favors a lightweight, browser-exportable pipeline |
| **Key Technical Challenges** | Tuning an emergent ecosystem simulation to feel alive without being chaotic/unreadable or static/boring; achieving diorama-realism lighting/material quality performantly in a browser context |
| **Art Style** | 2.5D or 3D stylized-realistic diorama (simplified for MVP; full macro-photoreal detail as a later polish pass) |
| **Art Pipeline Complexity** | Medium for MVP (simplified diorama realism); High for full vision (macro-photoreal detail) |
| **Audio Needs** | Moderate — an ambient nature soundscape is central to the calm feeling |
| **Networking** | None |
| **Content Volume** | MVP: 1 jar, 3 plant/moss types, 2 creature types. Full vision: multiple jars/biomes, seasonal variants, expanded creature roster |
| **Procedural Systems** | Rule-based ecosystem simulation drives organic-looking growth/decay patterns (systemic, not level-generation procedural) |

---

## Risks and Open Questions

### Design Risks
- The ecosystem simulation could feel either too random (unreadable) or too static (boring) — needs dedicated tuning time, not just decoration.
- Without characters or plot, sustaining "never boring" long-term interest depends entirely on the simulation being genuinely surprising over weeks/months of play.

### Technical Risks
- Achieving convincing diorama-realism lighting/material fidelity in a browser-exportable build may hit performance or engine limitations.
- Tuning a believable, emergent ecosystem simulation is a non-trivial simulation design problem, not just content authoring.

### Market Risks
- Niche audience if positioned wrong — needs clear "cozy/calm" marketing rather than generic "sim" framing (mitigated by Tiny Glade/Viridi comps showing a viable market).

### Scope Risks
- Full macro-photoreal art fidelity does not fit a solo "weeks" timeline — resolved by deferring full fidelity to a post-MVP polish pass (see Scope Tiers).
- Ecosystem simulation tuning could take longer than expected if initial rules don't produce satisfying emergent behavior.

### Open Questions
- How much real-time vs. accelerated time should terrarium drift run on? Needs prototyping — test both and see which produces a better "something changed since I left" feeling.
- Does the ecosystem simulation need a complexity cap to stay readable, or can it grow indefinitely? Needs prototyping/playtesting once MVP ecosystem rules exist.

---

## MVP Definition

**Core hypothesis**: Players want to return, day after day, to a single tended terrarium jar because tending it and noticing what changed is satisfying on its own, without any goals, fail states, or content beyond the jar itself.

**Required for MVP**:
1. One terrarium jar scene with simplified Diorama Realism art (physically-lit materials, macro framing, lower asset detail than full vision)
2. Tending actions: water/mist, reposition 2-3 object types
3. Ecosystem simulation: 3 plant/moss types + 2 creature types with moisture/light-driven growth and simple emergent interactions
4. Time-based drift (day/night at minimum; season is a stretch goal) that changes the jar between visits, with no fail state

**Explicitly NOT in MVP** (defer to later):
- Multiple jars/biomes
- Full macro-photoreal art fidelity
- Music beyond a single ambient loop
- Any collection/achievement UI
- Any social/sharing features

### Scope Tiers (if budget/time shrinks)

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 1 jar, 3 plant/moss types, 2 creatures | Simplified diorama-realism art, basic tending, day/night drift | Rebaselined 2026-08-09: pending `/estimate` against Technical Setup epics/stories — 11 MVP systems are now fully specified (vs. the pre-design "2-4 weeks" guess), so this figure is no longer load-bearing |
| **Vertical Slice** | Same jar, full tending set | Full simplified-art polish pass, refined ecosystem tuning | Pending same `/estimate` pass |
| **Alpha** | 2-3 jars/biomes | Seasons (rough), expanded creature roster | +2-3 months |
| **Full Vision** | Full jar roster | Full macro-photoreal art pass, seasons, collectibles, full ambient sound design | 4-6 months total (solo) |

---

## Next Steps

- [ ] Get concept approval from creative-director
- [ ] Fill in CLAUDE.md technology stack based on engine choice (`/setup-engine`)
- [ ] Create game pillars document (`/design-review` to validate)
- [ ] **Prototype core idea** (`/prototype [core-mechanic]`) — before writing GDDs, validate the concept is worth designing
- [ ] If prototype PROCEEDS: Decompose concept into systems (`/map-systems`)
- [ ] Design each system (`/design-system [system-name]`) — use prototype learnings in Tuning Knobs and Formulas sections
- [ ] Build vertical slice in Pre-Production (`/vertical-slice`) — validate full game loop before committing to Production
- [ ] Validate core loop with playtest (`/playtest-report`)
- [ ] Plan first milestone (`/sprint-plan new`)
