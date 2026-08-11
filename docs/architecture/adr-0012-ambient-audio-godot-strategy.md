# ADR-0012: Ambient Audio — Godot Implementation Strategy

## Status
Accepted (2026-08-11 — gate-check re-run, Technical Setup → Pre-Production)

## Date
2026-08-11

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Audio |
| **Knowledge Risk** | MEDIUM — the core `AudioStreamPlayer`/`AudioServer` API is stable across 4.4–4.7 (no breaking changes found), but Web-export-specific `AudioContext` gesture-unlock behavior required source-level verification rather than documented API, and one specific interaction (pre-gesture `play()` behavior once the context resumes) remains empirically unverified. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `modules/audio.md` (flagged stale — stamped Godot 4.6, same known-stale issue as `input`/`ui`/`physics`/`rendering` modules per the last `/architecture-review` pass; not misleading here, since nothing in this ADR relies on it beyond the already-cross-referenced `breaking-changes.md` entries), `godot-specialist` consultation against Godot engine source (`platform/web/display_server_web.cpp`, `audio_driver_web.cpp`, `library_godot_audio.js`) for Web `AudioContext` unlock behavior specifically, since no official doc or local reference covers it. |
| **Post-Cutoff APIs Used** | None directly — `AudioStreamPlayer`, `AudioServer.set_bus_mute()`/`set_bus_volume_db()`, signals, `_process()` are all pre-cutoff stable. The 4.7 `AudioEffectSpectrumAnalyzer.tap_back_pos` removal and `AudioStreamPlayer.area_mask` default change (breaking-changes.md) do not apply — this system uses neither feature. |
| **Verification Required** | Whether a `play()` call issued before the browser `AudioContext` unlocks produces audio once the context auto-resumes on the player's first input, or whether it must be explicitly re-issued — unverified from any documentation source (see Decision, Risks). Recommend a new verification gate (Gate D, alongside this project's existing Gate A/B/C) before this is considered field-verified, not blocking implementation. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0004 (Ecosystem Simulation — `watering_applied` signal, companion edit below), ADR-0006 (Time & Drift — `get_state()` polling), ADR-0010 (Discovery Surfacing — `get_active_items()`), ADR-0005 (Persistence/Save — `refresh_mirror()` companion edit and blob field gap below), ADR-0002 (autoload/direct-call/signal convention) |
| **Enables** | None — Ambient Audio is a leaf system (`architecture.md` API Boundaries: "No public API... nothing calls into it"); no other ADR depends on anything this one produces. |
| **Blocks** | Ambient Audio implementation stories (already stated as blocked by `design/gdd/ambient-audio.md` itself) |
| **Ordering Note** | Should be Accepted after ADR-0002, ADR-0004, ADR-0005, ADR-0006, ADR-0010, since its Key Interfaces call directly into all of them or consume their signals. |

## Context

### Problem Statement

`design/gdd/ambient-audio.md` is fully formula-specified (dB math, fade
curves, reactive-layer boosts, a complete state machine) but leaves the
Godot implementation undecided, and surfaces three real architectural gaps
along the way that no prior ADR closes:

1. **No system currently notifies "watering just happened."**
   `EcosystemSimulation.apply_watering()` is a direct command call
   (ADR-0004) with no signal — both this system's Reactive Layer (Core
   Rule 3) and Diorama Rendering's already-written Watering Substrate
   Sheen (ADR-0009 Decision, never actually specified its trigger either)
   need exactly this notification and have no way to get it today.
