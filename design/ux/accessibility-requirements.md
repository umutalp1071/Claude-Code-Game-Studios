# Accessibility Requirements: Terrarium

> **Status**: Draft
> **Author**: user + ux-designer
> **Last Updated**: 2026-08-10
> **Accessibility Tier Target**: Standard
> **Platform(s)**: Web (Browser) only
> **External Standards Targeted**:
> - WCAG 2.1 Level AA
> - AbleGamers CVAA Guidelines — N/A (no voice chat/messaging features exist or are planned)
> - Xbox / PlayStation / Nintendo Accessibility Guidelines — N/A (Web-only, no console release planned)
> - Apple / Google Accessibility Guidelines — N/A (no mobile app release planned; browser-only, including mobile browsers)
> **Accessibility Consultant**: None engaged
> **Linked Documents**: `design/gdd/systems-index.md`, `design/ux/interaction-patterns.md`, `.claude/docs/technical-preferences.md`

> **Why this document is heavily trimmed from the studio template**: that template is
> written for a multi-platform action/RPG. Terrarium is a solo/small-team, Web-only,
> single-player, no-combat, no-dialogue, no-fail-state cozy sim with exactly two
> input gestures (tap, drag). Most template sections (console API integration,
> subtitle/VO systems, difficulty options, timed-input adjustments, aim assist,
> input remapping) are structurally not applicable, not corner-cut — kept as short
> "N/A" notes with a reason rather than left silently blank. Sections kept in full
> are the ones with real risk specific to this game's design (see Tier Rationale).

---

## Accessibility Tier Definition

### Tier Definitions

| Tier | Core Commitment | Typical Effort |
|------|----------------|----------------|
| **Basic** | Critical text readable. No feature requires color discrimination alone. Independent audio volume control. No photosensitivity risk. | Low |
| **Standard** | All of Basic, plus: full input coverage across supported devices, adjustable text size, at least one colorblind treatment, and a reduced-motion option where motion carries the game's own information. | Medium |
| **Comprehensive** | All of Standard, plus: screen reader support for any menu/UI surface, difficulty assist modes, HUD repositioning, visual indicators for all gameplay-critical audio. | High |
| **Exemplary** | All of Comprehensive, plus: full customization, cognitive load assist tools, tactile/haptic alternatives, external third-party audit. | Very High |

### This Project's Commitment

**Target Tier**: Standard

**Rationale**: Terrarium has almost none of the accessibility barriers that drive most game accessibility work — no combat, no fail state, no timer, no rapid input, no dialogue/VO, and only two input gestures (tap, drag), both single-pointer and device-native. Its real barrier is different in kind: the game's entire design deliberately has **zero UI chrome** (10 of 11 MVP systems declare no UI Requirements), meaning nearly every piece of information the player receives — a plant's STALLED state, a creature's arrival, a watering confirmation — is communicated through diegetic light/material/motion cues rather than through text, icons, or a HUD with a color-independent backup layer sitting behind it. That makes colorblind-safe cue design and a genuine reduced-motion alternative load-bearing, not optional, for this specific game — elevated into this tier's baseline rather than left at Comprehensive. Comprehensive/Exemplary tier items (console API integration, external audits, full customization matrices) assume a platform and team scale this solo/small-team, Web-only project doesn't have; committing to them now would be aspirational scope, not a real commitment. Standard tier, scoped to what this game actually contains, is achievable within the project's stated capacity.

**Features explicitly in scope (beyond generic tier baseline)**:
- Colorblind-safe verification for all 4 Diegetic Discovery Cue categories, the STALLED-state tint, and the Watering Substrate Sheen — these are the game's *only* information channel for several important state changes, with no text/icon fallback anywhere.
- A reduced-motion alternative for the Ease-in/Hold/Ease-out motion language (`design/ux/interaction-patterns.md` Pattern 10) — since nearly every visual signal in this game is an animation, "off" cannot mean "no signal at all."

