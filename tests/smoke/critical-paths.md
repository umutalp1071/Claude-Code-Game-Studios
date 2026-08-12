# Smoke Test: Critical Paths

**Purpose**: Run these checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (which reads this file)
**Update**: Add new entries when new core systems are implemented.

## Core Stability (always run)

1. Game launches to the jar scene without crash
2. A tap/click over the open jar triggers watering (`jar_moisture` visibly rises)
3. Drag-repositioning the rock responds to both mouse and touch input

## Core Mechanic (update per sprint)

<!-- Add the primary mechanic for each sprint here as it is implemented -->
<!-- Example: "Time & Drift's catch-up batch correctly resolves offline growth on session start" -->
4. [Primary mechanic — update when first core system is implemented]

## Data Integrity

5. Save game completes without error (once Persistence/Save is implemented)
6. Load game restores correct `jar_moisture`/`growth_stage`/creature state (once implemented)

## Performance

7. No visible frame rate drops on target hardware (60fps target, Compatibility/WebGL2 renderer)
8. No memory growth over 5 minutes of play (once core loop is implemented)
