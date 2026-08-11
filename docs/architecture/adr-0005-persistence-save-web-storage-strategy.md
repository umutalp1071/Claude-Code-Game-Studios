# ADR-0005: Persistence & Save — Web Export Storage Strategy

## Status
Accepted (2026-08-11 — gate-check re-run, Technical Setup → Pre-Production)

## Date
2026-08-10

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Core / Persistence (Web export) |
| **Knowledge Risk** | HIGH per `VERSION.md` in general for this engine version — but the specific behaviors this ADR depends on (JS→GDScript callback timing during tab-hide, `FileAccess`/IDBFS write survival, `localStorage` survival) were **empirically verified**, not inferred from training data. See Evidence below. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md` (no Web-export persistence-timing entries in any of the four across the pinned 4.4–4.7 range — confirmed empty, not skipped); `docs/technical-setup/web-export-verification-plan.md` §2 (Gate B) and its RESULT tables (source of the Evidence below); `prototypes/web-export-spike/` (the runnable probes that produced it) |
| **Post-Cutoff APIs Used** | `FileAccess.store_*` methods return `bool` (not `void`) as of a post-cutoff change (`breaking-changes.md` line 69) — relevant only to this ADR's non-Web/editor fallback path (Implementation Requirements §4); the return value must be checked, not ignored, unlike pre-cutoff GDScript idiom. `JavaScriptBridge.eval()` and `OS.has_feature("web")` are stable pre-cutoff APIs, no version risk. `JavaScriptBridge.create_callback()` is **not** used by this design (option (c) specifically eliminates the need for a GDScript-JS callback at hide time) — it appears only in the spike's now-superseded probe code. |
| **Verification Required** | WebKit/iOS Safari — see Consequences → Risks. Nothing further required on Chromium; do not re-run the spike (per explicit instruction — this ADR is written from the completed Chrome-desktop evidence only). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (SessionBootstrap owns the session-start/save-load sequencing this ADR's `load()`/`save()` plug into — Persistence/Save does not invent its own ordering); ADR-0001 (Content Data's `get_definition()` is the `type_id`-existence check `save_blob_validity` requires) — both Proposed, same as this ADR. |
| **Enables** | Persistence/Save implementation epic/stories; unblocks the save-confirmation cue for Diorama Rendering (provisional dependency per `persistence-save.md` Core Rule 8) once that GDD exists. |
| **Blocks** | No epic is currently blocked *waiting* on this ADR (Persistence/Save's epic has not been created yet) — this ADR removes the BLOCKING flag from `persistence-save.md`'s Open Questions, which was itself blocking `/architecture-decision` for this system (now resolved by this document). |
| **Ordering Note** | This ADR does not change ADR-0002's step ordering (Data Flow §3/§4 in `architecture.md`) — only the *mechanism* behind steps 2 (load) and the backgrounding-write bullet. `architecture.md` is updated alongside this ADR (see Related Decisions) to keep the two in sync. |

## Context

### Problem Statement

`persistence-save.md` carried two BLOCKING Open Questions that `/architecture-decision` for this system could not proceed past without empirical data:

1. **HTML5/IndexedDB write reliability** — does a `FileAccess`/`user://` write reliably commit before a Web-export tab closes, or does it need an explicit `FS.syncfs()`?
2. **`visibilitychange`/`pagehide` reachability** — can a `JavaScriptBridge` callback actually execute GDScript while the tab is hidden, or is the WASM main loop suspended before it gets a frame?

The GDD had already pre-drafted three candidate mechanisms (labeled (a)/(b)/(c) in its own Open Questions section) but explicitly deferred choosing between them pending verification. The Web Export Spike (`prototypes/web-export-spike/`, Gate B) has now been run — **desktop Chrome only**, per explicit user decision not to pursue mobile/physical-device testing. This ADR makes the storage-mechanism decision from that evidence.

### Constraints

