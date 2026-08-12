# Web Export Spike

## Hypothesis being tested

Three BLOCKING Open Questions across `input-abstraction.md`, `persistence-save.md`,
and `diorama-rendering.md` cannot be resolved from documentation alone (this
project's own `docs/engine-reference/godot/` snapshot covers none of them). This
spike answers all three with one throwaway Godot 4.7.1 Web export, tested in real
browsers. Full plan, falsifiable questions, and pass/fail criteria:
`docs/technical-setup/web-export-verification-plan.md`.

- **Gate A** (`InputProbe.tscn`) — does touch synthesize duplicate mouse events, and
  does pointer-interruption detection (`focus_exited`, touch cancellation) actually
  work on Web export?
- **Gate B** (`PersistProbe.tscn`) — can a save durably commit when a tab is hidden
  or killed?
- **Gate C** (`RenderProbe.tscn`) — do `Light2D` + normal maps + glow +
  `CanvasModulate` behave as designed under the Compatibility/WebGL2 renderer?

**Run Gate C first** — it has the widest blast radius (gates the entire Diorama
Realism visual identity), per the plan's own recommendation.

## How to run

1. Open this directory (`prototypes/web-export-spike/`) as a project in the Godot
   4.7.1 editor.
2. **Every `.tscn` file here was hand-authored as plain text, not created via the
   editor** — each is intentionally minimal (one root node + one script; the script
   builds its own UI/scene content at runtime in `_ready()`) specifically to avoid
   the risk of a malformed hand-typed node hierarchy. Open each scene once in the
   editor before running, to let Godot validate/re-save it. If anything looks wrong
   in the Scene panel, it's a hand-authoring slip, not a design decision — fix it in
   the inspector.
3. Confirm `Project Settings → Rendering → Renderer → Rendering Method` reads
   `Compatibility` (already set in `project.godot`, but the plan says verify three
   ways — see plan §0.2).
4. **No `export_presets.cfg` is included.** Export presets are a GUI-configured
   resource with many fields I can't hand-author with confidence — add the Web
   preset yourself via `Project → Export...`, following plan §0.4 exactly (Runnable,
   Thread Support OFF, Extensions Support OFF, Progressive Web App OFF, Focus Canvas
   on Start ON).
5. Export to `build/index.html` (gitignored — never commit the build).
6. Serve it — `file://` does not work. Easiest: editor's Remote Debug → Run in
   Browser. Manual: `python -m http.server 8000` from `build/`. See plan §0.5 for
   the real-phone path.
7. Run the device matrix (plan §0.6) and fill in every `RESULT` table in
   `docs/technical-setup/web-export-verification-plan.md` directly — this repo does
   not duplicate those tables.

## What's placeholder, not real

- **Gate C's jar art is procedurally generated at runtime** (`_make_diffuse()` /
  `_make_normal()` in `render_probe.gd`) — a flat color diffuse and a simple
  dome-shaped bump normal map, not the real jar asset. This is enough to answer
  C2/C3/C4, but **C1's result is PROVISIONAL** per the plan's own §3.1 allowance —
  it must be re-run against the real jar diffuse+normal from
  art-director/technical-artist before that Open Question actually closes.
- No `art/` directory exists for the same reason — nothing to put in it yet.

## Deviations from the plan's exact file layout

- `hide_bridge.gd` is a new shared autoload, not called out by name in the plan's
  §0.1 file tree. The plan's Gate B code example (§2.2) inlines the JS
  `visibilitychange`/`pagehide` listener directly in `persist_probe.gd`, but also
  explicitly says Gate A should "reuse Gate B's JS-side listener here (same build,
  same scene tree)" — so the listener-install logic was factored into one autoload
  both `input_probe.gd` and `persist_probe.gd` connect to (`HideBridge.hide_detected`),
  rather than duplicated or awkwardly cross-referenced between two scene scripts.
  Functionally identical to the plan; structurally cleaner.

## Status

**In progress — desktop Chrome tested, all other browsers/devices untested.**
`ProbeLog`'s on-screen panel had a positioning bug (fixed 2026-08-10 — see git
history on `probe_log.gd`) that made the log invisible on every screen; results
below were captured after that fix, on desktop Chrome only. Every other
browser/device row in `docs/technical-setup/web-export-verification-plan.md`'s
`RESULT` tables is still `UNTESTED`. Do not infer results for untested
browsers/devices from the Chrome data — Gate B's own device matrix explicitly
flags Safari/iOS Safari as the highest-risk engines for exactly the persistence
questions Chrome already passed.

## Findings

*(desktop Chrome only — full detail and evidence lines live in the verification
plan's RESULT tables, §1.6 / §2.6 / §3.6)*

- **Gate A (Chrome desktop)**: A2 **PASS** — focus-out/hide callback delivered
  same-frame (frame=2021, lag=0.6ms), not deferred to return. A5 is a positive but
  informal observation (marker stable across 3 captures) — not a scored
  50/100/200% zoom test, since exact zoom per capture wasn't logged. **A1, A3, A4
  are UNTESTED** — all three require an actual touch/mobile device, which wasn't
  available. A1 in particular is the core hypothesis behind Core Rule 7's dedup
  logic and remains completely open.
- **Gate B (Chrome desktop)**: B1 **PASS** — callback lag 0.5ms, frame unchanged
  (frame=10093 throughout). B2 with-syncfs **5/5**; B2 no-syncfs **2/3** (only 3 of
  the planned 5 trials run, 1 failure) — directionally confirms `FS.syncfs()` is
  required, but the run is incomplete. B3 persisted/advanced across hard-kill
  trials (qualitative). B4 (iOS Safari `pagehide` vs `visibilitychange` + bfcache)
  is **UNTESTED**.
- **Gate C (Chrome desktop)**: C1 **PASS, provisional** (placeholder art — must
  re-run on the real jar asset). C2: glow **exists** under Compatibility/WebGL2
  (bright cue light produces a clearly visible bloom), but toggling `hdr_2d`
  ON/OFF produced **no visible difference** between the two builds — not a full
  HDR-bloom PASS, and matches the plan's own §3.5 "clamped" pattern on this one
  browser (directional, not confirmed — no energy sweep was run, and it's
  untested elsewhere). C3 **PASS** — blue tint composites over the lit result. C4:
  no stuttering/degradation observed ramping 1→5 cue lights, but no numeric
  ms/draw-call values were captured, and no mobile reference device was used —
  C4's actual purpose (mobile GPU worst-case budget) is still open.

### Open risks

1. **Gate A's central question (A1) is untested.** No touch data exists at all.
2. **Gate B's highest-risk browsers (Safari desktop, iOS Safari) are untested**,
   despite the plan calling them out by name as the likely failure points for
   persistence.
3. **Gate B's B2 no-syncfs run is incomplete** (3/5 trials).
4. **Gate C has no mobile data**, so C4's actual budget question (the reason the
   gate exists) is unanswered, and C1 is still provisional on placeholder art.
5. **Gate C's C2 on/off comparison is now done on Chrome and shows no difference**
   — glow exists but isn't HDR-dependent there. This points toward the
   painted-halo-fallback design consequence in §3.5(ii), but it's one browser and
   needs either a second browser to corroborate or an explicit design call from
   `creative-director`/`art-director` before `diorama-rendering.md` changes.

## When this concludes

Follow plan §4: fill in every RESULT table, write findings here, replace (don't
append to) the 3 GDD Open Questions with resolutions, route any design consequence
(e.g. C2 glow unavailable, A1 refuted) to creative-director/art-director, then
delete or archive this directory. It never becomes production code — see
`.claude/rules/prototype-code.md`.
