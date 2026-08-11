# Art Bible: Terrarium

> **Status**: In Progress — authored 2026-08-11, scope this session: Sections 1–4
> (Visual Identity Foundation), per the Technical Setup → Pre-Production gate
> requirement. Sections 5–9 (production guides + reference direction) are
> deferred — Section 5 (Environment Design Language, specifically lighting
> technique) and Section 8 (Asset Standards, specifically texture/VFX
> budgets) are intentionally held until Gate C4 (Diorama Rendering's
> Light2D/Compatibility-renderer frame-budget verification, currently
> unmeasured on any device) produces real numbers, per Art Director
> guidance at the 2026-08-11 gate check.
> **Author**: user + art-director
> **Last Updated**: 2026-08-11
> **Visual Identity Anchor Source**: `design/gdd/game-concept.md`
> **Engine/Platform**: Godot 4.7.1, Web export, Compatibility renderer (OpenGL ES3/WebGL2) — no Forward+ features available

---

## 1. Visual Identity Statement

### Direction: Diorama Realism

Terrarium is rendered as **Diorama Realism**: photoreal-adjacent lighting and
material detail within the tiny frame of the jar, like a nature macro
photograph you could stare at for an hour. This is the single visual
direction for the entire game — every asset, effect, and UI element is
judged against it.

MVP ships a simplified-fidelity pass of this direction (lower asset detail,
fewer authored variations); full macro-photoreal polish is a deferred
post-MVP pass, per the Scope Tiers in `design/gdd/game-concept.md`.
Simplified fidelity means the same rule at lower resolution — never a
cartoon fallback.

### The One-Line Visual Rule

> **If it wouldn't survive a macro-lens close-up, it doesn't belong in the jar.**

This is the single test for every asset decision in this document. If
you're unsure whether a texture, silhouette, effect, or UI treatment fits,
hold it up against this line before asking anything else.

### Supporting Visual Principles

**1. Material truth** — glass, moss, water, and wood must read as real
materials, even in the simplified/lower-detail MVP form.
*Design test*: Torn between a flat cartoon shader and a
simplified-but-physically-lit material? Choose the physically-lit option,
even at lower resolution.
*Serves*: Pillar 4, Every Detail Rewards Attention. A world meant to be
leaned into only rewards that attention if what you find under close
inspection holds up — a flat shader breaks exactly when this game is being
played.

**2. Scale intimacy** — camera and framing always emphasize the tiny scale
of the world: macro-lens language, shallow depth of field, close framing.
*Design test*: Torn between a wide establishing shot and close macro
framing? Choose macro framing.
*Serves*: Pillar 1, A World in Your Hands. Framing is how the game keeps
proving its own premise — a jar small enough to fully know. A wide shot
argues the opposite.

**3. Light as mood** — lighting communicates time of day and season more
than UI does.
*Design test*: Torn between a UI weather icon and an actual lighting change
in the scene? Choose the scene lighting change.
*Serves*: Pillar 2, Nothing Is Ever Finished, Nothing Is Ever Late. A UI
icon announces a state change and implies you should act on it. A lighting
shift just says the world moved on — different, never late, never a task.

### Platform Reality Check: What "Photoreal-Adjacent" Means on Compatibility/WebGL2

Web export locks this game to the **Compatibility renderer** (OpenGL
ES3/WebGL2) — Forward+-only features (SDFGI, volumetric fog/light shafts,
real-time per-pixel GI) are not available, full stop. "Photoreal-adjacent"
here means:

- **Baked, not real-time, lighting.** Material lit-ness comes from
  hand-authored shading baked into the asset, not a runtime GI solve.
  Already locked in `design/gdd/diorama-rendering.md`: a sparse Light2D
  layer (1–3 ambient + up to 5 cue-driven, ~8 concurrent worst case)
  accents that baked base — it does not replace it.
- **Depth of field is authored, not rendered.** Shallow-DOF is faked via
  softened edges and reduced contrast on background layers, not a runtime
  blur shader.
- **Mood lighting is a scene-wide tint, not per-pixel relighting.**
  Day/night and seasonal shifts are a `CanvasModulate` multiply tint over
  the baked scene, and per Core Rule 8 that tint is cosmetic — never gated.
- **Open risk, not yet closed**: Light2D/normal-map/glow behavior under
  Compatibility/WebGL2 is flagged BLOCKING and only partially verified
  (`docs/architecture/adr-0009-diorama-rendering-light2d-web-strategy.md`
  Gate C1 passed provisionally on placeholder art only; Gate C4, the actual
  frame-budget question, has no measurements on any device including
  mobile). This art bible's future Lighting & VFX section (deferred, see
  status header) is written assuming that verification passes; if it
  doesn't, the Light2D-accent layer needs rework — the Diorama Realism
  direction itself doesn't change, it just falls back to baked-only.

