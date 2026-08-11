# Test Infrastructure

**Engine**: Godot 4.7.1
**Test Framework**: GUT (Godot Unit Test)
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-08-09

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic)
  integration/    # Cross-system and save/load tests
  smoke/          # Critical path test list for /smoke-check gate
  evidence/       # Screenshot logs and manual test sign-off records
```

## Installing GUT

GUT is a Godot addon, not code checked into this repo — install it once per
local editor setup:

1. Open Godot → AssetLib → search "GUT" → Download & Install (pin to v9.7.1
   or later — the first release with explicit Godot 4.7 compatibility fixes)
2. Enable the plugin: Project → Project Settings → Plugins → Gut ✓
3. Restart the editor
4. Verify: `res://addons/gut/` exists

CI installs GUT fresh on every run instead (see `.github/workflows/tests.yml`)
— there is no `addons/gut/` checked into the repo for either path.

## Running Tests

On a fresh checkout (no `.godot/` import cache yet — e.g. right after
installing GUT, or in CI), import the project once first, or GUT's own
`class_name` declarations won't be registered and `gut_cmdln.gd` fails at
startup with "Some GUT class_names have not been imported":

```
godot --headless --import
```

Then run the suite:

```
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs=true -gprefix= -gsuffix=_test.gd -gexit
```

`-gprefix=`/`-gsuffix=_test.gd` are required: GUT's own default file match
is prefix `test_` + suffix `.gd` (i.e. `test_*.gd`), not the
`[system]_[feature]_test.gd` convention documented above. Without these
flags GUT starts fine but silently matches zero files.

`-ginclude_subdirs=true` is required — `-gdir` alone does not scan
subdirectories, and this file's own directory layout above nests tests by
system (`tests/unit/[system]/`). Same command CI uses (see
`.github/workflows/tests.yml`) — see `.claude/docs/coding-standards.md`'s
CI/CD Rules for the canonical reference.

## Test Naming

- **Files**: `[system]_[feature]_test.gd`
- **Functions**: `test_[scenario]_[expected]`
- **Example**: `ecosystem_moisture_test.gd` → `test_watering_raises_moisture_immediately()`

## Story Type → Test Evidence

| Story Type | Required Evidence | Location |
|---|---|---|
| Logic | Automated unit test — must pass | `tests/unit/[system]/` |
| Integration | Integration test OR playtest doc | `tests/integration/[system]/` |
| Visual/Feel | Screenshot + lead sign-off | `tests/evidence/` |
| UI | Manual walkthrough OR interaction test | `tests/evidence/` |
| Config/Data | Smoke check pass | `production/qa/smoke-*.md` |

## CI

Tests run automatically on every push to `main` and on every pull request.
A failed test suite blocks merging.