2. **Persistence/Save's mirror-refresh (ADR-0005) only fires on
   `tap`/`drag_end`.** Ambient Audio's mute/volume UI control is a
   `Control` that claims its own input before Input Abstraction's
   `_unhandled_input()` ever sees it (ADR-0008 Decision #1) — a volume
   change today would never reach the save mirror. ADR-0005's own Risks
   section explicitly named this exact class of gap in advance.
3. **`persistence-save.md`'s own blob field list (Core Rule 1) never
   lists `ambient_volume`/`muted`**, despite this GDD's Dependencies
   section already documenting Persistence/Save as reading/writing them
   (companion note, 2026-08-05). This is the same "blob-completeness"
   omission class that GDD's own history already caught twice for other
   fields (`light_level`/`light_direction`, `last_known_position`) — see
   GDD Sync note below.

Separately, `time-drift.md`'s `get_state()` and `discovery-surfacing.md`'s
`get_active_items()` are both poll-only (no signal), and the browser
`AudioContext` gesture-unlock behavior (GDD Core Rule 1a) has no
documented Godot API — verified against engine source instead (see Engine
Compatibility).

### Constraints
- No central event-bus/mediator autoload (registry `forbidden_patterns:
  event_bus_mediator`).
- `architecture.md` API Boundaries: Ambient Audio has **no public API** —
  it is a pure leaf consumer, nothing calls into it. This rules out a
  `restore(restored_blob)` companion method (the pattern every other
  system uses) — Ambient Audio must instead pull its own persisted state
  the same way it pulls everything else: by polling from its own
  `_process()`, not by being called into.
- `coding-standards.md`: dependency injection over singletons; static
  typing; gameplay values data-driven, never hardcoded.
- GDD Core Rule 6: must never gate or block gameplay input regardless of
  audio/`AudioServer` state.
- Web export only, Compatibility renderer — no engine feature used here
  is renderer-dependent, but the Web export runtime specifically governs
  the `AudioContext` unlock behavior (see Decision §3).

### Requirements
- One continuous ambient loop starts at session-ACTIVE with zero added
  delay (Core Rule 1), holding silently if the browser audio context
  isn't yet unlocked (Core Rule 1a), fading in on the first player input
  of any kind.
- Two optional reactive layers (watering swell, discovery bed-shift),
  both pure deltas summed and double-capped per the GDD's Reactive Layer
  Boosts formula — this ADR does not redefine that math, only decides how
  it's driven.
- A persisted `ambient_volume`/`muted` setting, read at session start and
  written whenever the (future `/ux-design`-owned) mute/volume control
  changes it.
- Hard stop, no fade-out, at session end (Core Rule 1/Edge Cases).

## Decision

**Ambient Audio is a single autoload, `AmbientAudio`** — a plain script
(no companion `.tscn`), matching every other autoload in this project.
Unlike the logic-only autoloads (`ObjectPlacement`, `EcosystemSimulation`),
it owns exactly one real scene-tree node: a single `AudioStreamPlayer`,
created programmatically in `_ready()`:

```gdscript
func _ready() -> void:
    _player = AudioStreamPlayer.new()
    _player.bus = &"Ambient"
    _player.stream = preload("res://assets/audio/ambient_loop.ogg")
    add_child(_player)
    _bus_idx = AudioServer.get_bus_index(&"Ambient")   # cached once, not
                                                         # re-looked-up per frame
                                                         # (godot-specialist note)
```

matching the engine reference's own idiom for a single/pooled player
(`docs/engine-reference/godot/modules/audio.md`'s "Object Pooling for
SFX" pattern, applied here to exactly one instance) rather than
introducing a new companion-scene autoload shape this project hasn't used
elsewhere. A new **`Ambient` bus**, child of `Master`, must exist in the
project's Audio Bus Layout resource — a one-time editor-side setup, not
GDScript-authored.

### 1. Session state detection — poll `TimeDrift.get_state()`

`get_state()` has no signal (registry `time_drift_session_state`).
`AmbientAudio._process(delta)` reads it every frame and edge-detects the
transition against a cached previous-frame value:
- `INACTIVE → ACTIVE`: call `_player.play()` unconditionally (Core Rule
  1's zero-delay guarantee), then branch on whether the browser audio
  context is already unlocked (§3).
- `ACTIVE → INACTIVE` (from `LOOPING` or `MUTED`): `_player.stop()`
  immediately, no fade-out (Edge Cases), reset all envelope state.

Matches Diorama Rendering's own established poll-based leaf-consumer
pattern (ADR-0009) — no new pattern introduced.

### 2. Discovery cues — poll `DiscoverySurfacing.get_active_items()`

Read once per `_process()` frame while `LOOPING`/`MUTED`. `N_active =
items.size()`, `W = max(CATEGORY_WEIGHT[item.category] for item in
items)` — both computed fresh every frame per the GDD's own "re-evaluated
live, no per-cue envelope instance" rule (Edge Cases). Registers
`ambient-audio.md` as a second consumer of the already-registered
`discovery_active_items_query` interface (ADR-0010) — no change needed
there, `DiscoveryItem.category` already carries exactly what
`CATEGORY_WEIGHT` needs.

### 3. Gesture-unlock detection — a dedicated raw `_input()` hook

**Engine specialist finding (source-verified against
`platform/web/display_server_web.cpp`)**: Godot's own Web runtime already
calls `resume_audio()` internally from its own input callbacks (key,
mouse, touch) — the browser `AudioContext` unlocks automatically on any
input Godot receives, with **no queryable `AudioServer` signal or
property** to detect it. This means:
- `AmbientAudio` cannot ask "is the context unlocked now" — it can only
  react to *any* input event firing, the same trigger Godot's own runtime
  already uses internally.
- Input Abstraction's `tap`/`drag_start` signals (ADR-0008) are
  insufficient here — they only cover mouse/touch, and only after
  `_unhandled_input()` (i.e., only events no UI `Control` claimed first).
  Gesture-unlock genuinely needs **any** input of **any** kind, UI-claimed
  or not — a keypress, a UI button tap, anything.

`AmbientAudio` implements its own minimal `_input(event: InputEvent) ->
void`, active only while `state == PENDING_GESTURE`, disabled (via
`set_process_input(false)`) immediately after firing once, and
re-enabled at the next `INACTIVE → ACTIVE` transition:

```gdscript
func _input(event: InputEvent) -> void:
    if _state != State.PENDING_GESTURE:
        return
    set_process_input(false)
    _player.stop()
    _player.play()   # defensive re-trigger — see Risks
    _state = State.LOOPING
    _fade_in_elapsed = 0.0
```

**Defensive re-trigger, not a bare state flip**: whether a `play()`
issued *before* the context unlocked actually produces audio once Godot's
internal `resume_audio()` fires on this same input event is unverified
from any documentation source (see Engine Compatibility). Re-issuing
`stop()`/`play()` here costs nothing (the loop hasn't audibly started
yet, since `PENDING_GESTURE` holds at `SILENCE_FLOOR_DB`) and removes the
ambiguity outright, rather than relying on unverified catch-up behavior.

### 4. Watering trigger — companion edit to ADR-0004

**Companion edit to ADR-0004 (Ecosystem Simulation)**: `EcosystemSimulation`
gains one new signal,

```gdscript
signal watering_applied
```

emitted at the end of `apply_watering()`, after `jar_moisture` is
written. This is the correct fix per the registered `api_decision`
(`inter_system_communication_pattern`: direct calls for commands, signals
for notifications) — `apply_watering()` remains Tending Input's command
call unchanged; the new signal is purely an additional notification for
systems that only need to know it happened, matching exactly how every
other cross-system notification in this project already works. `AmbientAudio`
connects directly (`EcosystemSimulation.watering_applied.connect(_on_watering_applied)`),
resetting the watering envelope's elapsed-time accumulator to `0` on
each call (retrigger, not stack — Edge Cases).

**This closes the identical latent gap in ADR-0009** (Diorama Rendering's
Watering Substrate Sheen, Core Rule 11) — that ADR's Decision names the
sheen tween but never specified what triggers it. A short cross-reference
note is added to ADR-0009's Related Decisions pointing at this signal;
ADR-0009's own Decision content is otherwise unchanged (out of scope for
this ADR to rework).

### 5. Envelope timing — manual per-frame accumulation, not `Tween`

Each active envelope (fade-in, mute declick, watering swell, discovery
bed-shift) is tracked as a private elapsed-time `float`, incremented by
`delta` in `_process()`, fed into `AmbientAudioMath`'s pure static
functions (`volume_db(t)`, `watering_boost_db(t)`, etc. — new
non-autoload script, same `testable_pure_formula_placement` convention as
`ObjectPlacementMath`/`EcosystemFormulas`). Matches the GDD's own
Validation Criteria language (Formulas ACs 12–14: "`t` passed as an
explicit parameter") directly — a `Tween`-based implementation would need
to read a live `Tween`'s interpolated value before killing/restarting it
to satisfy the no-stacking retrigger rules, and wouldn't expose `t` as an
injectable unit-test value at all.

The final bus write happens once per frame:
`AudioServer.set_bus_volume_db(bus_idx, AmbientAudioMath.final_volume_db(...))`,
computed from the current `base_volume_db` plus both envelopes'
current-frame outputs, per the GDD's Combined Output formula.

**Note, not a new decision**: AC25's exact retrigger semantics ("resets
`t→0` and continues from L, not from 0") describe a continuity property
the GDD's own `envelope(t, D)` formula, as written, doesn't parameterize
on a starting level — reconciling the literal formula against that AC's
audible-continuity intent is a story/test-level implementation detail,
not an architecture decision; this ADR decides *how* elapsed time is
tracked (per-envelope float, reset on retrigger), not the formula itself.

### 6. Persisted state — read via `_process()`, not `_ready()` or a `restore()` method

Per `architecture.md`'s existing "no public API, nothing calls into it"
guarantee for Ambient Audio, `SessionBootstrap` does not call anything on
this autoload (unlike `EcosystemSimulation.restore()`/`ObjectPlacement.restore()`).
`AmbientAudio` instead reads `PersistenceSave.get_restored_blob()` itself
— but not from its own `_ready()`. Autoload `_ready()` order places
`AmbientAudio` before `SessionBootstrap` (declared last, per ADR-0002),
so `PersistenceSave.load()` (called by `SessionBootstrap._ready()` at
Data Flow §3 step 2) has not run yet at `AmbientAudio._ready()` time.
Instead, a one-shot flag is checked on `AmbientAudio`'s **first**
`_process()` call — by then, every autoload's `_ready()` (including
`SessionBootstrap`'s, which drives the entire restore sequence) has
already completed within the same initial frame, per Godot's node
lifecycle guarantee that all `_ready()` calls for a frame's entering
nodes finish before any `_process()` call for that frame begins:

```gdscript
var _initialized: bool = false

func _process(delta: float) -> void:
    if not _initialized:
        _initialized = true
        var blob := PersistenceSave.get_restored_blob()
        ambient_volume = blob.get("ambient_volume", DEFAULT_AMBIENT_VOLUME)
        muted = blob.get("muted", DEFAULT_MUTED)
    # ... session-state polling, envelope updates (§1, §5)
```

Defaults (`0.7`, `false`) match `ambient-audio.md`'s Tuning Knobs exactly.

### 7. Persistence write path — companion edit to ADR-0005

**Companion edit to ADR-0005 (Persistence/Save)**: `_mirror_to_js()` is
currently internal-only. It gains a public wrapper,

```gdscript
func refresh_mirror() -> void:
    _mirror_to_js()
```

The mute/volume UI control (owned by a future `/ux-design` pass — this
ADR only fixes the wiring, not the control itself) calls
`AmbientAudio.set_volume(v)`/`AmbientAudio.toggle_mute()` on `AmbientAudio`,
which updates its own `ambient_volume`/`muted` fields, then calls
`PersistenceSave.refresh_mirror()` directly — closing the exact gap
ADR-0005's own Risks section named in advance ("any future GDD/ADR that
adds a state-changing action outside tap/drag_end must add a
corresponding mirror-refresh hook").

**GDD Sync note** (surfaced here, resolved at write-approval below):
`persistence-save.md`'s Core Rule 1 blob field list does not currently
list `ambient_volume`/`muted`, despite that document's own Dependencies
section already describing Persistence/Save as reading/writing them —
the same blob-completeness omission class that document's own history
already corrected twice for other fields.

### Architecture Diagram
```
TimeDrift.get_state()  ──poll, _process()──>  AmbientAudio
DiscoverySurfacing.get_active_items()  ──poll, _process()──>  AmbientAudio
EcosystemSimulation.watering_applied  ──signal (NEW, ADR-0004 companion edit)──>  AmbientAudio
PersistenceSave.get_restored_blob()  ──poll, first _process() only──>  AmbientAudio

AmbientAudio (autoload)
   │  owns: AudioStreamPlayer (bus="Ambient", created in _ready())
   │  _state: INACTIVE | PENDING_GESTURE | LOOPING | MUTED
   │  _input(event)  — active only in PENDING_GESTURE, self-disabling
   │  per-frame: AmbientAudioMath.final_volume_db(...) → AudioServer.set_bus_volume_db()
   │
   ├─ set_volume(v) / toggle_mute()  ← called by future mute/volume UI control
   │      updates ambient_volume/muted, then calls PersistenceSave.refresh_mirror() (NEW)
   │
   └─ AmbientAudioMath (separate script, static, pure — volume_db, envelope,
      watering_boost_db, discovery_boost_db, final_volume_db)

EcosystemSimulation (autoload, ADR-0004)
   │  NEW: signal watering_applied — emitted at end of apply_watering()

PersistenceSave (autoload, ADR-0005)
   │  NEW: func refresh_mirror() -> void  (public wrapper over _mirror_to_js())
```

### Key Interfaces
```gdscript
# AmbientAudio (autoload) — Presentation, no public API consumed by any
# other system (architecture.md: "nothing calls into it") — these two
# methods exist only for the future mute/volume UI control to call.
func set_volume(v: float) -> void
func toggle_mute() -> void

# EcosystemSimulation (autoload, ADR-0004) — companion edit, this ADR
signal watering_applied
# NEW. Emitted at the end of apply_watering(), after jar_moisture is
# written. Also closes ADR-0009's identical latent trigger gap.

# PersistenceSave (autoload, ADR-0005) — companion edit, this ADR
func refresh_mirror() -> void
# NEW. Public wrapper over the existing internal _mirror_to_js(). Called
# by AmbientAudio.set_volume()/toggle_mute() — the first state-changing
# action in this project that doesn't route through Input Abstraction's
# tap/drag_end, per ADR-0005's own anticipated-gap Risk.

# AmbientAudioMath (ambient_audio_math.gd) — separate script, static, pure
class_name AmbientAudioMath
extends RefCounted
static func volume_db(ambient_volume: float, muted: bool) -> float
static func ease(x: float) -> float
static func fade_volume_db(t: float, d: float, target_volume_db: float) -> float
static func watering_boost_db(t: float) -> float
static func discovery_boost_db(t: float, n_active: int, w: float) -> float
static func final_volume_db(base_volume_db: float, watering_boost: float, discovery_boost: float) -> float
```

## Alternatives Considered

### Alternative 1: `Tween`-driven envelopes
- **Description**: `create_tween()`/`tween_property()` for every fade,
  matching the engine reference's own "Playing Audio" example.
- **Pros**: Less code to write per fade; idiomatic for simple one-shot
  transitions.
- **Cons**: Retrigger-without-restart (continue from the current
  interpolated value, never restart from 0) requires reading a live
  `Tween`'s current property value before killing and restarting it —
  workable but awkward; doesn't expose `t` as an injectable parameter,
  so the GDD's own explicit "`t` passed as an explicit parameter" ACs
  (12–14) can't be satisfied without wrapping the `Tween` in an
  equivalent pure-function shim anyway.
- **Rejection Reason**: Manual accumulation directly satisfies the GDD's
  own testability requirement with no wrapper needed, and this project
  already has an established pure-formula-script convention this fits
  into cleanly.

### Alternative 2: Route the mute/volume control's writes through Input Abstraction
- **Description**: Have the UI control emit synthetic `tap`/`drag_end`
  signals through `InputAbstraction` so ADR-0005's existing gesture hook
  fires unchanged.
- **Pros**: No new `PersistenceSave` method.
- **Cons**: Stretches Input Abstraction's gesture contract (built for
  jar-space taps/drags with jar-local coordinate conversion) to cover an
  unrelated fixed-position UI control; couples a UI element to a system
  it has no other reason to depend on, for a synthetic event with no real
  position meaning.
- **Rejection Reason**: A direct, explicit `refresh_mirror()` call is
  smaller and clearer than routing an unrelated UI action through a
  gesture pipeline built for a different purpose.

### Alternative 3: Query the browser `AudioContext` state directly via `JavaScriptBridge.eval()`
- **Description**: Poll `audioContext.state === 'running'` from GDScript
  instead of relying on "any input fired" as the unlock proxy.
- **Pros**: Would give a ground-truth answer instead of an inferred one.
- **Cons**: No Godot-exposed handle to the specific `AudioContext`
  instance Godot's own driver created — would require reaching into
  Godot's internal JS globals (`GodotAudio.ctx`), an unsupported,
  implementation-detail coupling that could break on any Godot patch
  release.
- **Rejection Reason**: Godot already auto-resumes the context on any
  input (engine-specialist source finding) — inferring unlock from "any
  input fired" is exactly the same trigger the engine's own internal
  logic uses, with no fragile private-API reach-through needed.

## Consequences

### Positive
- `watering_applied` closes a real gap for two systems (this one and
  ADR-0009) in one companion edit, matching the registered
  command-vs-notification pattern exactly.
- `refresh_mirror()` closes ADR-0005's own explicitly-anticipated gap
  the moment it actually occurs, rather than leaving it latent until a
  bug report.
- Reading persisted state via first-`_process()` polling (not a new
  `restore()` method) keeps Ambient Audio's "no public API" leaf-consumer
  status intact, consistent with `architecture.md`.
- Manual envelope accumulation reuses this project's established
  pure-formula-script pattern and satisfies the GDD's own testability
  ACs directly, no wrapper needed.

### Negative
- `AmbientAudio` is the first autoload in this project to own a real
  scene-tree node (`AudioStreamPlayer`) rather than being pure data —
  a new, if small, precedent.
- Three companion edits across two other ADRs (ADR-0004's signal,
  ADR-0005's `refresh_mirror()`) plus a GDD text gap in
  `persistence-save.md` — more cross-file surface than a typical ADR,
  because this GDD genuinely surfaced three previously-undetected gaps,
  not because of scope creep in this decision itself.
- The defensive `stop()`/`play()` re-trigger in `_input()` (§3) is
  unverified against real Web-export behavior — cheap to include, but
  not proof the underlying ambiguity doesn't matter.

### Risks
- **Risk**: pre-gesture `play()` catch-up behavior is unverified (Engine
  Compatibility). **Mitigation**: the defensive re-trigger in §3 removes
  dependence on it entirely; recommend a Gate D verification pass
  (real Web build, real browser, real gesture) before marking any
  `PENDING_GESTURE`-dependent AC as field-verified, matching this
  project's existing Gate A/B/C precedent (ADR-0008's identical framing
  for its own unverified touch behaviors).
- **Risk**: `AmbientAudio` owning a real node is a new autoload shape in
  this project — a future contributor unfamiliar with this ADR might
  assume all autoloads are node-free.
  **Mitigation**: named explicitly in Consequences → Negative above and
  in this ADR's Decision; no code-level guard needed, a documentation
  concern only.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| ambient-audio.md | Core Rule 1 (session-start, zero-delay `play()`) | `_process()` edge-detects `TimeDrift.get_state()`'s `INACTIVE→ACTIVE` transition, calls `_player.play()` unconditionally in the same frame. |
| ambient-audio.md | Core Rule 1a / States 1b/PENDING_GESTURE (browser autoplay policy) | `_input()` hook (§3), active only in `PENDING_GESTURE`, self-disabling; defensive re-trigger given the unverified pre-gesture `play()` catch-up behavior. |
| ambient-audio.md | Core Rule 3 (watering reactive layer) | `EcosystemSimulation.watering_applied` signal (companion edit, §4) drives the watering envelope's elapsed-time reset. |
| ambient-audio.md | Core Rule 4 (discovery reactive layer, category-weighted) | Polls `DiscoverySurfacing.get_active_items()` every frame (§2); `DiscoveryItem.category` feeds `CATEGORY_WEIGHT` directly, no new field needed. |
| ambient-audio.md | Core Rule 7 (persisted mute/volume) | Read via first-`_process()` poll of `PersistenceSave.get_restored_blob()` (§6); written via `refresh_mirror()` companion edit (§7). |
| ambient-audio.md | Fade Envelope / Reactive Layer Boosts ACs (12–16c, "t passed as an explicit parameter") | Manual per-frame elapsed-time accumulation feeding `AmbientAudioMath`'s pure functions (§5) — no redesign of the GDD's own formulas. |
| ambient-audio.md | Edge Case (retrigger continuity, no stacking) | Elapsed-time reset to `0` on each `watering_applied`/discovery-membership-change event, per-envelope, never summed. |
| persistence-save.md | Core Rule 1 blob-completeness (gap identified, not yet fixed in the GDD text) | `refresh_mirror()` companion edit closes the *write-path* gap; the GDD's own field-list text gap is flagged for a GDD Sync fix at write-approval, not silently left. |
| adr-0009 (diorama-rendering.md, Core Rule 11) | Watering Substrate Sheen trigger (previously unspecified) | Resolved by the same `watering_applied` signal — cross-referenced in ADR-0009's Related Decisions. |

## Performance Implications
- **CPU**: One `_process()` poll per frame (session-state edge-detect,
  discovery-cue array read, envelope math) — negligible at this
  project's scale (a handful of discovery items, one watering envelope).
  `AudioServer.set_bus_volume_db()` is a cheap per-frame call, not a
  per-sample operation.
- **Memory**: One `AudioStreamPlayer` node, one preloaded `AudioStream`
  (the 3–5MB Ogg Vorbis loop per the GDD's Web Export Format spec) —
  within the 256MB ceiling with wide margin.
- **Load Time**: The ambient loop asset loads once at `_ready()` via
  `preload()` — a few MB, negligible against session start.
- **Network**: N/A.

## Migration Plan
N/A — new system, no existing implementation to migrate from.

## Validation Criteria
- Unit tests call `AmbientAudioMath`'s pure functions directly with
  literal `t`/parameter values, reproducing the GDD's own worked examples
  and boundary ACs (9–16c) exactly, per `coding-standards.md`'s
  dependency-injection requirement — no autoload load required.
- Integration tests drive `AmbientAudio`'s state machine against a mocked
  `TimeDrift`/`DiscoverySurfacing`/`EcosystemSimulation`, covering
  ACs 1a/1b/3/6/17–26 (all already flagged Integration-tier by the GDD's
  own `qa-lead` review).
- **Gate D (new, recommended, not blocking)**: a real Web build,
  real-browser check of the pre-gesture `play()` → first-input →
  audible-output path, mirroring this project's existing Gate A/B/C
  structure (`docs/technical-setup/web-export-verification-plan.md`).
  Not required before implementation proceeds — the defensive re-trigger
  (§3) already hedges the unverified case — but required before any
  `PENDING_GESTURE`-dependent AC is marked field-verified, matching
  ADR-0008's identical precedent for its own untested touch behaviors.
- Rule 1/2's "no audible seam"/"feels complete" and the entire sonic
  palette (Visual/Audio Requirements) remain human listening-review
  items per the GDD's own Testability Notes — not automatable, not
  claimed as covered by any test here.

## Related Decisions
- `docs/architecture/adr-0002-signal-init-order-snapshot-architecture.md`
  — autoload/direct-call/signal convention this ADR follows; `SessionBootstrap`
  ordering is why persisted state is read on first `_process()`, not `_ready()`.
- `docs/architecture/adr-0004-ecosystem-simulation-tick-architecture.md`
  — companion-edited by this ADR to add `watering_applied`.
- `docs/architecture/adr-0005-persistence-save-web-storage-strategy.md`
  — companion-edited by this ADR to add `refresh_mirror()`; its own Risks
  section anticipated this exact gap.
- `docs/architecture/adr-0006-time-drift-session-lifecycle.md` — source
  of the polled `get_state()` session boundary.
- `docs/architecture/adr-0008-input-gesture-abstraction-web-touch-focus.md`
  — establishes the `_unhandled_input()`-defers-to-UI convention that
  makes this ADR's separate raw `_input()` hook necessary; source of the
  Gate A/B/C verification-gate precedent this ADR's Gate D follows.
- `docs/architecture/adr-0009-diorama-rendering-light2d-web-strategy.md`
  — receives a cross-reference note (not a content rework) pointing at
  this ADR's `watering_applied` signal, closing its own identical latent
  trigger gap.
- `docs/architecture/adr-0010-discovery-surfacing-reveal-queue-architecture.md`
  — source of `get_active_items()`/`DiscoveryItem.category`, consumed
  unchanged; this ADR registers as a second consumer.
- `design/gdd/ambient-audio.md` — full behavioral specification this ADR
  implements.
