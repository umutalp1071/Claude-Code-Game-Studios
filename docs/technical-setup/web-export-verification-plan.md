# Web Export Verification Plan — Terrarium

| Field | Value |
|-------|-------|
| **Status** | Ready to execute — nothing verified yet |
| **Created** | 2026-08-09 |
| **Owner** | technical-director (plan) / godot-specialist + gameplay-programmer (build) / user (run) |
| **Engine** | Godot 4.7.1, Compatibility (OpenGL ES3 / WebGL2), Web export |
| **Spike location** | `prototypes/web-export-spike/` (throwaway, per `.claude/rules/prototype-code.md`) |
| **Est. effort** | ~half day to build all 3 probes, ~half day to run the device matrix |
| **Resolves** | 3 BLOCKING Open Questions (Gates A/B/C below) |

## Why this document exists

The Technical Setup gate check (2026-08-06, verdict CONCERNS) found three separate
BLOCKING Open Questions, each hypothesised in a GDD and each unverifiable from
documentation alone — this project's own pinned engine-reference snapshot
(`docs/engine-reference/godot/`) covers none of them either way. All three need the
same thing: a real Godot Web export, opened in real browsers. So they get one
throwaway spike, not three.

| Gate | GDD | Question in one line |
|------|-----|----------------------|
| **A — Input** | `design/gdd/input-abstraction.md` | Does touch synthesise duplicate mouse events, and does pointer-interruption detection actually work on Web? |
| **B — Persistence** | `design/gdd/persistence-save.md` | Can anything durably commit a save when a tab is hidden or killed? |
| **C — Rendering** | `design/gdd/diorama-rendering.md` | Do `Light2D` + normal maps + glow + `CanvasModulate` behave as designed on Compatibility/WebGL2? |

Gate C has the widest blast radius (it gates ambient lighting, all 4 Discovery
Surfacing cue treatments, and the jar's rim-lighting — i.e. the whole visual
identity), so if time runs short, **run C first**.

**Nothing in this document is a result.** Every table marked `RESULT` is empty and
must be filled in by hand from an actual browser session. Do not let anyone —
human or agent — close a gate from this plan alone.

---

## 0. Pre-flight: project skeleton and export settings

### 0.1 Where the spike lives

```
prototypes/web-export-spike/
├── README.md              # hypothesis, how to run, status, FINDINGS (required by prototype rules)
├── project.godot          # throwaway — NOT the real game project
├── export_presets.cfg
├── probe_log.gd           # autoload: on-screen ring-buffer log + "copy to clipboard"
├── Main.tscn / main.gd    # 3 buttons -> the 3 probe scenes
├── InputProbe.tscn  / input_probe.gd     # Gate A
├── PersistProbe.tscn/ persist_probe.gd   # Gate B
├── RenderProbe.tscn / render_probe.gd    # Gate C
├── art/                   # jar diffuse + normal (Gate C — see 3.1)
└── build/                 # exported web build (gitignore this)
```

**This is throwaway and stays throwaway.** Per `.claude/rules/prototype-code.md`,
production code may never reference `prototypes/`. What carries forward from this
spike is (a) the filled-in result tables in this document, (b) the export settings
that turned out to be correct, and (c) the GDD Open Question resolutions. The
scenes themselves get deleted or archived, and the real `project.godot` is created
fresh in the repo root when Technical Setup proper begins.

**Why not make this the real project**: the real project's structure will be driven
by ADRs that don't exist yet. Standing it up now to host three debug scenes bakes in
decisions before they're made — and the prototype rules would then forbid the real
code from touching it anyway.

### 0.2 The single most consequential setting — verify it three ways

Web export must use **Compatibility**, never Forward+ (Vulkan/D3D12/Metal do not
exist in browsers).

1. **Editor**: Project Settings → Rendering → Renderer → Rendering Method = `Compatibility`.
2. **File**: open `project.godot` as text and confirm all three keys, not just the first —
   the per-platform overrides are what actually ship:
   ```ini
   [rendering]
   renderer/rendering_method="gl_compatibility"
   renderer/rendering_method.mobile="gl_compatibility"
   renderer/rendering_method.web="gl_compatibility"
   ```
3. **Runtime** (the only one that can't lie — Gate C's probe prints this on screen
   inside the actual browser build):
   ```gdscript
   ProbeLog.line("method=%s" % ProjectSettings.get_setting("rendering/renderer/rendering_method"))
   ProbeLog.line("rendering_device=%s" % str(RenderingServer.get_rendering_device()))  # expect <null> under Compatibility
   ProbeLog.line("adapter=%s" % RenderingServer.get_video_adapter_name())
   ```