"Photoreal-adjacent" is a lighting-and-material *quality target*, not a
rendering-technique promise — the technique is deliberately the cheapest
one that can still hit the quality bar on this renderer.

### Failure Test

If a cropped screenshot of any single element in the jar could be mistaken
for a stylized mobile-game icon rather than a close-up photograph, the
visual identity has failed. This applies equally to a hero asset (the jar)
and a background filler asset (a moss clump) — there is no "it's just
background" exception. Per Pillar 4, background is exactly where attention
gets rewarded first.

---

## 2. Mood & Atmosphere

### Why Four States, Not the Usual Set

Terrarium has no combat, no levels, no menus, no win/lose states — so this section maps mood to the states the game actually has, not a genre template. Time & Drift's INACTIVE/CATCHING_UP/ACTIVE machine is a *session lifecycle*, not a mood target: CATCHING_UP is architecturally invisible (its own Acceptance Criteria guarantee no intermediate state is ever rendered), so it gets no mood entry — there is nothing to look at yet.

The four states below are the ones the player actually perceives, drawn directly from Time & Drift, Discovery Surfacing, and Ambient Audio's Player Fantasy sections. The day/night cycle is deliberately **not** a fifth state — Diorama Rendering already locks it as a `CanvasModulate` tint riding on top of whichever state is active, never gating or replacing it (Section 1, Principle 3). It's documented here as an orthogonal modifier layer for that reason.

---

### State 1 — First-Ever Session

The one moment in the entire game that isn't about noticing change, because nothing has happened yet to notice. `ticks_to_apply=0`, the jar starts in its authored initial state, "not pre-decayed" (`time-drift.md` Edge Cases) — and Discovery Surfacing generates zero items, by design (Core Rule 3). This is introduction, not payoff.

- **Primary emotion/mood target**: quiet permission to look closely — the game handing the player something already complete and asking nothing of them yet. Not awe, not spectacle; the opposite of a title-screen flourish.
- **Lighting character**: neutral and true-to-material. `day_night_phase` is 0.0 at session start by construction, which lands exactly on `t=1.0` — the gradient's midday stop, `(1.0, 1.0, 1.0)`, i.e. *no tint at all*. This isn't a coincidence worth overriding: the game's very first frame is lit at true material color, nothing dramatized, which is its own quiet statement of "this is real, not staged."
- **Atmospheric descriptors**: unhurried, complete, undramatized, still, intimate.
- **Energy level**: contemplative, at rest — the calmest state in the game, because it's the only one with zero motion of any kind layered on top (no cue, no reveal, no tint drift yet perceptible).

### State 2 — Routine Return, Nothing Changed

When the delta set is empty (Discovery Surfacing stays IDLE) — the common case for a same-day recheck. Time & Drift's own worked example calls this "barely any drift, appropriately less dramatic than the daily visit." This is not a lesser version of State 1; it's warmer and more familiar, because it *is* the player's jar, just not visibly different today.

- **Primary emotion/mood target**: quiet familiarity — "it's still here, still mine," reassurance rather than discovery. Comfort, not disappointment at the absence of news.
- **Lighting character**: whatever point in the day/night cycle the visit happens to land on — deliberately unstaged, since real-time drift means this is uncontrolled. No cue-driven light of any kind is added; the entire mood comes from the *absence* of any added light event, not from a special treatment.
- **Atmospheric descriptors**: familiar, settled, private, steady, unremarkable-in-a-good-way.
- **Energy level**: contemplative, low — nearly as calm as State 1, but registers as *returning* rather than *arriving*: the difference is entirely emotional register, not visual event, since mechanically almost nothing distinguishes this state from State 1 besides the player's own memory of the place.

### State 3 — Discovery Reveal (REVEALING)

The staggered "what changed" sequence: per-element diegetic cues (Growth's subsurface glow, Arrival's specular catch-light, Departure's cooling desaturation, Detail Event's brief point-light bloom) activating one at a time, item 0 visible the instant the jar first renders, no waiting period, deliberately overlapping rather than queuing strictly. This is Discovery Surfacing's own Player Fantasy: "a small, private 'oh' of recognition" — not a payoff, explicitly not engineered as a climax (Core Rule 8's own corrected wording strikes "the payoff" framing).

