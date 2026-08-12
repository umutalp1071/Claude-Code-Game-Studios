# Control Manifest

> **Engine**: Godot 4.7.1
> **Last Updated**: 2026-08-12
> **Manifest Version**: 2026-08-12
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0010, ADR-0011, ADR-0012
> **Status**: Active — regenerate with `/create-control-manifest update` when ADRs change

`Manifest Version` is the date this manifest was generated. Story files embed
this date when created. `/story-readiness` compares a story's embedded version
to this field to detect stories written against stale rules. Always matches
`Last Updated` — they are the same date, serving different consumers.

This manifest is a programmer's quick-reference extracted from all Accepted ADRs,
technical preferences, and engine reference docs. For the reasoning behind each
rule, see the referenced ADR. **ADR-0009 (Diorama Rendering) is excluded** —
still Status: Proposed, held pending Gate C4's unmeasured frame-budget data.
Regenerate this manifest once ADR-0009 is Accepted.

---

## Foundation Layer Rules

*Applies to: scene management, event architecture, save/load, engine initialisation*
*(Content Data, cross-cutting signal/init-order/snapshot architecture, Input Abstraction)*

### Required Patterns

- **Content type definitions are authored as native Godot `.tres` Resource files** using custom subclasses (`PlantTypeDef`, `CreatureTypeDef`, `ObjectTypeDef`), each declaring `class_name` so they appear by name in the editor's "New Resource" dialog — source: ADR-0001
- **Definitions live one file per instance** under `res://data/content/{plants,creatures,objects}/*.tres` — source: ADR-0001
- **Content Data's `_ready()` must**: scan each category directory via `DirAccess`, sort paths ordinally (never via `uid://`), load with `ResourceLoader.load()`, run `definition_validity()` before registry admission (reject + `push_warning()` on failure), key the registry `Dictionary[String, Resource]` by the definition's own `id` field — never by file path — source: ADR-0001
- **Content Data's registry must be fully loaded before any other system initializes** — source: ADR-0001
- **`get_definition(id) -> Resource` is the only public lookup surface**; the returned `Resource` is read-only by convention — source: ADR-0001
- **Use `Array[String]` typed arrays** (not `PackedStringArray`) for fields like `visual_stages` — source: ADR-0001
- **Commands/queries use direct typed method calls** on the owning system's public API; **notifications use Godot signals** — source: ADR-0002
- **`SessionBootstrap` (autoload) owns driving the 11-step session-start/save-load sequence** and must be the **LAST** autoload in Project Settings load order — source: ADR-0002
- **`SessionBootstrap._ready()`'s call order is fixed**: `PersistenceSave.load()`/`get_restored_blob()` → `EcosystemSimulation.restore()`/`ObjectPlacement.restore()` → `DiscoverySurfacing.capture_pre_batch_snapshot()` → `TimeDrift.run_catchup_and_activate()` → `CreatureBehavior.resolve_session_start()` → `DiscoverySurfacing.compute_delta()` — source: ADR-0002
- **Any snapshot copy of nested Dictionaries must use `.duplicate(true)`** (recursive) — never plain `.duplicate()` (shallow) — source: ADR-0002
- **`SessionBootstrap`'s `_ready()` must contain only the documented numbered sequence** — no unrelated startup logic — source: ADR-0002
- **`InputAbstraction` uses `_unhandled_input(event)` as its entry point**, never `_input()` — source: ADR-0008
- **Internal pointer identity must be tagged `(source: MOUSE|TOUCH, id: int)`**, never a bare `int` — source: ADR-0008
- **Compare device IDs against `InputEvent.DEVICE_ID_MOUSE`/`DEVICE_ID_KEYBOARD`**, never literal `0` — source: ADR-0008 (Godot 4.7 device-ID renumbering)
- **Convert event position to jar-local space via `get_viewport().canvas_transform.affine_inverse() * viewport_pos`, then `_jar.to_local()`** — never raw `.position` — source: ADR-0008
- **The drag-active threshold check compares raw, pre-conversion viewport-space positions**; jar-local conversion applies only at signal-emission time — source: ADR-0008
- **The jar node reference must be wired via explicit `register_jar(self)`** (called from the jar scene's own `_ready()`), never a lazy `%UniqueName` lookup — source: ADR-0008
- **Interruption detection connects to `get_window().focus_exited`/`focus_entered`** once in `InputAbstraction._ready()`; on `focus_exited`, force the active pointer IDLE and fire `drag_end(position, true, device_id)` if DRAGGING — source: ADR-0008
- **A single restartable `Timer`** (`process_mode = PROCESS_MODE_ALWAYS`, `wait_time = 8.0`, restarted per processed event) must drive the same IDLE/`drag_end(canceled=true)` transition on timeout, as a defensive watchdog — source: ADR-0008

### Forbidden Approaches

- **Never reference content definitions by `res://` path from gameplay code** — always by `id` — source: ADR-0001
- **Never resolve definition file order via `uid://`** — sorts unpredictably — source: ADR-0001
- **Do not author content as external JSON/CSV** — hand-rolled parsing/validation with no compile-time typing, rejected — source: ADR-0001
- **Do not add a `.tres`-source + JSON-export hybrid pipeline** without a real external consumer need — source: ADR-0001
- **No central event-bus/mediator autoload anywhere in the project** — source: ADR-0002 (registry `forbidden_patterns: event_bus_mediator`)
- **Never route synchronous request/response operations** (`get_definition()`, `get_position()`) **through signals** — source: ADR-0002
- **Do not have a Core-layer "central state owner" hold Presentation-layer bookkeeping** (e.g. Ecosystem Simulation holding Discovery Surfacing's snapshot) — source: ADR-0002
- **Do not implement the pre-batch snapshot as a tick-by-tick replay log** — source: ADR-0002
- **Do not use `_input()` as Input Abstraction's entry point** — sees events a UI `Control` already claimed — source: ADR-0008
- **Do not resolve the jar node reference via lazy `%UniqueName` lookup** — source: ADR-0008
- **AC10-family (interruption) criteria must not be marked passing on simulated-signal evidence alone** — requires real touch-hardware verification (Gate A1/A3/A4) — source: ADR-0008

### Performance Guardrails

- **Content Data load**: one-time directory scan + load per definition at startup, no per-frame cost — source: ADR-0001
- **`SessionBootstrap._ready()`** runs once per session; `_pre_batch_snapshot` must be discarded immediately after `compute_delta()`, never retained for session lifetime — source: ADR-0002
- **Input Abstraction's watchdog `Timer`** only ticks while a pointer is active; use a persistent `Timer`, not `get_tree().create_timer()`, to avoid `SceneTreeTimer` churn — source: ADR-0008

---

## Core Layer Rules

*Applies to: core gameplay loop, main player systems, physics, collision*
*(Object Placement, Ecosystem Simulation, Tending Input)*

### Required Patterns

- **Object Placement is a single autoload holding `Dictionary`** (object_id → `ObjectState`), keyed by `object_id` — never node reference or file path — source: ADR-0003
- **`ObjectState` is a standalone `RefCounted` subclass** (own file), not a `Resource` — source: ADR-0003
- **The four validity formulas** (`footprint_hit`, `in_bounds`, `no_overlap`, drag-follow) **live in a separate non-autoload script `ObjectPlacementMath`**, as `static func`s — never inside the autoload — source: ADR-0003
- **Object Placement must have zero scene-tree nodes of its own** — source: ADR-0003
- **`repositionable`/`footprint_size` are read once per object** via `ContentData.get_definition()` at registry population and cached — never re-queried per formula evaluation — source: ADR-0003
- **`footprint_hit` is inclusive**: `point.distance_to(obj_pos) <= fp` — source: ADR-0003
- **`in_bounds` must return `false` outright outside its domain precondition** (`fp < min(rx, ry)`) — never compute a misleading value — source: ADR-0003
- **`restore(restored_blob)` is called exactly once, only by `SessionBootstrap`**, before Input Abstraction's signals are live — source: ADR-0003
- **`is_within_any_footprint(point)` iterates the registry internally** — keeps `footprint_size` and the registry private to Object Placement — source: ADR-0003
- **`EcosystemSimulation` holds jar-wide scalars as plain fields** plus two `Dictionary` registries (`_plants`, `_creatures`) of `RefCounted` state classes — source: ADR-0004
- **`CreatureState.state` must be a real GDScript `enum Presence {PRESENT, ABSENT}`**, not an `int` with a comment — source: ADR-0004
- **All Ecosystem Simulation formulas live in a separate non-autoload script `EcosystemFormulas`**, as `static func`s taking all inputs as parameters — no reads of internal state, no engine RNG calls — source: ADR-0004
- **`EcosystemSimulation` owns a private `_rng: RandomNumberGenerator`** (`randomize()`'d once at `_ready()`); the roll is generated internally and passed into the pure `should_trigger_detail(roll, p_detail)` function — source: ADR-0004
- **`advance_tick()` applies exactly one tick's worth of change** and must be safe to call N times in a row; per-tick order is fixed: moisture decay → light tick → plants (before creatures, Core Rule 11) → creatures — source: ADR-0004
- **`set_last_known_position()` is called by Creature Behavior every live frame** — separate from `advance_tick()`'s per-tick orchestration — source: ADR-0004
- **`restore(restored_blob)` is called exactly once, only by `SessionBootstrap`** — source: ADR-0004
- **`get_plant_ids()`/`get_creature_ids()` must return ids in registration (insertion) order** — source: ADR-0004
- **Formula functions return typed results** (e.g. `Vector2i`, a `DebounceResult` `RefCounted` type) — never an ad-hoc `Dictionary` return bag — source: ADR-0004
- **`watering_applied` signal must be emitted at the end of `apply_watering()`**, after `_jar_moisture` is written — source: ADR-0004
- **`WATERING_AMOUNT` is a stored `const`, exposed via `get_watering_amount()`** — callers must never hardcode or redefine it — source: ADR-0004
- **Tending Input is a single stateless autoload** — zero scene-tree nodes, zero persisted fields — source: ADR-0011
- **Tending Input connects to `InputAbstraction.tap` once in its own `_ready()`**, using a direct (non-deferred) `Callable` — source: ADR-0011
- **On `tap`**: reject via `ObjectPlacementMath.in_bounds(..., fp=0.0)`, then reject via `ObjectPlacement.is_within_any_footprint()`, then call `EcosystemSimulation.apply_watering(EcosystemSimulation.get_watering_amount())` exactly once — source: ADR-0011
- **No `call_deferred`/`await`/`CONNECT_DEFERRED` anywhere in the tap-handling chain** — must resolve same-frame — source: ADR-0011
- **Tending Input connects only to `InputAbstraction.tap`** — never `drag_start`/`drag_move`/`drag_end` — source: ADR-0011
- **Autoload declaration order**: `EcosystemSimulation` and `InputAbstraction` must be declared before `TendingInput` in Project Settings — source: ADR-0011

### Forbidden Approaches

- **No `Area2D`/`CollisionShape2D`/physics engine for placement/collision math** — pure `Vector2` math only — source: ADR-0003
- **No public runtime write API on Object Placement beyond `restore()`** — every post-session-start position change goes through Input Abstraction's signals — source: ADR-0003
- **Never let any system other than Object Placement read `footprint_size` directly from Content Data** — source: ADR-0003
- **Do not use per-object `Node2D` scripts with sibling/group lookups for overlap checks** — source: ADR-0003
- **Do not assert `Dictionary[String, ObjectState]` generic typing** — use plain untyped `Dictionary` (unconfirmed engine support) — source: ADR-0003
- **`EcosystemSimulation` must never call outward to any other system** — pure state owner, query/command interface only — source: ADR-0004
- **Never expose or seed `_rng` outside `_ready()`** — no public setter — source: ADR-0004
- **Do not add a dedicated RNG-provider autoload** — source: ADR-0004
- **Do not let Time & Drift own or supply the detail-event RNG roll** — source: ADR-0004
- **Tending Input must never read Content Data or `footprint_size` directly, and must never enumerate Object Placement's objects itself** — source: ADR-0011
- **Do not write a second point-in-ellipse formula for jar-bounds checking** — reuse `ObjectPlacementMath.in_bounds` at `fp=0.0` — source: ADR-0011

### Performance Guardrails

- **`no_overlap` is O(n)** per validity check against a small fixed object count — revisit if object count grows substantially — source: ADR-0003
- **`advance_tick()` iterates 3 plants + 2 creatures at MVP scale** — negligible even at `max_catchup_ticks=84` — source: ADR-0004
- **`is_within_any_footprint` is O(n)** over a small fixed object count — same complexity class as `no_overlap` — source: ADR-0011

---

## Feature Layer Rules

*Applies to: secondary mechanics, session lifecycle, AI, discovery/reveal systems*
*(Persistence/Save, Time & Drift, Creature Behavior, Discovery Surfacing)*

### Required Patterns

- **`localStorage` (via `JavaScriptBridge.eval()`) is the sole Web-export storage backend**, for both foreground and hide-triggered writes — source: ADR-0005
- **`FileAccess`/`user://` is retained ONLY as the non-Web (editor/desktop dev) fallback** — never shipped in the Web path — source: ADR-0005
- **The hide-triggered write is handled entirely by a pure-JS `visibilitychange`/`pagehide` listener** with zero GDScript execution at the moment of hiding — source: ADR-0005
- **A JS-side mirror (`window.__persist_mirror`) must be refreshed via `_mirror_to_js()`** on: `save()`, `load()`, Input Abstraction's `tap`/`drag_end` signals, and the public `refresh_mirror()` wrapper — source: ADR-0005
- **`save()` is triggered ONLY by true session end** — never by `visibilitychange`/`pagehide` — source: ADR-0005
- **A `pageshow` listener must guard against bfcache restores**: `if (event.persisted) location.reload();` — source: ADR-0005
- **`FileAccess.store_*` return values (`bool`, post-cutoff) must be checked, not ignored**, in the non-Web fallback — source: ADR-0005
- **Last-known-good promotion logic lives in the pure-JS hide handler**, driven by a `window.__persist_current_valid` flag GDScript maintains — source: ADR-0005
- **`TimeDrift` holds `_state: SessionState {INACTIVE, CATCHING_UP, ACTIVE}`** and `_session_start_unix: int` — source: ADR-0006
- **`run_catchup_and_activate()` is called exactly once, only by `SessionBootstrap`**, spanning the catch-up batch and the `CATCHING_UP→ACTIVE` transition as one atomic call — source: ADR-0006
- **`Time.get_unix_time_from_system()` returns `float`** — every call site feeding an `int`-typed slot MUST cast explicitly (`int(Time.get_unix_time_from_system())`) — source: ADR-0006
- **`last_visit_timestamp` updates on EVERY hide event**, written via a one-line addition to ADR-0005's existing pure-JS handler — never a new GDScript hide hook — source: ADR-0006
- **`ticks_to_apply` must clamp negative/zero elapsed time to 0** and cap at `max_catchup_ticks` — source: ADR-0006
- **No `await`, `call_deferred()`, or `Thread` spawn inside any autoload's `_ready()`** (standing constraint on `SessionBootstrap`'s sequence) — source: ADR-0006, ADR-0007
- **`CreatureBehavior` polls `EcosystemSimulation.get_creature_state(id)` once per `_process()` frame per creature**, diffing against its own last-observed value — pull-based, never push/signal-based — source: ADR-0007
- **`resolve_session_start()` is called directly by `SessionBootstrap`, exactly once, before any `_process()` frame** — source: ADR-0007
- **`_instances: Dictionary` entries exist only while a live instance exists** — removed when `DEPARTING`'s exit animation completes — source: ADR-0007
- **`CreatureBehavior` owns a private `RandomNumberGenerator`** (`randomize()`'d once at `_ready()`, no public setter) for destination/pause draws, passed into pure formula functions — source: ADR-0007
- **Movement/destination/pause formulas live in a separate non-autoload script**, static and pure — source: ADR-0007
- **`DiscoverySurfacing` holds `_queue: Array[DiscoveryItem]`, `_state: State {IDLE, REVEALING}`, `_focused_elapsed: float`** — source: ADR-0010
- **Two entry points only, called exclusively by `SessionBootstrap`**: `capture_pre_batch_snapshot()` (step 5), `compute_delta()` (step 9) — source: ADR-0010
- **`DiscoveryItem` is a `RefCounted`, never a `Resource`** — source: ADR-0010
- **Registration-order tie-break must use `get_plant_ids()`/`get_creature_ids()`'s array index directly** — no separate index-lookup — source: ADR-0010
- **Queue ordering/timing formulas live in a separate non-autoload pure script, `DiscoverySurfacingMath`** — source: ADR-0010
- **Focus-pause timing connects directly to `Window.focus_exited`/`focus_entered`** in `DiscoverySurfacing`'s own `_ready()`, independent of Input Abstraction — source: ADR-0010
- **`_process(delta)` only advances `_focused_elapsed` when `_state == REVEALING and not _paused`** — source: ADR-0010
- **`DiscoverySurfacingMath`'s sort comparator takes `registration_index` as a caller-supplied parameter**, never looks it up internally — source: ADR-0010

### Forbidden Approaches

- **Never introduce a periodic/interval autosave** — only session-end and hide may ever commit to `localStorage` — source: ADR-0005
- **Do not use `FileAccess`/IDBFS + `FS.syncfs()` for the Web export path** — dropped entirely — source: ADR-0005
- **Do not rely on a GDScript callback executing during a hide event for the Web persistence path** — source: ADR-0005
- **Do not attempt to distinguish a true tab close from mere backgrounding** — no reliable signal exists on the Web platform — source: ADR-0006
- **Do not add a new GDScript-side hide hook for the timestamp update** — reuse ADR-0005's pure-JS listener only — source: ADR-0006
- **Any future change to ADR-0005's JS hide-listener layer must preserve the `pageshow`/`event.persisted` reload guard** — source: ADR-0006
- **Do not have Ecosystem Simulation emit a signal on PRESENT/ABSENT transitions for Creature Behavior** — would violate its "never calls outward" guarantee — source: ADR-0007
- **Do not merge `resolve_session_start()` with the live `_process()` diff-poll** — conflating them risks reintroducing the CATCHING_UP race — source: ADR-0007
- **Do not route Discovery Surfacing's focus-pause detection through Input Abstraction** — `Window`'s focus signal is global engine state, not owned by Input Abstraction — source: ADR-0010
- **Do not add a stale-timer watchdog for the focus-pause mechanism** (unlike Input Abstraction's) — lower-severity failure mode, YAGNI — source: ADR-0010
- **Do not implement per-item reveal sequencing as a two-state QUEUED↔REVEALING ping-pong** — contradicts the GDD's locked overlap formulas — source: ADR-0010

### Performance Guardrails

- **Save blob must stay comfortably under `localStorage`'s ~5MB Safari / ~10MB Chrome/Firefox per-origin quota** — source: ADR-0005
- **`JavaScriptBridge.eval()` calls are per-gesture-commit only, not per-frame** — source: ADR-0005
- **`ticks_to_apply` is O(1); `day_night_phase` is one `fmod` per frame during ACTIVE** — source: ADR-0006
- **Per-frame diff-poll over ≤2 creatures at MVP scale is O(1) in practice** — revisit if creature count grows substantially — source: ADR-0007
- **`compute_delta()` is O(plants + creatures) once per session; `get_active_items()` is O(queue depth, ≤8), called every frame** — source: ADR-0010

---

## Presentation Layer Rules

*Applies to: rendering, audio, UI, VFX, shaders, animations*
*(Ambient Audio — Diorama Rendering excluded, ADR-0009 still Proposed)*

### Required Patterns

- **`AmbientAudio` owns exactly one real scene-tree node**, an `AudioStreamPlayer`, created programmatically in `_ready()`; `_bus_idx` cached once via `AudioServer.get_bus_index()`, never re-looked-up per frame — source: ADR-0012
- **A new `Ambient` bus (child of `Master`) must exist in the project's Audio Bus Layout resource** — one-time editor setup — source: ADR-0012
- **Session state detected by polling `TimeDrift.get_state()` every `_process()` frame with edge-detection**; `INACTIVE→ACTIVE` calls `_player.play()` unconditionally, `ACTIVE→INACTIVE` calls `_player.stop()` immediately with no fade-out — source: ADR-0012
- **Discovery cues read by polling `DiscoverySurfacing.get_active_items()` once per `_process()` frame** while LOOPING/MUTED — re-evaluated live, never cached — source: ADR-0012
- **Gesture-unlock uses a dedicated raw `_input(event)` hook**, active only in `PENDING_GESTURE`, self-disabling via `set_process_input(false)` after firing once, re-enabled at the next `INACTIVE→ACTIVE` transition; on fire, defensively re-issue `stop()` then `play()` — source: ADR-0012
- **`EcosystemSimulation.watering_applied` signal must trigger the watering reactive-layer envelope** — connected directly, never inferred by polling `apply_watering()`'s call site — source: ADR-0012
- **Every active envelope must be tracked as a private elapsed-time `float`**, incremented by `delta` in `_process()`, fed into pure static functions in `AmbientAudioMath` — never a `Tween` — source: ADR-0012
- **The final bus volume write (`AudioServer.set_bus_volume_db()`) happens once per frame** — source: ADR-0012
- **Persisted `ambient_volume`/`muted` must be read via a one-shot flag checked on `AmbientAudio`'s FIRST `_process()` call** — never `_ready()` — source: ADR-0012
- **`PersistenceSave.refresh_mirror()` must be called directly by `AmbientAudio.set_volume()`/`toggle_mute()`** after mutating state — source: ADR-0012

### Forbidden Approaches

- **Ambient Audio must never gate or block gameplay input** regardless of audio/`AudioServer` state — source: ADR-0012
- **Do not give Ambient Audio a `restore(restored_blob)` companion method** — it has no public API; pull persisted state via polling only — source: ADR-0012
- **Do not route the mute/volume control's persistence writes through synthetic `tap`/`drag_end` signals** — call `refresh_mirror()` directly — source: ADR-0012
- **Do not query the browser `AudioContext` state via `JavaScriptBridge.eval()` reaching into Godot's internal JS globals** — unsupported, could break on any patch release — source: ADR-0012

### Performance Guardrails

- **One `_process()` poll per frame for session-state/discovery-cue/envelope math** — negligible at project scale — source: ADR-0012
- **The ambient loop asset (~3-5MB Ogg Vorbis) loads once via `preload()`** — within the 256MB ceiling with wide margin — source: ADR-0012

---

## Global Rules (All Layers)

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `PlayerController` |
| Variables | snake_case | `move_speed` |
| Signals/Events | snake_case, past tense | `health_changed` |
| Files | snake_case matching class | `player_controller.gd` |
| Scenes/Prefabs | PascalCase matching root node | `PlayerController.tscn` |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH` |

Source: `.claude/docs/technical-preferences.md`

### Performance Budgets

| Target | Value |
|--------|-------|
| Framerate | 60fps |
| Frame budget | 16.6ms |
| Draw calls | ≤500 (conservative target for the Compatibility/web renderer) |
| Memory ceiling | ≤256MB active memory (conservative browser-tab budget) |

Source: `.claude/docs/technical-preferences.md`

### Approved Libraries / Addons

- None configured yet — add as dependencies are approved (`.claude/docs/technical-preferences.md`)

### Forbidden APIs (Godot 4.7.1)

These APIs are deprecated or renamed for Godot 4.7.1 — source: `docs/engine-reference/godot/deprecated-apis.md`

**Nodes & Classes**

| Deprecated | Use Instead | Since |
|------------|-------------|-------|
| `TileMap` | `TileMapLayer` | 4.3 |
| `VisibilityNotifier2D` | `VisibleOnScreenNotifier2D` | 4.0 |
| `VisibilityNotifier3D` | `VisibleOnScreenNotifier3D` | 4.0 |
| `YSort` | `Node2D.y_sort_enabled` | 4.0 |
| `Navigation2D` / `Navigation3D` | `NavigationServer2D` / `NavigationServer3D` | 4.0 |
| `EditorSceneFormatImporterFBX` | `EditorSceneFormatImporterFBX2GLTF` | 4.3 |

**Methods & Properties**

| Deprecated | Use Instead | Since |
|------------|-------------|-------|
| `yield()` | `await signal` | 4.0 |
| `connect("signal", obj, "method")` | `signal.connect(callable)` | 4.0 |
| `instance()` | `instantiate()` | 4.0 |
| `PackedScene.instance()` | `PackedScene.instantiate()` | 4.0 |
| `get_world()` | `get_world_3d()` | 4.0 |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` | 4.0 |
| `duplicate()` for nested resources | `duplicate_deep()` | 4.5 |
| `Skeleton3D` signal `bone_pose_updated` | `skeleton_updated` | 4.3 |
| `AnimationPlayer.method_call_mode` | `AnimationMixer.callback_mode_method` | 4.3 |
| `AnimationPlayer.playback_active` | `AnimationMixer.active` | 4.3 |
| `RichTextLabel.ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT` | `UPDATE_WIDTH_UNIT` | 4.7 |
| `AudioEffectSpectrumAnalyzer.tap_back_pos` | *(removed, no replacement)* | 4.7 |
| Comparing mouse/keyboard device ID to literal `0` | `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD` | 4.7 |

**Patterns (Not Just APIs)**

| Deprecated Pattern | Use Instead |
|--------------------|-------------|
| String-based `connect()` | Typed signal connections |
| `$NodePath` in `_process()` | `@onready var` cached reference |
| Untyped `Array` / `Dictionary` | `Array[Type]`, typed variables |
| `Texture2D` in shader parameters | `Texture` base type |
| Manual post-process viewport chains | `Compositor` + `CompositorEffect` |
| GodotPhysics3D for new projects | Jolt Physics 3D |

### Cross-Cutting Constraints

- **No central event-bus/mediator autoload anywhere in the project** (registry `forbidden_patterns: event_bus_mediator`) — source: ADR-0002, reaffirmed by ADR-0008/ADR-0010
- **Commands/queries use direct typed method calls; notifications use Godot signals** — source: ADR-0002
- **`SessionBootstrap` loads LAST in the autoload order**; every autoload it calls into must already have completed `_ready()` — source: ADR-0002
- **No `await`, `call_deferred()`, or `Thread` spawn inside any autoload's `_ready()`** — breaks the structural init-order guarantees ADR-0006/ADR-0007 depend on — source: ADR-0006, ADR-0007
- **All public methods must be unit-testable via dependency injection over singletons; static typing on all public methods** — source: `.claude/docs/coding-standards.md`, applied throughout every ADR's pure-formula-script convention
- **Gameplay values must be data-driven (external config/tuning constants), never hardcoded** — source: `.claude/docs/coding-standards.md`, echoed by ADR-0004/ADR-0011's `WATERING_AMOUNT` pattern
- **Compare mouse/keyboard device IDs to `InputEvent.DEVICE_ID_MOUSE`/`DEVICE_ID_KEYBOARD`, never literal `0`** — source: `docs/engine-reference/godot/deprecated-apis.md`, ADR-0008 (Godot 4.7)