- Web export only targets the Compatibility/WebGL2 renderer (unrelated to persistence, but confirms this is a browser-hosted WASM context throughout — see `technical-preferences.md`).
- The save blob is small: one jar's worth of ints, short `type_id` strings, and small arrays (`persistence-save.md` Formulas' own storage-ceiling analysis: comfortably under `localStorage`'s ~5MB Safari / ~10MB Chrome/Firefox per-origin quota).
- `creative-director` has already ruled, in the GDD itself, on the general shape of this tradeoff: "prefer the option that removes the race over the option that mitigates it... unless a concrete storage-size or implementation-complexity reason rules it out." No such reason has surfaced.
- **No further browser/device testing is available for this decision.** WebKit (desktop Safari, iOS Safari) is permanently out of scope for this pass. This ADR must either resolve on Chromium-only evidence with a named residual risk, or remain Proposed-but-blocked — it cannot wait for data that will not arrive.

### Requirements

- Must reliably persist the save blob at true session end (Core Rule 5, AC1).
- Must reliably persist the save blob when the tab is hidden/backgrounded, specifically to survive a hard kill during an ACTIVE session (Core Rule 5, AC1a/AC10) — this is the requirement the spike's Gate B evidence most directly bears on.
- Must support the last-known-good fallback tier (Core Rule 7) — two stored blobs, promotion logic on write.
- Must not introduce a periodic/interval autosave (AC11 — the mitigation for the hide-triggered write must not, in effect, become a disguised autosave).
- Must integrate with the already-Proposed `SessionBootstrap` sequencing (ADR-0002) without redefining it.

## Decision

**Adopt GDD option (c): a JS-side mirrored save blob, written by a pure-JS `visibilitychange`/`pagehide` listener with zero GDScript execution required at the moment of hiding.** Drop `FileAccess`/IDBFS (option (a)) entirely from the Web export path. `localStorage`, accessed via `JavaScriptBridge.eval()`, is the sole Web-export storage backend for both the foreground (true-session-end) write and the hide-triggered write. `FileAccess`/`user://` is retained only as the non-Web (editor/desktop dev) fallback, never shipped as part of the Web persistence path.

**Why not (a) or (b), independently verified against the evidence — not just deferring to the suggested option:**

- **(a) and (b) are not independent of each other** (the GDD's own round-12 finding, confirmed by this ADR's re-reading): both require GDScript to actually execute *during* the hide event. Gate B's B1 result (0.5ms lag, frame unchanged) shows this executes reliably **on Chromium**. But that single data point does not de-risk WebKit — Safari's background-tab JS/timer throttling is independently documented to be more aggressive than Chromium's, which is precisely why the verification plan named Safari "the highest-risk engine for Gate B" *before* any testing occurred. Betting the core persistence guarantee on the one axis that is both unverified and independently expected to diverge on the untested browser is not a sound architectural choice, regardless of how clean the Chrome number looks.
- **(a) specifically adds a second, independent failure surface on top of that shared risk**: IDBFS is a two-step mechanism (write to an in-memory layer, then an async `FS.syncfs()` flush to real IndexedDB) even when the flush is called explicitly. Gate B measured this directly: without `FS.syncfs()`, 2/3 survived a hard kill (one demonstrated failure); with it, 5/5. The GDD's own text already flags that even the synced case is "still fragile per practitioners, since a tab close can interrupt the sync itself" — a theoretical race a 5-trial single-browser sample cannot rule out. (a) also does not remove (b)'s WebKit risk, since the actual `FileAccess` write still has to happen from GDScript during the hide callback — it inherits B1's risk *and* adds its own. There is no scenario in which (a) is strictly better than (b) for this project's data shape; it is only historically the more "native"-feeling mechanism.
- **(c) is the only option that removes the B1 dependency from the hide-triggered write entirely, by construction.** Its whole design point — a JS-side mirror kept current, persisted by a pure-JS listener with no engine involvement — means the only GDScript-dependent step (serializing and mirroring the blob) happens during ordinary foregrounded execution, a context with no known throttling risk on any browser. The risky step (GDScript running on a hidden/backgrounded tab) is removed from the critical path rather than merely measured and trusted.
- **(c) also satisfies Core Rule 8's save-confirmation-cue honesty requirement better than the alternatives** — a fact already noted in the GDD's own round-12 text, not new here: a synchronous `localStorage` write is the one path where "saved" and "committed" are the same operation, rather than an optimistic assumption.