- **Primary emotion/mood target**: gentle noticing — curiosity quietly rewarded, arriving in pieces rather than all at once. The opposite of a notification badge.
- **Lighting character**: the baseline day/night tint is completely unchanged underneath — mood shift comes entirely from the per-element cues themselves, small pinpoints of warm/cool light at specific locations in the jar, never a global wash or flash. Locally, brief moments of slightly higher contrast exactly where a cue lives; everywhere else in the frame, unchanged.
- **Atmospheric descriptors**: attentive, staggered, softly punctuated, alive-in-places, unhurried.
- **Energy level**: measured — the only state with real built-in forward motion (the queue's pacing), but capped at 6–34 seconds and explicitly never rushed. Distinctly more awake than States 1–2, still nowhere near urgent — this is the ceiling of this game's entire energy range, and it's still gentle.

### State 4 — Settled Presence / Idle Tending

The bulk-of-session state: after or without a reveal, the player waters, repositions, or simply lingers — Ambient Audio's own Player Fantasy names this directly ("the audio equivalent of a macro photograph you could stare at for an hour"). This is where the Core Loop's Moment-to-Moment and Short-Term rhythms actually live.

- **Primary emotion/mood target**: sustained, ambient contentment — presence without demand. The game's steady-state resting mood, and the one most players spend the most time in.
- **Lighting character**: baseline day/night tint, but here it's actually likely to be *seen moving* — a 5-minute session shows roughly a quarter of a full cycle, a 15-minute session most of one loop. This is the one state where the light-as-mood principle (Section 1) is most visibly doing its job in real time.
- **Atmospheric descriptors**: tactile, lived-in, responsive-but-calm, immersive, unforced.
- **Energy level**: contemplative, with brief measured upticks exactly at the instant of a tending action (watering's moisture rise, substrate sheen, audio swell, all sharing one ~3-second envelope) that resolve back to contemplative within seconds — a small ripple on an otherwise still surface, never a sustained spike.

---

### The Day/Night Modifier Layer (Not a Fifth State)

Diorama Rendering locks the key light's *direction* as permanently fixed, baked upper-left into every asset at authoring time — day/night only ever drifts the `CanvasModulate` tint and one accent light's color/intensity, never its direction and never the light-vs-shadow logic of any sprite. Concretely: cool desaturated blue at deepest night → a warm amber peak at dawn/dusk → neutral true-material color at midday, eased continuously through a cosine curve with no visible seam at the cycle wrap.

Treat state and time-of-day as two independent axes, not one combined mood:

- **State** (1–4 above) supplies *what the player is feeling* — energy level, attentional focus, emotional register.
- **Day/night phase** supplies *temperature only* — warm or cool, nothing else.

A Discovery Reveal at deep-night tint is still measured and attentive, just cooler-lit. Settled Presence at the dawn amber peak is still contemplative, just warmer-lit. Neither axis is allowed to reach into the other's job — this is the direct application of Section 1's Core Rule that the tint is cosmetic, never gated, and it holds exactly as true for mood as it does for gameplay state.

---

## 3. Shape Language

Terrarium has no cast in the traditional sense — no hero, no villain, no silhouette-readable-at-100-yards combat roster. Its "cast" is 3 plant types, 2 creature types, 1 repositionable object, and the jar that holds them. Shape language here has one job the usual character-silhouette framework doesn't: make `growth_pattern`, creature identity, and "what's alive vs. what's inert" legible through form alone, before color ever enters — because Diorama Rendering's Core Rule 2 renders discrete growth stages with **no cross-fade**, and Pillar 4 depends on the player's eye catching a *shape* difference, not a color swap, when something has changed.

### Plant Silhouette: `growth_pattern` as the Primary Shape Grammar

Content Data's three `growth_pattern` values map 1:1 onto the MVP's three plant types (`moss`=carpet, `fern`=clump, `flower`=climb) and onto three orthogonal spread axes, already given numeric floors by Diorama Rendering's Growth Pattern Scaling formula:

| Pattern | Type | Scale floor (X, Y) | Silhouette behavior |
|---|---|---|---|
| carpet | Moss | 0.35, 0.35 (uniform) | expands outward on both axes evenly — a flat patch widening |
| clump | Fern | 0.55, 0.40 | modest footprint growth, faster vertical bulk — a mass rounding and rising in place |
| climb | Flower | 0.75, 0.45 | footprint nearly fixed, height dominant — a line reaching upward |

That scale transform is the **floor**, not the payoff — it's a guaranteed minimum size delta even against lazy art. The real silhouette work belongs to the authored `visual_stages` sprites themselves. A real fern doesn't get "bigger blob" as it grows, it unfurls new fronds; a real flower doesn't just stretch taller, it adds structure (stem, bud, bloom) that changes its silhouette's *shape*, not just its bounding box. Content Data's own Growth Pattern Scaling divergence cap (±0.30 per axis, tightened this review specifically because an earlier over-stretched `climb` value visibly warped baked shadow) means the numeric transform alone cannot carry full differentiation between patterns at intermediate stages — the sprite has to.

**Design test**: silhouette a `visual_stages` entry to solid black. Can you identify its `growth_pattern` and roughly which stage it is, with zero color or texture information? If carpet, clump, and climb read as interchangeable blobs at the same scale, the pattern isn't doing its job.
**Serves**: Pillar 4, Every Detail Rewards Attention, and Section 1's material-truth principle — a growth silhouette that's only a uniform scale-up fails the macro-lens test the same way a flat cartoon shader would; real growth restructures a form, it doesn't just inflate it.

**Decay reads the same silhouettes backward.** Content Data's Core Rule 8 locks decay as the *same* `growth_stage` index retreating toward 0 through the *same* sequence — never a separate "withered" asset. Shape language must honor this literally: no stage's silhouette may be authored to look structurally "broken" or "sickly," because that exact silhouette is revisited on the way down from a healthy plant that simply hasn't been watered in a while, and is revisited again on the way back up. Every stage's shape must read as a legitimate point in a living plant's form, in either direction.
**Serves**: Pillar 2, Nothing Is Ever Finished, Nothing Is Ever Late — the Anti-Pillar's "not punishing" requirement, expressed as a shape constraint rather than a color one.

### Creature Silhouette: Closing the Gap `growth_pattern` Left Open

Diorama Rendering's Visual/Audio Requirements already commits Snail and Moth to a **color/value** contrast ("terracotta shell against green moss," "a paler wing value against dark leaf-shadow") — that's real, but it's Section 4's job, and color alone is a weaker signal than the categorical shape split plants get for free from `growth_pattern`.

**Correction (2026-08-11, art-director gate review, verified against `content-data.md`'s current Open Questions):** an earlier draft of this section stated Content Data "names this gap explicitly and leaves it open." That overstates it — Content Data's Open Questions explicitly **rules this a non-issue at MVP's 2-creature-type scope** (2026-08-03, `creative-director` ruling: Snail and Moth are already maximally distinct via species identity and `visual_ref` alone; the thread "reopens only if the creature roster grows large enough (~4+ types) that two creatures could plausibly share both species and silhouette family"). It is not an open gap this section closes; it's a design decision this section makes anyway, because strong silhouette language is worth authoring on its own merits regardless of what Content Data's schema formally requires:

- **Snail** — a coiled, compact spiral shell silhouette, low and rounded, sitting close to the substrate/moss height. A coil is a geometrically "patient" shape — it visually matches `movement_speed=6` and the longest pause range in the roster (3.0–6.0s).
- **Moth** — an angular, wide silhouette held above the ground plane, breaking the jar's otherwise low, horizontal plant-scape with a raised triangular/fan shape. This matches `movement_speed=14` (2.3× Snail) and the shortest pauses (1.5–3.0s).

This gives Snail and Moth three redundant differentiators, not one: silhouette *family* (coil vs. angular fan), *ground relationship* (hugging vs. lifted), and *geometric character* (rounded-organic vs. angular). Redundancy matters because both creatures matter equally for "noticing what changed" (Discovery Surfacing's Arrival/Departure cues), and a glance or partial occlusion by a leaf shouldn't cost legibility. It also deliberately avoids reusing any of the three plant silhouette families (a coil isn't a carpet, clump, or climb shape) — so a creature never gets mistaken for "just another plant" at a glance, distinct from *and* readable against the static plant life around it.

**No separate "departed" shape.** Creature Behavior's DEPARTING state is a fade-and-motion exit ("moves toward a jar edge and fades out"), never a shape change — Snail and Moth each get exactly one silhouette, always their full-vitality shape, whether wandering, pausing, or mid-exit. This mirrors the plant rule above: nothing in this jar gets a "sad" or "leaving" shape.
**Serves**: Pillar 3, Care Not Control — Creature Behavior's own Player Fantasy names the goal directly ("recognizing individual inhabitants... as consistent little characters"); a legible, distinct-from-day-one silhouette is what makes that recognition possible without turning this into character design. Also Pillar 2 — a creature is simply present or not, never in a broken/leaving state visually.

### The Rock: Sole Inert, Player-Shaped Object

The Rock is the one hard-edged, non-growing, non-wandering thing in the jar, and its silhouette leans into that rather than blending in: **angular, faceted, asymmetric — hard geometry**, with none of the growth softness the plants carry (no swelling curve like clump, no unfurl like carpet, no vertical reach like climb) and none of the organic roundness the creatures carry. It's the only shape in the scene that never has a life stage.

That contrast does double duty. Diorama Rendering already locks a *material* contrast for the Rock ("a deliberate material contrast against the glass and wet substrate... reinforcing visual hierarchy through material language rather than outline alone") — this adds the outline half that document explicitly left open. A genuinely different shape-family for the one draggable object is a legible, diegetic invitation to touch it, with no UI affordance icon needed, consistent with this game's near-total absence of non-diegetic UI chrome.
**Design test**: silhouetted in black next to a plant at any growth stage, the Rock should be unmistakably the "different kind of thing" — never mistakable for a dormant or decayed plant stage.
**Serves**: Pillar 1, A World in Your Hands — the Rock is the one element the player's own hand actually composes; everything else in the jar drifts on its own (grows, decays, wanders, tints with time of day) while the Rock's shape is the one fixed point the player placed. Its stillness becomes a quiet anchor across sessions, not a spectacle.

### Environment Geometry: Glass, Substrate, Vignette

- **Glass** — already locked as a hand-authored semi-transparent overlay with baked specular bands and painted (not shader) refraction. Shape-wise, the jar's own outline stays a simple, true, regular curve — deliberately the one *geometrically perfect* form in the frame. Its regularity is a contrast device: a real, man-made curve holding a scene full of irregular, asymmetric, organic growth. That contrast is what sells "a real container holding a small wild world" rather than a diorama box that happens to be round.
- **Substrate** — deliberately the *least* shaped element: irregular granular texture with no strong directional form of its own. It's a visual noise floor, not a silhouette competing with anything above it.
- **Vignette** — a soft radial alpha gradient, no hard edge, no shape of its own beyond an implied soft ellipse. Its only job is invisible: pull the eye toward center without ever being consciously seen as "a shape." If a player can point at the vignette, it has failed the same test Section 1 already applies to every other element.

**Design test**: each environment element's geometric character should be a direct expression of what it physically is — glass is regular because real glass is manufactured and round; substrate is unshaped because loose granular material has no silhouette of its own; the vignette is invisible because it isn't a diegetic object at all.
**Serves**: Section 1, Principle 1 (material truth) — this is that principle applied to geometry rather than surface texture. A geometrically "wrong" jar (faceted, hand-wobbly) would read as stylized in exactly the way the one-line rule forbids.

### Hero Shapes vs. Supporting Shapes

Diorama Rendering's own Budget Allocation already names the glass overlay "the highest-value asset in the whole scene" — so the **jar is the one permanent hero shape**. Its regular curve frames every other silhouette in every single screenshot; the eye registers "jar" before "contents," without needing motion or contrast to earn that status. This matches Pillar 1 directly: the container is the hero, not any single inhabitant, because the premise is "a world small enough to hold," not "a mascot creature."

Below that, hero status is **contextual and temporary**, not fixed: whatever is currently moving (a creature, always live per Diorama Rendering Core Rule 5) or whatever Discovery Surfacing's active cue is targeting momentarily claims the eye. There is no second *permanent* hero silhouette — never a standing "the flower is the star" default framing — because a fixed secondary hero would compete with the jar and contradict Pillar 4's actual ask: reward comes from noticing what's different *now*, not from one object being permanently more important-looking than the rest. In State 2 (Section 2's "routine return, nothing changed"), there should be no artificial hero shape at all — consistent with that state's calm, undemanding register.

Receding shapes: substrate (unshaped by design, above), rear-of-jar dressing (Diorama Rendering's authored depth-of-field already softens these edges — a shape-language decision as much as a lighting one: background silhouettes are intentionally soft-edged so they read as "there but not now"), and the Rock when it isn't being actively repositioned (present, anchoring, never competing — its invitation is shape/material contrast, never a glow or outline emphasis).

**Design test**: in a single static frame with zero motion, exactly one shape should dominate (the jar). If a second shape competes for that role by default rather than because it's currently changing, the hierarchy has drifted.
**Serves**: Pillar 4 — hierarchy that rotates with what's actually alive in the moment is the shape-language expression of "every detail rewards attention," rather than "one big spectacle."

---

## 4. Color System

Almost every number in this section already exists somewhere in a GDD. This section compiles them into one coherent read and flags one color decision that was implied but never written down (4.4). It does **not** invent new numeric swatches for qualitatively-locked materials (moss/substrate/glass/terracotta/wing/stone) — those stay direction-only here; pinning exact hex values is Section 8 (Asset Standards) territory, already deferred pending Gate C4.

### 4.1 Primary Palette

The concept doc's Visual Identity Anchor already commits the philosophy directly: *"A grounded, naturalistic palette (greens, browns, glass-blue) that shifts subtly with season and light rather than saturated 'gamey' colors — believability over vibrancy."* This palette is that philosophy translated into 7 material roles. Each is a *baked* color (painted into the sprite, per Section 1's baked-not-real-time-lighting principle) — the day/night gradient in 4.2 multiplies over these, it never replaces them.

| Role | What it means in this world | Where it lives | Numeric lock |
|---|---|---|---|
| **Foliage Green** | Living, growing tissue — the baseline "this is alive" material | Moss, Fern, Flower base color; moss slightly more saturated with baked crevice AO to read alive/damp | Direction locked, swatch deferred (Section 8) |
| **Substrate Brown** | The given ground — neutral, unshaped, the surface everything else grows from or rests on (Section 3's "visual noise floor") | Substrate/dirt base, matte, high micro-detail granule texture | Direction locked, swatch deferred |
| **Glass Blue-Grey** | The container, the boundary, the one geometrically regular thing in the frame (Section 3) — always faintly cool/transparent even at full sun | Jar overlay, baked specular bands, painted refraction | Direction locked, swatch deferred |
| **Terracotta Warm** | Creature-warmth, specifically Snail — a deliberate warm accent against the jar's dominant green/brown | Snail shell | Direction locked ("warmer terracotta... against green moss"), swatch deferred |
| **Bone Pale** | Creature-lightness, specifically Moth — a deliberate pale accent against dark shadow, the jar's other creature-warmth axis | Moth wings | Direction locked ("paler wing value... against dark leaf-shadow"), swatch deferred |
| **Wet-Cool Response** | What real moisture does to material — darkens, cools slightly, gains sheen | Watering Substrate Sheen tween target | **Numerically locked**: `(0.74, 0.78, 0.83, 1.0)` |
| **Etiolation Pale-Yellow-Green** | What real light-starvation does to material — the STALLED cue | Plant `self_modulate` when `stalled=true` | **Numerically locked**: `(0.88, 0.90, 0.62, 1.0)` |

One deliberate omission: **day/night warm amber and deep-night blue are not in this table.** They're light temperature, not material color — conflating them here would blur exactly the distinction Section 1's material-truth principle depends on (paint vs. what light does to paint). They belong in 4.2/4.3.

**Design test**: could you point at any color in this palette and explain what real physical thing produces it (chlorophyll, wet clay, glass, etiolation, moisture) without reaching for a game-UI justification ("it's the warning color")? If not, it doesn't belong.

### 4.2 Semantic Color Usage

**Warm means time-of-day. Cool means time-of-day. Neither means anything else — by design, because nothing else exists for them to mean.** This game has no health, no danger, no rarity tiers, no reward color-coding. `DAY_NIGHT_GRADIENT`'s warm amber (dawn/dusk peak) and cool blue (deep night) carry exactly one piece of information: proximity to solar peak. Core Rule 8 locks this tint as "cosmetic-only, never gated" — which creates a real obligation for every *other* color decision in the game: nothing else may borrow "warm=good, cool=bad" as local color logic, because doing so would retroactively make the ambient tint start reading as a status signal it structurally isn't.

This matters concretely for **Departure's cooling desaturation**. A player pattern-matching from other games' conventions (cool = negative, warning, loss) could misread Departure's cool-shift as "something bad happened." Discovery Surfacing's own Core Rule 7 already guards against this at the *behavioral* level (departure is "surfaced, never silent," reads as "moved on," not a penalty) — but the color choice needs to hold up that same intent. **Design test**: if you swapped Departure's cool desaturation for Growth's warm bloom and vice versa, would either cue read as more "positive" or "negative" than the other? It shouldn't — both should read as equally neutral, equally part of the jar's ordinary life. If cool reads as bad, the cue has drifted from "diegetic light behavior" toward "UI status color," which is the exact failure both locked GDDs already forbid.

**How the four discovery categories get color-differentiated without becoming a color-coded system.** `discovery-surfacing.md`'s Visual/Audio Requirements is explicit: *"The distinguishing axis between categories is where light/material behavior lives, not hue-coding."* Reading each category's locked physical logic:

| Category | Locked behavior | Implied temperature | Why (diegetic logic) |
|---|---|---|---|
| Growth | subsurface warm light bloom from within plant tissue | warm gold | Transmitted light through living tissue reads warm — the same reason a leaf held up to the sun glows gold, not blue |
| Arrival | specular catch-light off the creature's silhouette edge | near-neutral / reflects current ambient | A specular highlight reflects whatever light is already in the scene — it doesn't emit its own hue. This is *why* it can carry genuine motion (the one category that does) without needing a color identity at all |
| Departure | cooling desaturation/settle at last-known position | cool blue-grey | The physical read of "recently disturbed, now settling" — temperature dropping slightly as motion stops, not a penalty tint |
| Detail Event | brightest-but-briefest point-light flare | warm-white, high luminance | Distinguished from Growth by intensity + brevity, not by a different hue family — both lean warm |

The load-bearing point: **temperature here is a secondary, physically-motivated characteristic riding on top of the primary distinguishing axes** (target type — plant tissue point vs. creature position; motion — Arrival only; duration/intensity — Detail Event's brevity). It is never the only signal. Two useful internal contrasts:

- **Growth vs. Detail Event** are differentiated entirely by *timing* (duration/intensity) despite sharing both target-type (plant) and hue family (warm) — this pair is colorblind-safe by construction, since timing isn't a color-vision-dependent channel.
- **Growth vs. Departure** are differentiated by *target type* (plant tissue vs. creature position) **and** temperature — this is the pair `accessibility-requirements.md` already flags as the real risk ("the closest pair... rely on temperature contrast, which several colorblind types compress"). See 4.5 for what backup already exists here.

### 4.3 Per-State Color Temperature Rules

Section 2 already locks the rule this section just has to apply: **state supplies emotional register, day/night phase supplies temperature only, and neither is allowed to reach into the other's job.** Concretely, per state:

| State | Color temperature behavior |
|---|---|
| 1 — First-Ever Session | `day_night_phase=0.0` by construction lands exactly on `t=1.0` — neutral `(1,1,1)`, zero tint. The game's first frame is the *only* guaranteed-neutral frame in the whole game; every other state's temperature is whatever the real-time cycle happens to be. |
| 2 — Routine Return | Whatever `t` the visit lands on, entirely uncontrolled — no cue color layered in at all (IDLE state generates zero discovery items). The state's "quiet familiarity" mood comes from the *absence* of any added color event, not a color treatment of its own. |
| 3 — Discovery Reveal | Baseline tint completely unchanged underneath; mood shift comes entirely from small per-element pinpoints (4.2's table) — never a global wash. A Reveal at deep-night tint is still a Reveal, just cooler-lit; the state's identity and the tint's identity never blend into a third thing. |
| 4 — Settled Presence | Baseline tint, but here it's the one state actually *likely to be seen moving* in real time (Section 2 already notes a 5-minute session shows roughly a quarter-cycle). Plus: this is the one state where **two temperature signals can fire simultaneously and are both correct** — Watering Substrate Sheen's substrate darkens/cools (`WATERING_SHEEN_TINT`) while the sun `Light2D` simultaneously brightens/warms (`WATERING_SUN_ENERGY_BOOST`), same 3-second envelope. This isn't a contradiction to resolve — it's physically accurate (wet material genuinely darkens in its own shadow while catching a brighter specular highlight) and worth naming explicitly so it isn't mistaken for an authoring inconsistency later. |

### 4.4 UI Palette

There is, correctly, almost nothing to palette here. `discovery-surfacing.md` and `diorama-rendering.md` both lock "UI Requirements: None." The one surface is `ambient-audio.md`'s mute/volume control, whose *box* is already locked (fixed corner, ≤4% viewport, persistent visibility, ≥44×44px hit area, z-order above all diegetic content) but whose visual treatment is explicitly left to `ux-designer`/`art-director`.

**Recommended color treatment**: pull from the same worked-material language as the jar's surroundings — a small object read as dull metal, aged brass, matte ceramic, or turned wood, using **value contrast for legibility, not hue saturation** — matching the Rock's own precedent (Section 3: material contrast, not outline emphasis, carries an object's "separate from the world" read). This keeps the one necessary UI exception speaking the same visual language as everything else, per Section 1's one-line rule.

**Tint exemption, decided this session**: the control is exempt from the day/night `CanvasModulate` tint — rendered in a layer the multiply doesn't reach, always at its true authored color regardless of time of day. It's a functional, always-reachable control; a deep-night cool tint pushing its already-small icon toward the gradient's dim night-stop channel floor would risk legibility exactly when a player wants to reach for mute. `ambient-audio.md`'s own "diegetic-*adjacent*" wording (not fully diegetic) is read as the license for this one exception. **Companion note needed**: `ambient-audio.md` or `diorama-rendering.md` should get a one-line addition recording this exemption once the control is actually built.

### 4.5 Colorblind Safety

Structured against `accessibility-requirements.md`'s already-committed Standard tier and its own Color-as-Only-Indicator Audit table, not re-derived from scratch.

| Signal | Risk level | Non-color backup that exists | Gap |
|---|---|---|---|
| STALLED tint | **High — real, unresolved** | None. `growth_stage`'s sprite index is frozen (that's the whole point) — nothing else changes | Flagged, not closed — see below |
| Growth vs. Departure cue temperature | Medium — flagged in accessibility doc as the closest pair | **Target-type context**: Growth always targets a specific plant instance's changed tissue; Departure always targets a creature's last-known jar-floor position. A player who can't distinguish warm from cool can still distinguish "this light is inside a plant" from "this light is at open substrate where nothing grows." Partial answer, not full | Colorblind-simulation pass still open (accessibility doc's own Test Plan already schedules this) |
| Growth vs. Detail Event | Low | Differentiated by duration/intensity — a temporal axis, colorblind-safe by construction | None |
| Day/night warm/cool shift | Exempt by design | Core Rule 8: cosmetic-only, never gated — no gameplay information here to fail to perceive | `DAY_NIGHT_GRADIENT`'s dim night-stop channel floor already guards general (not colorblind-specific) legibility |
| Watering Sheen | Low | Self-triggered by the player's own tap — timing alone confirms the action registered; the sun-light energy boost is a secondary non-color signal | None flagged |
| STALLED tint vs. dawn/dusk amber stop | General legibility risk (not colorblind-specific) | — | Already flagged in `diorama-rendering.md`'s own Formulas section as needing confirmation; compounds the same gap below |

**On the STALLED gap specifically — why it isn't closed the way Section 3 closed its gap.** Section 3's fix for Snail/Moth was a shape difference. That move is structurally unavailable here: Section 3 also locked that no plant growth-stage silhouette may ever be authored to look "broken" or "sickly," specifically because STALLED and DECAYING both freeze the same silhouette sequence, and any given stage gets revisited on the way down from healthy *and* on the way back up. A shape-based STALLED signal would need that same stage to simultaneously read "fine, just decaying toward this point" and "STALLED-flagged, frozen here" — which isn't one asset anymore, it's two, and Content Data doesn't scope for that.

**Decided this session: flag and defer, per user decision.** `STALLED_TINT=(0.88,0.90,0.62,1.0)` is described as "pale" but that's a hue+desaturation description, not a confirmed brightness delta. Recommended path: fold an explicit grayscale-simulation check into the same technical-artist pass `diorama-rendering.md`'s Formulas section already requires before that system's implementation story is marked Done (alongside the existing dawn/amber-confusion check), rather than opening a second separate task. Whether that grayscale check proves sufficient, or STALLED ultimately needs an actual second signal, is a call for a future session with real assets to test against — tracked in `accessibility-requirements.md`'s own Open Questions, not closed here.

---

## 5. Character Design Direction

*[Deferred — this project has no traditional "characters"; this section
will cover plant/creature/object design direction when authored. Not
required for the Technical Setup → Pre-Production gate.]*

---

## 6. Environment Design Language

*[Deferred pending Gate C4 (Diorama Rendering frame-budget verification).
Not required for the Technical Setup → Pre-Production gate.]*

---

## 7. UI/HUD Visual Direction

*[Deferred — Ambient Audio's mute/volume control is this project's only
UI surface (design/gdd/ambient-audio.md UI Requirements); everything else
is diegetic by design. Not required for the Technical Setup →
Pre-Production gate.]*

---

## 8. Asset Standards

*[Deferred pending Gate C4. Not required for the Technical Setup →
Pre-Production gate.]*

---

## 9. Reference Direction

*[To be authored — game-concept.md already names Tiny Glade, Viridi, and
Stardew Valley as comparables, plus macro nature photography, real
terrarium/bonsai care, ASMR nature videos, and quiet nature documentaries
as non-game inspirations. This section will sharpen those into
take-from/avoid guidance per source.]*
