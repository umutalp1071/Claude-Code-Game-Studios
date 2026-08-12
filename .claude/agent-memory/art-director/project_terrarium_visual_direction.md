---
name: project-terrarium-visual-direction
description: Terrarium's Visual Identity Anchor and where its visual decisions already live across GDDs, as of the Systems Design -> Technical Setup gate (2026-08-06)
metadata:
  type: project
---

Terrarium (cozy ecosystem-tending sim, Godot 4.7.1, Web/Compatibility renderer)
has its Visual Identity Anchor locked in `design/gdd/game-concept.md`
("Diorama Realism" — macro-lens nature-photograph framing, baked-light
material truth, scale intimacy, light-as-mood, naturalistic palette,
simplified fidelity for MVP with full macro-photoreal polish deferred
post-MVP).

**Why this matters:** by the time Systems Design finished (2026-08-05), an
unusual amount of what would normally be first-drafted in the art bible was
already decided and locked inside individual GDDs' Visual/Audio Requirements
sections, each explicitly tagged "no art bible exists yet — flagged as
candidate first entries for it":
- `design/gdd/diorama-rendering.md` — the biggest source. Baked-light
  upper-left key convention, 1-3 ambient Light2D + up to 5 cue-driven
  Light2D (8 concurrent worst case, budget not yet profiled), day/night
  CanvasModulate gradient with exact color stops, STALLED-cue etiolation
  tint (0.88,0.90,0.62), DOF via asset authoring (soft edges/reduced
  contrast on background layer) not runtime blur, vignette as composition
  device only, glass jar as the single highest-value hand-authored asset,
  per-creature/object silhouette-contrast direction (terracotta snail vs.
  moss, pale moth wing vs. dark shadow), growth_pattern silhouette rules
  (carpet/clump/climb).
- `design/gdd/discovery-surfacing.md` — 4 diegetic per-category cue
  treatments (Growth subsurface glow, Arrival specular catch-light,
  Departure desaturation/settle, Detail Event point-light bloom), all
  Light2D-based, "would it still make physical sense without the glow?"
  as the standing corrective test for any future cue art.
- `design/gdd/ambient-audio.md` — the one locked exception to an otherwise
  strict "zero UI chrome" rule: a mute/volume corner control, box locked
  (fixed corner, <=4% viewport, always visible, >=44x44px hit area,
  diegetic-adjacent styling directive) but exact icon/pattern deliberately
  left to art-director/ux-designer.

**Known open items intentionally deferred to Technical Setup** (correctly
scoped there, not Systems Design gaps): BLOCKING Open Question in
diorama-rendering.md — Godot 4.7.1 Compatibility/WebGL2 Light2D/normal-map/
glow behavior is unverified and gates the entire lighting approach, needs a
throwaway render-test spike early, before the art bible commits fully to the
Light2D-heavy strategy; Departure cue VFX has no real-world reference and
needs a technical-artist prototype; held-object visual feedback (lift/scale/
highlight while dragging) and the mute icon's exact styling are both
low-priority art-director calls still open.

**How to apply:** when authoring `design/art/art-bible.md`, treat
diorama-rendering.md's Visual/Audio Requirements and discovery-surfacing.md's
as primary source material to consolidate, not fresh decisions — the risk is
re-deciding something already locked and creating a contradiction, not a lack
of raw material. Sequence the Light2D/Compatibility-renderer verification
spike before finalizing the Lighting & VFX section, since a failed spike
would force a rework of both diorama-rendering.md and the art bible section
at once.