### 0.3 Other settings to set before building

| Setting | Value | Why |
|---|---|---|
| `input_devices/pointing/emulate_mouse_from_touch` | **false** | Required by Input Abstraction Core Rule 1. Gate A tests whether disabling it is actually sufficient. |
| `input_devices/pointing/emulate_touch_from_mouse` | **false** | Otherwise desktop mouse fakes touch events and poisons Gate A's readings. |
| `display/window/stretch/mode` | `canvas_items` | Gate A's DPI/zoom check depends on this; record whatever you choose, the result only holds for that choice. |
| `display/window/stretch/aspect` | `expand` | Same. |
| `display/window/size/viewport_width` / `height` | jar design resolution | Record the values used. |
| `rendering/viewport/hdr_2d` | **true** for the first Gate C build | Godot docs state this only has an effect on Forward+/Mobile — Gate C C2 tests whether that's still true in 4.7.1 and what it means for glow. |

### 0.4 Export template and preset

- Editor → Manage Export Templates → installed version string must read exactly
  `4.7.1.stable`. A mismatched template silently produces a build that isn't testing
  your engine version.
- Export preset **Web**, Runnable.
- **Thread Support: OFF** for this spike. Threads require cross-origin isolation
  (`Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy:
  require-corp`) *and* a secure context on non-localhost, which turns "test on my
  phone" into a TLS-certificate project. Single-threaded is also the more
  conservative case for Gate B (a hidden tab starves the main loop harder), so it
  tests the worse scenario. Record the preset default before changing it.
- Extensions Support: OFF. Progressive Web App: OFF.
- "Focus Canvas on Start": ON (Gate A's focus behaviour is meaningless if the canvas
  never had focus).
- Export path: `prototypes/web-export-spike/build/index.html`.

### 0.5 Serving it (this is where an hour usually disappears)

- `file://` **does not work** — the WASM module needs real HTTP.
- Easiest desktop path: Godot editor → Remote Debug → Run in Browser (serves with
  the right headers automatically; Editor Settings → Export → Web sets host/port/TLS).
- Manual path: from `build/`, `python -m http.server 8000` → `http://localhost:8000`.
- **Real phone**: same Wi-Fi, browse to `http://<desktop-lan-ip>:8000`. This works
  only because threads are off (no secure-context requirement). If you later need
  threads, use the editor's TLS option or a tunnel (cloudflared/ngrok).
- Mobile browsers make the JS console painful to reach — that's why `probe_log.gd`
  exists. Every probe writes to an on-screen `Label` inside a `ScrollContainer`, with
  a **Copy log** button (`DisplayServer.clipboard_set(text)`) so results can be pasted
  straight into this document.

### 0.6 Device matrix

| Class | Target | Priority |
|---|---|---|
| Desktop Chromium | Chrome or Edge | Required |
| Desktop Firefox | Firefox | Required |
| Desktop WebKit | Safari (macOS) | Required if a Mac exists — highest-risk engine for Gate B |
| Mobile WebKit | iOS/iPadOS Safari | **Required** — worst case for both persistence and touch cancellation |
| Mobile Chromium | Android Chrome | Required |

If hardware is limited, the irreducible minimum is **desktop Chrome + one iOS
Safari device**. Any browser you skip stays an open risk — record it as such in the
results rather than generalising from the ones you did test.

---

## 1. Gate A — Input Abstraction

**GDD**: `design/gdd/input-abstraction.md` → Open Questions (BLOCKING entry) and
Edge Cases (pointer interruption, touch drag past canvas edge).
**Blocks**: Object Placement and Tending Input both consume the `canceled` contract
that Core Rules 1/7/8 produce.

### 1.1 Falsifiable questions

| ID | Question | Current GDD hypothesis |
|---|---|---|
| **A1** | With `emulate_mouse_from_touch = false`, does a single physical touch on Web export still produce *any* `InputEventMouse*` event? | Yes it does — this is the stated reason Core Rule 7's dedup exists. Unverified. |
| **A2** | Does `Window.focus_exited` fire when the browser tab is hidden / the mobile app is backgrounded — and **on which frame is it delivered**? | It fires and no `JavaScriptBridge` workaround is needed. Unverified. |
| **A3** | Does an OS-level touch cancellation with no focus change (pull-to-refresh, edge-swipe back, notification banner) deliver anything to Godot, or does the pointer get stuck down? | Assumed to route through the same Core Rule 8 path. Unverified, and flagged in the GDD as a separate question from A2. |
| **A4** | Does `InputEventScreenDrag` keep delivering once the finger leaves the canvas DOM element? | Unknown — GDD Edge Cases says mouse clamps-and-continues but touch may stall. |
| **A5** *(free rider)* | Do pointer positions and the drag threshold stay stable across browser zoom (50/100/200%) and high-DPI mobile? | Core Rule 4's jar-local conversion is believed to close this. Unverified. |