**A gap found independent of the raw spike evidence, and closed here rather than left to implementation:** the GDD's option (c) text says the JS-side mirror is refreshed "at each true-session-end write." Taken literally, that would mean a hide event mid-visit re-persists whatever was current *at the previous session's end* — silently defeating Core Rule 5's actual purpose (a crash never costs the current visit's tending), which was the whole reason the backgrounding trigger was added in round 11. This ADR closes that gap: the mirror is also refreshed on Input Abstraction's existing `tap` and `drag_end` signals (see Key Interfaces) — no new cross-system signal is introduced, and this does not violate AC11 (no periodic autosave), because refreshing an in-memory JS string is not a storage write; only the two GDD-specified triggers (session end, hide) ever commit to `localStorage`.

### Architecture Diagram

```
                         ┌─────────────────────────────────────────┐
                         │              GDScript side               │
                         │                                           │
  Input Abstraction ──tap/drag_end──▶  PersistenceSave._on_gesture() │
  (existing signals,                     │                           │
   no new contract)                      ▼                           │
                         │        _serialize() -> Dictionary         │
                         │              │                            │
                         │              ▼                            │
                         │   JavaScriptBridge.eval(                  │
                         │     "window.__persist_mirror = ...;       │
                         │      window.__persist_current_valid=…",   │
                         │     true)  # use_global_execution_context │
                         │   (cheap, gesture-rate, not per-frame)    │
                         │                                           │
  SessionBootstrap ──true session end──▶ PersistenceSave.save()      │
                         │   same _serialize(), then                 │
                         │   JavaScriptBridge.eval(                  │
                         │     "localStorage.setItem('save_current',…)",│
                         │     true)                                  │
                         │   (synchronous, foregrounded — no B1 risk) │
                         └─────────────────────────────────────────┘
                                          │
                                          │ (mirror var + valid flag
                                          │  kept current via the above)
                                          ▼
                         ┌─────────────────────────────────────────┐
                         │           Pure JS side (HideBridge)       │
                         │  visibilitychange/pagehide listener:      │
                         │    if (window.__persist_current_valid)    │
                         │      localStorage.save_last_known_good =  │
                         │        localStorage.save_current;         │
                         │    localStorage.save_current =            │
                         │      window.__persist_mirror;             │
                         │  — zero GDScript execution required.      │
                         │                                           │
                         │  pageshow listener (bfcache guard):        │
                         │    if (event.persisted) location.reload();│
                         └─────────────────────────────────────────┘
```

### Key Interfaces

`architecture.md`'s existing API sketch for Persistence/Save is **confirmed unchanged at the public-signature level** — this ADR decides the *mechanism* behind it, not the shape SessionBootstrap already calls into:

```gdscript
# Persistence/Save (autoload) — Feature. Public signature unchanged from architecture.md.
func save() -> void          # called ONLY by SessionBootstrap at true session end
func load() -> bool          # called ONLY by SessionBootstrap, step 2 of the restore sequence
func get_last_visit_timestamp() -> int
func set_last_visit_timestamp(ts: int) -> void   # called ONLY by Time & Drift, only on true session end
func get_restored_blob() -> Dictionary  # NEW — exposes the validated blob for SessionBootstrap's
                                          # steps 3/4 to pull typed fields from (ADR-0004 line 102-104's
                                          # already-established pattern: SessionBootstrap populates
                                          # Ecosystem Simulation's/Object Placement's registries directly
                                          # at bootstrap time; this is the source it pulls from)
func refresh_mirror() -> void  # NEW — companion edit, ADR-0012 (2026-08-11). Public wrapper over the
                                 # existing internal _mirror_to_js() (below). Called by Ambient Audio's
                                 # mute/volume control after mutating ambient_volume/muted — the first
                                 # state-changing action in this project that doesn't route through
                                 # Input Abstraction's tap/drag_end, closing the exact gap this ADR's own
                                 # Risks section anticipated in advance.

# Correction to architecture.md's existing comment on save():
# save() is NOT triggered by visibilitychange/pagehide under this decision. The hide-triggered write
# is handled entirely by the pure-JS listener below, using the mirror this autoload keeps current.
# save() is triggered ONLY by true session end.
```