**Features explicitly out of scope**:
- Console platform accessibility API integration (Xbox/PlayStation/Switch) — Web-only per `technical-preferences.md`.
- Subtitle/caption system, mono audio, hearing-aid frequency audit — no voiced dialogue or directional/positional audio exists or is planned (`ambient-audio.md`'s MVP scope is a single wordless nature soundscape).
- Full input remapping — the game has exactly two gestures (tap, drag), both bound to their platform-native input (mouse click / touch), nothing to rebind.
- Difficulty options, timed-input/QTE adjustments, hold-to-press alternatives, aim assist, sprint/platforming assists — structurally N/A; no fail state, no combat, no timer, no rapid input, no hold input, no aiming, no platforming exist anywhere in the 11 MVP GDDs (Anti-Pillars: NOT punishing, NOT god-mode).
- HUD repositioning, high contrast mode, mono audio, screen reader for the game world — Comprehensive-tier items, deferred (see Known Intentional Limitations).

---

## Visual Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Colorblind-safe treatment — Discovery Cues | Standard | Discovery Surfacing's 4 categories (Growth/Arrival/Departure/Detail Event) | Not Started | Categories are already distinguished by *where light/material behavior lives* and by motion (Arrival only), not by hue alone, per `discovery-surfacing.md`'s own Visual/Audio Requirements — verify this holds under Protanopia/Deuteranopia/Tritanopia simulation once real assets exist, since "warm bloom" vs. "cooling desaturation" could collapse under some color-vision deficiencies if not carefully authored. |
| Colorblind-safe treatment — STALLED tint | Standard | Diorama Rendering's per-plant STALLED cue | Not Started | This is the **one place in the whole game where color is currently the sole differentiator** between "paused, waiting on light" and "actively decaying" — see Color-as-Only-Indicator Audit below. `diorama-rendering.md`'s own STALLED_TINT is etiolation-based (pale yellow-green), not simply a generic desaturation, which helps but doesn't resolve the color-only risk on its own. |
| Colorblind-safe treatment — Watering Sheen | Standard | Diorama Rendering's Watering Substrate Sheen | Not Started | Lower risk — this cue is *triggered by the player's own action* (they just tapped), so timing alone already confirms the action registered even if the tint shift is hard to perceive; the `energy` boost on the sun `Light2D` is a secondary, non-color signal. |
| Text contrast | Standard | The one text surface in the game: Pattern 8's mute/volume control (icon-based, minimal text) | Not Started | Low surface area — this game has no menu text, no HUD text, no dialogue at MVP scope. Verify once the control's exact icon treatment is designed (`design/ux/interaction-patterns.md` Pattern 8, still an open item there). |
| Color-as-only-indicator audit | Basic | All diegetic cues | Not Started — see table below | |
| UI scaling | Standard | Pattern 8's control only | Not Started | Minimal relevance — nearly no text/UI to scale. `≥44×44px` hit area is already locked regardless of scale setting (`ambient-audio.md` Core Rule 7). |
| Brightness / gamma controls | Basic | Global | Not Started | Worth real attention here specifically — Diorama Realism is a lighting-driven visual identity (`game-concept.md`'s "light as mood" principle), so a player on a poorly-calibrated or low-brightness display is at higher risk of missing legibility-critical light cues than in a flatter-shaded game. |
| Screen flash / strobe warning | Basic | Detail Event's "brightest-but-briefest... point-light bloom" cue | Not Started | Low risk on inspection — Detail Event fires at most once per plant per catch-up batch (a rare, non-looping, single flash), far below the Harding FPA 3-flashes-per-second threshold. No dedicated warning screen needed; flagged here so it isn't silently unconsidered. |
| Motion/animation reduction mode | Standard | Every tweened effect in `design/ux/interaction-patterns.md` (Patterns 3, 4, 5, 6, 11, 12) | Not Started | **Load-bearing for this game, not optional polish.** A reduced-motion toggle cannot simply disable these animations — nearly every one of them *carries the actual information* (a Departure cue's settle, a STALLED plant's tint shift). The reduction must shorten/simplify the motion (e.g. faster ease, smaller amplitude) while preserving the signal, not remove it. Needs its own design pass once Diorama Rendering's implementation begins — flagged as an Open Question below, not solved here. |
| Subtitles | N/A | — | N/A | No voiced dialogue exists or is planned anywhere in this game's MVP or Full Vision scope. |

### Color-as-Only-Indicator Audit

| Location | Color Signal | What It Communicates | Non-Color Backup | Status |
|----------|-------------|---------------------|-----------------|--------|
| Plant STALLED tint | Pale yellow-green etiolation tint vs. full color | "Moisture is fine, light is currently blocking growth" vs. "growing/decaying normally" | **None currently specified.** The plant's `visual_stages` sprite index doesn't change while STALLED (that's the whole point — it's frozen, not decaying), so there's no non-color cue distinguishing "frozen because STALLED" from "frozen because nothing changed this tick." | Not Started — real gap, not yet resolved anywhere in `diorama-rendering.md` |
| Discovery Cue categories | Warm bloom (Growth) / catch-light (Arrival) / cooling desaturation (Departure) / bright flicker (Detail Event) | Which of 4 event types occurred | Arrival has genuine motion (the only category that does); Detail Event has brevity/intensity; Growth and Departure are the closest pair (warm vs. cool) and rely on temperature contrast, which several colorblind types compress | Not Started — needs colorblind-simulation verification once real assets exist |

---

## Motor Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Mouse/touch parity | Standard | Every interaction in the game | **Already committed at the platform level** | `technical-preferences.md` already mandates equal mouse+touch support with no hover-only interaction as the sole information channel; `input-abstraction.md` implements this directly. This document doesn't re-specify it — cross-referenced here so it's traceable from the accessibility side too. |
| One-hand operability | Standard | All interactions | **Already satisfied by design** | Every interaction in this game is single-pointer (tap or drag); `input-abstraction.md` Core Rule 7 enforces exactly one active pointer at a time — no two-hand or multi-touch gesture exists anywhere. Nothing to add. |
| Drag precision (fine motor) | Standard | Object Placement's repositioning | **Tracked, not yet resolved** | The one real motor consideration in this game. `object-placement.md`'s `LENIENCY` knob (0.7–0.9 default) already exists partly for this reason — objects can visually overlap before a placement is rejected, reducing precision demand. `input-abstraction.md`'s own Open Questions already separately flags that `threshold_touch` (16px) may make small, deliberate repositioning nudges systematically harder to land on touch than mouse — this document doesn't reopen that question, it inherits it. Owner: game-designer, per that GDD's own "flagged for Vertical Slice playtest validation." |
| Input remapping | N/A | — | N/A | Nothing to rebind — two gestures, both device-native. |
| Hold-to-press / rapid-input alternatives | N/A | — | N/A | No hold inputs, no rapid-input requirement anywhere (`tending-input.md` Core Rule 4 explicitly has no cooldown). |
| Timing adjustments, aim assist, sprint/platforming assists | N/A | — | N/A | No timers, no aiming, no movement/platforming exist in this game. |
| HUD repositioning | Comprehensive | — | Deferred | No traditional HUD exists to reposition; Pattern 8 is already fixed-corner by explicit GDD lock (`ambient-audio.md` Core Rule 7). |

---

## Cognitive Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Missed-cue recovery | Standard | Discovery Surfacing's reveal queue | **Real, unresolved tension — flagged, not solved** | `discovery-surfacing.md` Core Rule 6 explicitly states a cue that fades unseen is gone for good, by design (Anti-Pillar against demanding acknowledgment). This is defensible for the game's calm tone but is a genuine cognitive-accessibility gap for a player who's momentarily distracted, has slower visual processing, or steps away mid-reveal. Not resolved here — flagged as an Open Question below, matching this project's own precedent of "reintroduce only with playtest evidence" (see `input-abstraction.md`'s `pointer_ignored` history). |
| Tutorial / onboarding | Standard | Whole game | **Gap — no owner exists yet** | No dedicated onboarding/tutorial system appears anywhere in `systems-index.md`. `game-concept.md`'s Flow State Design says onboarding is "try each tool with zero fail risk, learning by doing" — but nothing in any of the 11 MVP GDDs actually implements guided first-contact. Not this document's gap to close; flagged so it isn't lost. Owner: game-designer, before Vertical Slice. |
| Visual backup for audio-only information | Standard | Ambient Audio | **Already satisfied by design** | `ambient-audio.md`'s own Silence-Safe Composition section already states nothing in the visual layer may depend on audio for legibility. Confirmed here, not re-derived. |
| Pause | N/A | — | N/A | No time pressure to pause from — backgrounding the browser tab is this game's de facto pause (`time-drift.md`), and gameplay is never blocking (Discovery Surfacing Core Rule 9). |
| Difficulty options, quest/objective clarity, navigation assists | N/A | — | N/A | No difficulty axis, no quests/objectives (Anti-Pillar: NOT god-mode / no imposed goals), no world navigation (single jar). |
| Cognitive load documentation | Comprehensive | — | See Per-Feature Matrix below (lightweight version kept at Standard tier) | |

---

## Auditory Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Independent volume control | Basic | The one audio layer in the game | **Already committed** | `ambient-audio.md` Core Rule 7 locks a persisted `ambient_volume`/`muted` control. A single control (not 4 separate music/SFX/voice/UI buses) is correct here, not a shortfall — this game has exactly one audio layer (the ambient loop + its reactive swells share one bus); there is no separate voice, SFX, or UI-sound category to split out. |
| Closed captions for gameplay-critical SFX | N/A | — | **Already satisfied by design** | `ambient-audio.md`'s Silence-Safe Composition already guarantees no sound carries information without a visual equivalent — nothing here needs a caption. |
| Subtitles, mono audio, directional-audio indicators, hearing-aid frequency audit | N/A | — | N/A | No dialogue; no directional/positional audio exists or is planned. |

---

## Platform Accessibility API Integration

| Platform | API / Standard | Status | Notes |
|----------|---------------|--------|-------|
| Web (Browser) | Godot 4.7.1 AccessKit / native browser accessibility tree | **Unverified — see Open Questions** | Godot's AccessKit integration (added 4.5+) covers `Control` node menus on native builds; whether it functions at all under **Web export's Compatibility/WebGL2 renderer** (a canvas-rendered target) is not confirmed anywhere in this project's `docs/engine-reference/godot/` snapshot. This is a genuine post-cutoff engine-version question, not a design decision — flagged for verification, not assumed either way. |
| Console (Xbox/PlayStation/Switch), Mobile app (iOS/Android) | — | N/A | Not targeted platforms per `technical-preferences.md` (Web export only; mobile *browsers* are covered under the Web row above, a native mobile app is not planned). |

---

## Per-Feature Accessibility Matrix

Lightweight version — only the 5 systems with direct player-facing accessibility surface are listed. The remaining 6 MVP systems (Content Data, Input Abstraction, Ecosystem Simulation, Time & Drift, Creature Behavior, Persistence/Save) have no accessibility surface of their own; their properties flow through the presentation systems below.

| System | Visual Concerns | Motor Concerns | Cognitive Concerns | Auditory Concerns | Addressed |
|--------|----------------|---------------|-------------------|------------------|-----------|
| Tending Input | None — no visual signal of its own | None — single tap, no precision demand | None | None | Yes |
| Object Placement | None of its own (rendering is Diorama Rendering's job) | Fine-motor drag precision (LENIENCY knob partially mitigates; touch-threshold question tracked upstream) | None | None | Partial |
| Discovery Surfacing | None of its own (pacing only, not rendering) | None | Missed-cue recovery gap (flagged above) | None | Partial |
| Diorama Rendering | STALLED tint is a color-only indicator (real gap); Discovery Cue categories need colorblind verification; every effect needs a reduced-motion alternative | None | None | None | Not Started |
| Ambient Audio | None | None | None | Already satisfied by design (Silence-Safe Composition) | Yes |

---

## Accessibility Test Plan

| Feature | Test Method | Test Cases | Pass Criteria | Responsible | Status |
|---------|------------|------------|--------------|-------------|--------|
| Colorblind simulation — Discovery Cues, STALLED tint, Watering Sheen | Manual — Coblis simulator on real render captures, once Diorama Rendering ships | Each of the 4 Discovery Cue categories; STALLED vs. GROWING vs. DECAYING; watering-triggered vs. idle substrate | A player can distinguish every state pair above in all 3 simulated colorblind types without relying on hue alone | ux-designer / art-director | Not Started |
| Mouse/touch parity | Manual — complete a full tending session using only mouse, then only touch | Watering, repositioning, wobble, snap-back, mute control | Identical outcomes and comparable effort on both input methods | qa-tester | Not Started |
| Reduced-motion mode | Manual — enable mode, observe every animated pattern in `interaction-patterns.md` | Patterns 3, 4, 5, 6, 11, 12 | Every effect's underlying signal is still perceivable, motion is reduced/shortened, not silently removed | ux-designer | Not Started (mode doesn't exist yet — see Open Questions) |
| Text contrast — mute control | Automated — contrast analyzer on final icon/control art | Pattern 8's control at rest and active states | ≥4.5:1 against its background per WCAG AA | ux-designer | Not Started |
| Godot Web export + AccessKit | Manual — small throwaway probe (same class of test as this project's existing Web-export verification plan) | Does AccessKit expose any node under Compatibility/WebGL2 to a browser screen reader | Confirms whether Comprehensive-tier menu screen-reader support is even reachable on this platform, informing a future tier decision | technical-director/godot-specialist | Not Started |

---

## Known Intentional Limitations

| Feature | Tier Required | Why Not Included | Risk / Impact | Mitigation |
|---------|--------------|-----------------|--------------|------------|
| Screen reader support for the jar scene itself | Comprehensive+ | This game has almost no menu/text surface to begin with (Pattern 8 is the only candidate), and whether Godot's AccessKit even reaches Web export's Compatibility renderer is unverified (see Open Questions) — likely not achievable regardless of tier commitment | Blind/low-vision players relying on a screen reader get no access to the diorama itself; the one control (mute/volume) may or may not be reachable depending on the AccessKit/Web-export answer | None planned for MVP — revisit if the AccessKit verification comes back positive |
| Discovery cue missed-cue recovery | Standard+ | Deliberately excluded by `discovery-surfacing.md`'s own design (Anti-Pillar against demanding acknowledgment) | Players with slower visual processing, momentary distraction, or short absences during the ~30s reveal window permanently miss that discovery | None planned — matches this project's own "reintroduce only with playtest evidence" precedent; revisit post-Vertical-Slice if playtesting surfaces genuine confusion |
| Reduced-motion mode | Standard | Not yet designed — this document identifies the need, doesn't design the solution | Motion-sensitive players currently have no way to reduce the game's (load-bearing) animation without losing information | Owner: ux-designer, before this feature enters implementation — tracked as an Open Question below |

---

## Audit History

| Date | Auditor | Type | Scope | Findings Summary | Status |
|------|---------|------|-------|-----------------|--------|
| — | — | — | — | No audit performed yet — this document is the first accessibility pass for this project | Not Started |

---

## External Resources

| Resource | URL | Relevance |
|----------|-----|-----------|
| WCAG 2.1 (Web Content Accessibility Guidelines) | https://www.w3.org/TR/WCAG21/ | Foundational standard — contrast ratios, text sizing; directly applicable since this is a Web export |
| Game Accessibility Guidelines | https://gameaccessibilityguidelines.com | Game-specific checklist organized by category and cost — useful even though most "high-cost" categories don't apply to this game |
| Colour Blindness Simulator (Coblis) | https://www.color-blindness.com/coblis-color-blindness-simulator/ | Free tool for the colorblind verification pass this document repeatedly flags as needed |

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Does Godot 4.7.1's AccessKit integration expose anything to browser screen readers under the Compatibility/WebGL2 export target, or is it native-build-only? | technical-director / godot-specialist | Before committing to (or ruling out) any Comprehensive-tier screen-reader work | Unresolved — genuinely unconfirmed in `docs/engine-reference/godot/`, not merely unresearched |
| How should reduced-motion mode work when the motion itself carries the information (Discovery Cues, STALLED tint), rather than being pure decoration? | ux-designer | Before Diorama Rendering's implementation begins | Unresolved |
| Should Discovery Surfacing's missed-cue behavior be revisited, or is "gone if you miss it" an acceptable, intentional accessibility tradeoff for this game's calm-tone design? | game-designer / creative-director | Before Vertical Slice, informed by playtest evidence | Unresolved — tracked, not blocking |
| Does the STALLED-tint color-only-indicator gap need a non-color backup (e.g. a subtle particle/texture change), or is the etiolation-based tint itself considered sufficient once verified under colorblind simulation? | art-director / technical-artist | Before Diorama Rendering's implementation story is marked Done | Unresolved |