### 1.2 Scene: `InputProbe.tscn`

One full-rect `Control` (`mouse_filter = STOP`), one `Label` in a `ScrollContainer`,
one `ColorRect` "pointer down?" indicator, one **Copy log** button.

`input_probe.gd` — the whole probe is essentially one `_input` and one `_notification`:

```gdscript
func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton or event is InputEventMouseMotion \
    or event is InputEventScreenTouch or event is InputEventScreenDrag:
        # log: frame, ms, class, device (compare vs InputEvent.DEVICE_ID_MOUSE — 4.7 constant,
        # never literal 0), index (touch only), position, pressed
        ProbeLog.line("%d %d %s dev=%s idx=%s pos=%s pressed=%s" % [...])

func _notification(what: int) -> void:
    # log every one of these, with frame + ms:
    #   NOTIFICATION_APPLICATION_FOCUS_OUT / _IN
    #   NOTIFICATION_WM_WINDOW_FOCUS_OUT / _IN
    #   NOTIFICATION_APPLICATION_PAUSED / _RESUMED   (if delivered on web at all)
```

Also connect `get_window().focus_exited` / `focus_entered` and log them separately —
4.6 introduced a **dual-focus system** (mouse/touch focus is now distinct from
keyboard/gamepad focus, see `docs/engine-reference/godot/breaking-changes.md`), so
"the window lost focus" and "the notification fired" are no longer safely
interchangeable and must be logged as separate lines.

Reuse Gate B's JS-side `visibilitychange` listener here (same build, same scene tree):
it records `performance.now()` into `window.__probe_hide_ts` on every hide. That
timestamp is what makes A2 answerable rather than a yes/no shrug.

Every log line must carry both `Engine.get_frames_drawn()` and
`Time.get_ticks_msec()`. The frame number is the whole point: it distinguishes
"fired while hidden" from "queued and delivered on the frame the tab came back".

### 1.3 Procedure

1. **A1** — 20 taps and 5 slow drags with a finger, on each mobile browser. Then
   repeat on a touchscreen laptop if one exists.
2. **A2** — press and hold (enter DRAGGING), then, still holding: switch tab
   (desktop) / swipe to the app switcher (mobile). Wait 5s. Return.
3. **A3** — start a drag near the top of the page and trigger pull-to-refresh;
   separately, start a drag and edge-swipe back; separately, trigger an incoming
   notification/call if possible. Return to the page **without** backgrounding it
   where the gesture allows.
4. **A4** — start a touch drag inside the canvas and move the finger off the canvas
   element (past the page edge, or onto browser chrome), then lift outside.
5. **A5** — log `get_viewport().get_visible_rect().size`,
   `DisplayServer.window_get_size()`, `get_window().content_scale_factor`, and the
   pointer position while touching a fixed on-screen marker, at 50%/100%/200% zoom
   and on each mobile device.

### 1.4 Pass / fail criteria

| ID | Result → meaning |
|---|---|
| **A1** | **Mouse events present** (any `InputEventMouse*` within ~1 frame of a touch, at ~the same position) → Core Rule 1's hypothesis is confirmed; Core Rule 7's dedup is load-bearing, keep as designed. **Zero mouse events across all 25 gestures on every mobile browser** → the hypothesis is false; Core Rule 1's stated rationale must be rewritten, and Core Rule 7 is retained only for the genuine two-device case (touchscreen laptop), not for same-contact synthesis. Either way this is a real resolution. |
| **A2** | **Fired before hide**: an engine-side focus-out line exists whose `ms` is within 100ms of `__probe_hide_ts` *and* whose frame number is ≤ the last frame rendered while visible → Core Rule 8 works as written. **Delivered on return**: the line exists but its frame equals the first frame after the tab became visible and its `ms` gap ≈ the hidden duration → **the trigger is reachable but late**; see 1.5. **No line at all on some browser** → Core Rule 8's detection mechanism does not exist on that browser and needs a different source (a `JavaScriptBridge` `visibilitychange` hook, or the A3 fallback). |
| **A3** | For each gesture: does a `pressed=false` touch event, a focus-out, or *nothing* arrive? **Nothing** on any browser → a pointer can be left stuck down with no engine-visible cause, and Core Rule 8's "never left stuck" guarantee is unachievable by event alone → the design needs an explicit stale-pointer watchdog (e.g. cancel if no `drag_move`/release for N seconds, or cancel on the next unrelated event). Record which gesture on which browser. |
| **A4** | Drag events continue past the canvas with clamped positions → Edge Cases' clamp-and-continue holds for touch. Events stop → the Edge Case must be rewritten as "touch stalls at the last in-bounds position". Also record whether the release-outside produces a `pressed=false` event at all — if it doesn't, that's another stuck-pointer source feeding A3's watchdog conclusion. |
| **A5** | Pointer position for the fixed marker is identical (±1px) across all zoom levels and devices → thresholds are zoom-independent under the chosen stretch mode. Any deviation > 1px → record the scale factor and the deviation; Core Rule 4's conversion needs a DPI term. |