```gdscript
# Internal (not part of the public autoload API):
func _serialize() -> Dictionary
func _mirror_to_js() -> void
  # JavaScriptBridge.eval("window.__persist_mirror = " + JSON.stringify(_serialize()) + ";
  #                        window.__persist_current_valid = " + str(_current_is_valid) + ";", true)
  # window.__persist_current_valid (bool: was the blob most recently loaded, or written, known-valid —
  # Core Rule 7's promotion precondition, computed in GDScript once and carried as a flag so the pure-JS
  # hide handler needs zero validation logic of its own).
  # Called from: save() (session end), load() (after a successful restore — the freshly-loaded blob is
  # itself known-valid), the tap/drag_end gesture hook (Decision, gap-closing paragraph above), and now
  # the public refresh_mirror() wrapper (companion edit, ADR-0012, 2026-08-11 — see Key Interfaces above).

func _on_gesture(...) -> void   # connected to Input Abstraction's existing `tap`/`drag_end` signals
  # (architecture.md API Boundaries — no new signal contract). Calls _mirror_to_js(). Fires on canceled
  # drags too; harmless — re-mirroring unchanged data is a no-op cost, not a correctness issue.

func load() -> bool:
  # var raw: Variant = JavaScriptBridge.eval("localStorage.getItem('save_current')", true)
  # var current: Dictionary = JSON.parse_string(raw) if raw != null else {}   # parse_string() -> null on malformed JSON
  # if current and save_blob_validity(current):
  #     _restored_blob = current; _current_is_valid = true; _mirror_to_js(); return true
  # var lkg_raw: Variant = JavaScriptBridge.eval("localStorage.getItem('save_last_known_good')", true)
  # var lkg: Dictionary = JSON.parse_string(lkg_raw) if lkg_raw != null else {}
  # if lkg and save_blob_validity(lkg):
  #     _restored_blob = lkg; _current_is_valid = true; _mirror_to_js(); return true   # Core Rule 7
  # _current_is_valid = false; return false   # Core Rule 4 — every system defaults
```

```javascript
// HideBridge (autoload's installed JS, extends the pattern already proven in
// prototypes/web-export-spike/hide_bridge.gd — production version, not the throwaway probe)
window.__persist_hide = function () {
  if (document.visibilityState !== 'hidden') return;
  var blob = JSON.parse(window.__persist_mirror);
  blob.last_visit_timestamp = Math.floor(Date.now() / 1000);  // added by ADR-0006 (Time & Drift)
  window.__persist_mirror = JSON.stringify(blob);
  if (window.__persist_current_valid) {
    localStorage.setItem('save_last_known_good', localStorage.getItem('save_current'));
  }
  localStorage.setItem('save_current', window.__persist_mirror);
};
document.addEventListener('visibilitychange', window.__persist_hide);
window.addEventListener('pagehide', window.__persist_hide);

// bfcache guard (Consequences → Risks, B4 mitigation)
window.addEventListener('pageshow', function (event) {
  if (event.persisted) location.reload();
});
```

```gdscript
# Non-Web (editor/desktop dev) fallback — never shipped as part of the Web persistence path:
if not OS.has_feature("web"):
    var f := FileAccess.open("user://save_current.json", FileAccess.WRITE)
    if f == null:
        push_error("save_current.json open failed: %s" % FileAccess.get_open_error())
    else:
        if not f.store_string(JSON.stringify(_serialize())):  # bool return, post-cutoff — checked, not ignored
            push_error("store_string failed")
        f.close()
```

## Alternatives Considered

### Alternative (a): `FileAccess`/IDBFS + explicit `FS.syncfs()`
- **Description**: Write the save blob via `FileAccess` to `user://`, then force `JavaScriptBridge.eval("FS.syncfs(false, cb)")` after each critical write.
- **Pros**: Uses Godot's "native" persistence API; no hand-written JS storage logic.
- **Cons**: Shares option (b)'s B1 dependency (GDScript must run during hide) *and* adds its own async-flush race on top; Gate B measured a real failure without `syncfs()` (2/3) and cannot rule out the flush-interrupted-by-close race even with it (5/5 on a 5-trial single-browser sample).
- **Rejection Reason**: Strictly dominated by (c) for this data shape — no advantage that offsets carrying both risks at once.