### 1.5 The distinction that actually matters for A2

If A2 lands on "delivered on return", that is **acceptable for input and fatal for
persistence**. Nothing renders while the tab is hidden, so a drag that cancels on the
first frame after return is indistinguishable to the player from one that cancelled
instantly. The same late delivery applied to a save write means the write never
happens before the tab dies. Do not let a single "focus_exited works!" line in the
log close both Gate A and Gate B — they need different strengths of the same answer.

### 1.6 RESULT — fill in

| ID | Chrome (desktop) | Firefox | Safari (desktop) | iOS Safari | Android Chrome |
|---|---|---|---|---|---|
| A1 | UNTESTED — no touch/mobile device available | UNTESTED | UNTESTED | UNTESTED | UNTESTED |
| A2 | **PASS** — `WM_WINDOW_FOCUS_OUT`, `focus_exited`, and the `HideBridge` gd callback (lag=0.6ms) all logged at frame=2021; `hide_detected` also frame=2021 (gd_now=92013.9, js_ts=92013.3). No frame advanced before delivery — lands on the plan's "fired before hide" branch, not "delivered on return". Return: `WM_WINDOW_FOCUS_IN`/`focus_entered` at frame=2030. | UNTESTED | UNTESTED | UNTESTED | UNTESTED |
| A3 | UNTESTED — no touch/mobile device available | UNTESTED | UNTESTED | UNTESTED | UNTESTED |
| A4 | UNTESTED — no touch/mobile device available | UNTESTED | UNTESTED | UNTESTED | UNTESTED |
| A5 | Partial, not a formal PASS — fixed marker held at (20.0, 20.0) across 3 captures (window ≈1366×632–633, content_scale_factor=1.0); the zoom level for each capture was not reliably recorded, so this is a positive-but-informal observation, not a scored 50/100/200% comparison. | UNTESTED | UNTESTED | UNTESTED | UNTESTED |

---

## 2. Gate B — Persistence / Save

**GDD**: `design/gdd/persistence-save.md` → Open Questions (HTML5/IndexedDB write
reliability; `visibilitychange`/`pagehide` reachability, re-scoped round 12).
**Blocks**: Core Rule 5, AC1a, AC10, AC10a all currently assert a
crash/forced-tab-kill mitigation that may silently not exist.