### Alternative (b): GDScript-triggered `localStorage` write via `JavaScriptBridge.eval()` during the hide callback
- **Description**: On `visibilitychange`, the JS listener calls back into GDScript (as Gate B's `probe_gd` did), which then evals a `localStorage.setItem()` call.
- **Pros**: Simpler than (c) — no separate JS-side mirror to keep fresh; Gate B's `probe_gd` data (persisted/advanced across hard-kill trials) shows this mechanism itself works on Chrome.
- **Cons**: Still fully dependent on B1 (GDScript executing during hide) — the exact axis independently flagged as highest-risk for the untested browser family.
- **Rejection Reason**: (c) provides the same outcome with the B1 dependency removed from the hide-critical path, at the marginal cost of maintaining a JS-side mirror — a cost this ADR judges worth paying given WebKit is permanently unverified for this decision.

## Consequences

### Positive
- The hide-triggered write no longer depends on GDScript executing on a hidden tab at all — the single largest unverified-and-independently-expected-to-diverge risk is architecturally removed, not just measured and trusted.
- Single storage backend (`localStorage`) for the Web path instead of two (IDBFS + localStorage), reducing implementation and reasoning surface.
- Save-confirmation cue (Core Rule 8) can be genuinely honest — commit and confirmation are the same synchronous operation.
- Both `persistence-save.md`'s BLOCKING Open Questions are resolved by this decision (see Related Decisions).

### Negative
- Introduces a JS-side mirror that must be kept in sync with GDScript state — a small but real piece of duplicated state (mitigated by the gesture-triggered refresh in Key Interfaces; the mirror is derived, never authoritative — `_serialize()` is the single source of truth it's regenerated from).
- Two storage code paths now exist (Web: `localStorage`/JS; non-Web: `FileAccess`) rather than one — acceptable because the non-Web path is dev-only and never ships, but it is still surface a reviewer must know to check.
- `FS.syncfs()`-based IDBFS support is fully abandoned for Web, so if a future requirement needs `FileAccess` semantics on Web (e.g., a much larger save blob under Multi-Jar Management, Alpha tier), this decision would need revisiting rather than extending.

### Risks

- **WebKit/iOS Safari is entirely unverified for this decision (B4, and B1/B2/B3 more generally).** This is the primary named residual risk. Mitigations already baked into the Decision: (c)'s zero-engine-involvement design specifically targets the failure mode WebKit is most likely to exhibit (aggressive background-tab throttling), and the `pageshow`/bfcache-reload guard defends against the specific WebKit-only behavior (bfcache restoring the page without re-running `_ready()`) that this project cannot verify is even not a problem. **This risk is not closed — it is architecturally hedged.** If/when a WebKit device becomes available, re-run Gate B (B1/B2/B3/B4) against this design specifically (not the throwaway spike) to confirm.
- **The gesture-triggered mirror refresh (tap/drag_end) could, in principle, miss a state change that doesn't route through those two signals** (e.g., a hypothetical future system that mutates save-relevant state without any user gesture — none currently exists in the 11 GDDs, but a future one could). Mitigation: this ADR's Key Interfaces section names the exact trigger surface; any future GDD/ADR that adds a state-changing action outside tap/drag_end must add a corresponding mirror-refresh hook, the same "blob-completeness principle" discipline `persistence-save.md` Core Rule 1 already established for the blob's own field list.
- **`localStorage` is synchronous and blocks the calling thread** — for this project's single-threaded Web export (Thread Support OFF per the verification plan's own export settings), this is a non-issue in practice (no other thread to block), but would need reconsideration if threading is ever enabled.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| persistence-save.md | Open Question: HTML5/IndexedDB write reliability | Resolved — IDBFS/`FileAccess` dropped for Web; `localStorage` is the sole Web storage backend, verified on Chrome (Gate B B2/B3). |
| persistence-save.md | Open Question: `visibilitychange`/`pagehide` reachability | Resolved — the hide-triggered write no longer depends on reachability at all (option (c)); B1's Chrome PASS confirms the foreground write path (session-end + mirror refresh) is safe. |
| persistence-save.md | Core Rule 5 (backgrounding write) | Implemented via the pure-JS `HideBridge` listener, not a GDScript callback, per the Decision. |
| persistence-save.md | Core Rule 7 (last-known-good promotion) | Promotion logic moved into the pure-JS handler, driven by a `window.__persist_current_valid` flag GDScript maintains — see Key Interfaces. |
| persistence-save.md | Core Rule 8 (save-confirmation cue honesty) | `localStorage`'s synchronous write makes commit and confirmation the same operation, per the GDD's own round-12 note. |
| persistence-save.md | AC11 (no periodic/interval autosave) | Preserved — the gesture-triggered mirror refresh is not a storage write, only the two GDD-specified triggers commit to `localStorage`. |
| architecture.md | Data Flow §3 (session end/backgrounding), API Boundaries (`save()`/`load()`) | Both updated alongside this ADR — see Related Decisions. |
| ambient-audio.md | Core Rule 7 (persisted `ambient_volume`/`muted`, written via a UI control that never routes through `tap`/`drag_end`) | `refresh_mirror()` companion edit (ADR-0012) — see Key Interfaces above. |

## Performance Implications
- **CPU**: `JavaScriptBridge.eval()` calls are per-gesture-commit (tap, drag_end), not per-frame — negligible against the 16.6ms budget. The save blob is small (Context → Constraints), so `JSON.stringify()`/serialization cost is trivial at this scale.
- **Memory**: One JS-side string mirror plus two `localStorage` keys (`save_current`, `save_last_known_good`), each well under 1KB for the current schema — no measurable impact against the 256MB ceiling.
- **Load Time**: `load()` performs one synchronous `localStorage.getItem()` + JSON parse at session start — sub-millisecond at this data size, not a load-time concern.
- **Network**: N/A — `localStorage` is local, no network I/O.

## Migration Plan
No existing implementation to migrate from — this is the first Persistence/Save implementation. `FS.syncfs()`-based code, if any was written speculatively before this ADR, should be removed rather than kept dormant (dead code inviting future confusion about which path is authoritative).

## Validation Criteria
- Unit-level: `_serialize()`/deserialize round-trip (already specified by `persistence-save.md` AC2a) verified independent of the trigger plumbing.
- Integration-level (Web build required): repeat Gate B's own B1/B2/B3 checks against the *production* implementation (not the throwaway spike) as part of this system's story-level test evidence, on Chrome at minimum — confirms the shipped code behaves like the spike's probes did, since the spike code is explicitly not migrated (`.claude/rules/prototype-code.md`).
- WebKit re-verification remains an explicit open item — see Consequences → Risks. Not a blocking condition for shipping the Chromium-verified design, per the residual-risk framing above.

## Related Decisions
- **Amended by ADR-0006** (Time & Drift): the `HideBridge` handler above now also stamps
  `last_visit_timestamp` into the mirrored blob at hide time, resolving `time-drift.md`'s own
  inherited BLOCKING gate without reintroducing the B1 dependency this ADR was written to avoid.
- Updates `docs/architecture/architecture.md` — Data Flow §3 (session end/backgrounding bullet) and API Boundaries (Persistence/Save's `save()` comment, `load()`'s new `get_restored_blob()`), and the External API row for Persistence/Save (drops the IDBFS/`FS.syncfs()` framing, notes Chromium-verified/WebKit-unverified status instead of blanket "unverified").
- Replaces (not appends to) `design/gdd/persistence-save.md`'s two BLOCKING Open Questions with resolutions pointing here.
- Depends on ADR-0001 (Content Data), ADR-0002 (SessionBootstrap sequencing) — see ADR Dependencies above.
- `docs/architecture/adr-0012-ambient-audio-godot-strategy.md` —
  companion-edits this ADR to add `refresh_mirror()` (2026-08-11).
- Evidence source: `docs/technical-setup/web-export-verification-plan.md` §2 (Gate B), `prototypes/web-export-spike/README.md`.