The round-12 re-scope is respected here: **we are not testing whether
`visibilitychange` fires** (that's well-documented Page Lifecycle behaviour). We are
testing whether a *durable write* can be completed from that event.

### 2.1 Falsifiable questions

| ID | Question |
|---|---|
| **B1** | Does a `JavaScriptBridge.create_callback()` callback into GDScript execute **while the tab is hidden**, or is it deferred until the engine gets another frame (i.e. on tab return)? |
| **B2** | Does data written to `user://` via `FileAccess` survive a **hard tab/browser kill** — with, and without, an explicit `FS.syncfs()`? |
| **B3** | Does `localStorage.setItem()` called from the pure-JS listener survive a hard kill, 5/5 trials, on every browser? |
| **B4** | On iOS Safari specifically: which of `visibilitychange` / `pagehide` fires, and does bfcache restore the page without re-running `_ready()` (`pageshow.persisted === true`)? |

### 2.2 Scene: `PersistProbe.tscn`

On start, read and display three independent counters, each with a wall-clock stamp:

| Slot | Written by | Path |
|---|---|---|
| `probe_js` | pure JS listener, zero engine involvement | `localStorage` |
| `probe_gd` | GDScript, called from the JS listener via the bridge | `localStorage` via `JavaScriptBridge.eval()` |
| `probe_fs` | GDScript, called from the JS listener via the bridge | `user://probe.txt` via `FileAccess` |

Install the listener once in `_ready()`. **Keep the callback in a member variable** —
`create_callback()` references are collected if dropped, and the callback then never
fires (a classic and silent failure):

```gdscript
var _cb: JavaScriptObject          # MUST be held, or the callback never fires
var _window: JavaScriptObject

func _ready() -> void:
    if not OS.has_feature("web"):
        return
    _window = JavaScriptBridge.get_interface("window")
    _cb = JavaScriptBridge.create_callback(_on_hide_from_js)
    JavaScriptBridge.eval("""
        window.__probe_n = (parseInt(localStorage.getItem('probe_js') || '0'));
        window.__probe_hide = function () {
            if (document.visibilityState !== 'hidden') return;
            window.__probe_hide_ts = performance.now();
            localStorage.setItem('probe_js', String(++window.__probe_n));   // control case
            if (window.__probe_gd_cb) window.__probe_gd_cb(window.__probe_hide_ts);
        };
        document.addEventListener('visibilitychange', window.__probe_hide);
        window.addEventListener('pagehide', window.__probe_hide);
    """, true)
    _window.__probe_gd_cb = _cb

func _on_hide_from_js(args: Array) -> void:
    var js_ts: float = args[0]
    var now: float = float(JavaScriptBridge.eval("performance.now()", true))
    ProbeLog.line("gd callback: frame=%d lag=%.1fms" % [Engine.get_frames_drawn(), now - js_ts])
    # write probe_fs (FileAccess) and probe_gd (localStorage via eval), then optionally FS.syncfs
```

Build **two variants** (a checkbox that persists in `localStorage` is fine — one
build, two modes): with and without
`JavaScriptBridge.eval("FS.syncfs(false, function(e){ console.log('syncfs', e); })")`
after the `FileAccess` write. B2 is meaningless unless both are measured.

### 2.3 Procedure — three escalating teardown severities

1. **Soft**: switch tab, wait 5s, return. Read the logged callback lag and frame number.
2. **Medium**: hide the tab, then close it (or navigate away). Reopen the page fresh.
3. **Hard kill**: hide the tab, then kill the browser process (desktop: Task Manager /
   Force Quit; mobile: swipe the app away from the app switcher). Reopen.

Run severity 3 **five times per browser**. A save path that works 4/5 is a broken
save path, not a flaky one.

### 2.4 Pass / fail criteria

| ID | Criterion |
|---|---|
| **B1 PASS** | Callback lag < 100ms **and** `Engine.get_frames_drawn()` at callback time equals the frame count recorded on the last visible frame (no frame advanced). |
| **B1 FAIL** | Lag ≈ the duration the tab was hidden, and/or the frame counter advanced → the callback is deferred to the next main-loop iteration. **Every GDScript-side write path dies with it**, including the GDD's option (b). |
| **B2 PASS** | After hard kill, `probe_fs` reads the pre-kill value **5/5 on every browser tested**. Record the with-syncfs and without-syncfs numbers separately — if without-syncfs is < 5/5 and with-syncfs is 5/5, `FS.syncfs()` is mandatory, which is a hard architectural requirement, not a nicety. |
| **B3 PASS** | `probe_js` reads the pre-kill value 5/5 on every browser. If this fails anywhere, no browser-side hide-triggered write is trustworthy at all and the design must fall back to write-on-mutation. |
| **B4** | Record which event fires first on iOS, and whether a bfcache restore skips `_ready()`. If it does, the real save system needs a `pageshow` re-init path or it will run on stale in-memory state after a restore. |

### 2.5 Decision table — map the outcome onto the options the GDD already drafted

| B1 | B2 (no syncfs) | B3 | → Resolution |
|---|---|---|---|
| PASS | PASS | PASS | Any option works. Take GDD option (b)/(c) — synchronous `localStorage`, since it's the only path where a "saved" confirmation cue is honest rather than optimistic (Core Rule 8). |
| PASS | FAIL | PASS | IDBFS needs `FS.syncfs()` and the sync itself can still be interrupted → option (a) is the fragile path the `creative-director` constraint already says to avoid. Take (b)/(c). |
| **FAIL** | either | PASS | Options (a) and (b) both die — both need GDScript to run during hide. Only **option (c)** survives: mirror the save blob as a JSON string on the JS side (write-through at each commit), and let the pure-JS listener call `localStorage.setItem()` with zero engine involvement. |
| FAIL | either | FAIL | No hide-triggered write is reachable at all → adopt the **write-on-mutation fallback** already pre-drafted by `creative-director`, and add AC11's one-clause amendment. |

Whichever row lands, the GDD Open Question gets replaced by a decision, and
`/architecture-decision` for Persistence & Save is unblocked.

### 2.6 RESULT — fill in

| ID | Chrome (desktop) | Firefox | Safari (desktop) | iOS Safari | Android Chrome |
|---|---|---|---|---|---|
| B1 lag / frame | **PASS** — lag=0.5ms; `focus_exited` and the gd callback both logged frame=10093 (no frame advanced) | UNTESTED | UNTESTED | UNTESTED | UNTESTED |
| B2 no-syncfs (x/5) | 2/3 trials run (not the full 5) — 1 failure observed; incomplete, not a scored x/5 result | UNTESTED | UNTESTED | UNTESTED | UNTESTED |
| B2 with-syncfs (x/5) | **5/5** | UNTESTED | UNTESTED | UNTESTED | UNTESTED |
| B3 (x/5) | Persisted/advanced across hard-kill trials (qualitative — exact x/5 count was not itemized separately from the B2 runs) | UNTESTED | UNTESTED | UNTESTED | UNTESTED |
| B4 | n/a | n/a | UNTESTED | UNTESTED | n/a |

---

## 3. Gate C — Diorama Rendering (run this one first)

**GDD**: `design/gdd/diorama-rendering.md` → Open Question 1 (BLOCKING).
**Blocks**: ambient accent lighting, all 4 Discovery Surfacing cue treatments
(Growth subsurface glow, Arrival specular catch-light, Departure ambient settle,
Detail Event point-light bloom), and the glass jar's normal-map + `Light2D`
rim-lighting — i.e. the entire Diorama Realism visual anchor.

### 3.1 The one art dependency

The GDD explicitly requires validating "against the actual jar normal-map setup
specifically (the highest-value, most load-bearing asset)". So this test needs **one
real jar diffuse + its normal map** from `art-director`/`technical-artist` — not
placeholder art.

If that asset doesn't exist yet, run with a placeholder (any sprite + a
hand-authored normal map) to get C2/C3/C4 answered, and mark **C1 as provisional —
must be re-run against the real jar asset before the Open Question closes.** Don't
let a placeholder pass count as the jar pass.

### 3.2 Falsifiable questions

| ID | Question | Why it's in doubt |
|---|---|---|
| **C1** | Do `Light2D` instances light a `CanvasTexture` normal map per-pixel on Compatibility/WebGL2, on desktop **and** mobile GPUs? | 2D lighting is expected to work under Compatibility, but nothing in the pinned engine reference confirms it for 4.7.1 WebGL2, and mobile GL drivers are the usual place this breaks. |
| **C2** | Does `WorldEnvironment` glow do anything at all in 2D under Compatibility? | Godot's docs state `rendering/viewport/hdr_2d` "only has an effect when using the Forward+ or Mobile rendering methods", and the Compatibility renderer is described as SDR-only in 2D — while community reports claim 2D glow working in 4.4 web builds with HDR 2D on. Genuinely contradictory; only a test settles it. **Detail Event's "point-light bloom" cue depends on the answer.** |
| **C3** | Does `CanvasModulate`'s multiply tint apply to the *composited* result (sprite + light contribution), or only to the unlit sprite? | Core Rule 8 / the day-night AC assume the tint makes it "one lit place" — that only holds if lights are tinted too. |
| **C4** | Worst case — **8 concurrent `Light2D`** (1–3 ambient + up to 5 cue-driven) + 1 active object tween + a mid-cycle day/night transition — within 16.6ms and ≤500 draw calls on a mid-range phone? | The GDD explicitly struck its previous "stays far under the ceiling" claim as unsupported. This number is currently unknown. |

### 3.3 Scene: `RenderProbe.tscn`

- Jar sprite as a `Sprite2D` with a `CanvasTexture` (`diffuse_texture` = jar art,
  `normal_texture` = jar normal map). One or two supporting sprites (a "wet leaf")
  with the same treatment.
- One fixed-direction "sun" `PointLight2D` matching the baked upper-left key light,
  with a **manual angle-override slider** used only for C1 (sweep it 360° to prove
  the normal map responds — the shipping design keeps direction fixed).
- A `+`/`-` pair spawning 0–5 short-lived cue `PointLight2D`s.
- `CanvasModulate` with a `t` slider (0→1) sampling the GDD's `DAY_NIGHT_GRADIENT`
  stops, plus a "force strong blue" button for the C3 check.
- `WorldEnvironment` with glow enabled, and a glow on/off toggle.
- HUD overlay, updated every frame:
  ```gdscript
  Engine.get_frames_per_second()
  Performance.get_monitor(Performance.TIME_PROCESS)
  Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
  Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
  ```
  plus the three runtime renderer lines from §0.2 (this is where the
  "am I actually on Compatibility?" proof gets printed).

Glow's `hdr_2d` dependency is a project setting, not runtime-toggleable — export
**two builds** (`hdr_2d` on / off) and compare. If they're pixel-identical, that's
itself the C2 answer.

### 3.4 Procedure

Take a screenshot of each state, on each browser/device, and keep them next to the
result table:

1. Light sweep 0→360° with glow off, `t = 0.5`.
2. Glow on vs off, at both `hdr_2d` settings, with one bright cue light at full energy.
3. `CanvasModulate` strong blue, with the sun light at full energy over the jar.
4. Ramp cue lights 0→5 with the ambient lights on (total 8), start an object tween,
   and drag the `t` slider across a gradient stop simultaneously. Hold for 30s and
   record the *worst* frame time, not the average.
5. Repeat 1–4 in the editor's own Compatibility preview on desktop. Editor-vs-browser
   divergence localises a bug to WebGL2 rather than to Compatibility generally.

### 3.5 Pass / fail criteria

| ID | Criterion |
|---|---|
| **C1 PASS** | Sweeping the light visibly moves the highlight across the normal-mapped surface, consistently, on desktop **and** mobile. Also record whether the normal-map Y orientation matches the editor (a green-channel flip between GL backends is a known class of bug — if it differs, that's an art-pipeline requirement, not a blocker). |
| **C1 FAIL** | No shading response, or response on desktop but not mobile → normal-mapped `Light2D` rim-lighting is not available for the jar. The GDD's "highest-value asset" treatment must move fully to baked/painted specular. This is a design escalation, not a fix. |
| **C2 (i) full** | Glow visibly blooms and responds to light energy → Detail Event's point-light bloom cue works as designed. |
| **C2 (ii) clamped** | Glow renders but only from values already at/near white (SDR clamp), and `hdr_2d` on/off makes no difference → bloom must be authored as a painted additive halo sprite instead of engine glow. **`diorama-rendering.md` and `discovery-surfacing.md` both need a cue-treatment revision.** |
| **C2 (iii) absent** | No visual difference at all with glow on → drop the `WorldEnvironment` entirely; same design consequence as (ii). |
| **C3 PASS** | Forcing `CanvasModulate` to strong blue also tints the lit/rim areas → the tint composites over lighting, Core Rule 8 holds. |
| **C3 FAIL** | Lit areas stay untinted → day/night tint and the lighting layer are visually separate, and Core Rule 8's "one lit place" claim plus the related AC need rewriting. |
| **C4 PASS** | Worst frame time ≤ 16.6ms and draw calls ≤ 500 on the mid-range mobile reference device under the full 8-light worst case. |
| **C4 (regardless)** | Record the **per-light cost delta** (frame time at 0 lights vs 8, measured on mobile). That number, not a pass/fail, is what any future budget conversation about the 5-concurrent-cue cap needs. |

### 3.6 RESULT — fill in

| ID | Editor (Compat) | Chrome (desktop) | Firefox | Safari (desktop) | iOS Safari | Android Chrome |
|---|---|---|---|---|---|---|
| C1 | UNTESTED | **PASS, provisional** — sun-angle sweep visibly moved the shading highlight across the placeholder dome normal map. Provisional per §3.1: placeholder art, not the real jar asset — must re-run before this closes. | UNTESTED | UNTESTED | UNTESTED | UNTESTED |
| C2 (hdr_2d on) | UNTESTED | Glow present — bright cue light produced a clearly visible bright region + surrounding bloom; low-energy state showed little/no visible effect. | UNTESTED | UNTESTED | UNTESTED | UNTESTED |
| C2 (hdr_2d off) | UNTESTED | Glow present — same result as `hdr_2d` ON: clearly visible bright region + surrounding bloom under otherwise identical `RenderProbe` conditions. **No visually noticeable difference between the ON and OFF builds.** | UNTESTED | UNTESTED | UNTESTED | UNTESTED |
| C3 | UNTESTED | **PASS** — forcing strong blue `CanvasModulate` visibly tinted the composited/lit result, not just the unlit sprite | UNTESTED | UNTESTED | UNTESTED | UNTESTED |
| C4 ms / draw calls | UNTESTED | Qualitative only — no ms/draw-call numbers were captured. Ramping cue lights 1→5 (with ambient lights) produced no noticeable visual/performance degradation or stuttering during manual observation. | UNTESTED | UNTESTED | UNTESTED | UNTESTED |
| C4 per-light delta | UNTESTED | Not captured — no numeric HUD values recorded | UNTESTED | UNTESTED | UNTESTED | UNTESTED |

**C2 note (desktop Chrome only)**: glow *exists* under Compatibility/WebGL2 — it is
not absent (rules out §3.5 outcome (iii)). But toggling `hdr_2d` produced no visible
difference between the two builds, so this is **not** a full HDR-bloom PASS (§3.5
outcome (i), "responds to light energy" in an HDR-dependent way) — that would need
the ON/OFF builds to actually differ. The observed pattern (glow renders, on/off
makes no difference) matches the plan's own §3.5 outcome (ii) "clamped" description
on Chrome, but that is a single-browser observation, not a confirmed cross-browser
verdict, and no energy sweep was run to separately confirm the SDR-clamp mechanism
behind it — treat as directional, not conclusive. If it holds on other browsers,
§3.5 (ii) says this is a design consequence (painted-halo bloom instead of engine
glow) for `diorama-rendering.md` / `discovery-surfacing.md`, to be routed to
`creative-director`/`art-director`, not decided here.

**Reference device used for C4**: not recorded — desktop Chrome only, no numeric measurement and no mobile reference device tested yet.

---

## 4. When the spike concludes

1. Fill in every `RESULT` table above, in this file. Attach the Gate C screenshots
   alongside (`docs/technical-setup/evidence/`) and paste the copied probe logs.
2. Write findings into `prototypes/web-export-spike/README.md` (required by
   `.claude/rules/prototype-code.md`) and add a row to `prototypes/index.md`.
3. Replace — do not append to — each of the three GDD Open Questions with a
   resolution stating what was observed, on which browsers, and what the design now
   does. "Verified on Chrome, untested on Safari" is a valid resolution; "probably
   fine" is not.
4. If any gate produces a design consequence (C2 (ii)/(iii), C1 FAIL, C3 FAIL, B1
   FAIL, A1 refuted), route it to `creative-director` / `art-director` as a design
   decision. This plan resolves facts, not designs.
5. Unblock the downstream `/architecture-decision` runs: Input Abstraction (Gate A),
   Persistence & Save (Gate B), Diorama Rendering (Gate C).
6. Delete or archive the spike. It never becomes production code.

## 5. Known contradictions this plan is designed to expose

Flagged for `creative-director` / `art-director` — **not** silently corrected here.

- **Glow on Compatibility (Gate C2)** — official Godot documentation states
  `rendering/viewport/hdr_2d` only affects Forward+/Mobile, and describes the
  Compatibility renderer as SDR-only in 2D. `diorama-rendering.md` specifies Detail
  Event's cue as a "point-light bloom" and asks the verification pass to "fold in
  Godot 4.6's Glow/HDR compositing-order change". If 2D glow is unavailable under
  Compatibility, that 4.6 change is *irrelevant to this project entirely*, and one of
  the four Discovery cue treatments needs re-authoring.
- **"Immediately" in Input Abstraction Core Rule 8 / AC10** — browsers stop
  `requestAnimationFrame` for hidden tabs, so the engine may get no frame at all
  while hidden. If Gate A2 lands on "delivered on return", the strongest achievable
  guarantee is "on the first frame after the tab becomes visible again", not
  "immediately". Harmless for the player (nothing renders while hidden) but the
  wording is currently making a promise the platform can't keep.
- **Persistence options (a) and (b) are not independent** —
  `persistence-save.md` lists them as alternative mitigations, but both require
  GDScript to execute during the hide event. Gate B1 kills them together. Only
  option (c) (JS-side mirrored blob, pure-JS write) is genuinely independent of the
  main loop; the round-12 note gets this right for (c) but the (b) framing invites
  the wrong conclusion.
- **4.6 dual-focus system vs Core Rule 8's detection** —
  `docs/engine-reference/godot/breaking-changes.md` records that mouse/touch focus is
  now separate from keyboard/gamepad focus. "The window lost focus" is therefore no
  longer a single unambiguous event, which is why Gate A logs the window signals and
  the notifications on separate lines rather than treating them as one signal.
