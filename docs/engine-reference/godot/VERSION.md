# Godot Engine — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | Godot 4.7.1 |
| **Release Date** | July 2026 |
| **Project Pinned** | 2026-08-02 |
| **Last Docs Verified** | 2026-08-02 |
| **LLM Knowledge Cutoff** | May 2025 |
| **Risk Level** | HIGH — version is beyond LLM training data |

## Knowledge Gap Warning

The LLM's training data likely covers Godot up to ~4.3. Versions 4.4 through
4.7 introduced significant changes the model does NOT know about — new
defaults (Jolt Physics, D3D12 on Windows), renamed/removed APIs, and
behavior changes in rendering, physics, and animation. Always cross-reference
`breaking-changes.md` and `deprecated-apis.md` in this directory before
suggesting Godot API calls, and use WebSearch to verify anything uncertain.

**Project-specific note**: This project targets **Web export**, which uses
the **Compatibility** rendering method (OpenGL ES3/WebGL2) — NOT Forward+.
Forward+ requires Vulkan/D3D12/Metal, none of which are available in
browsers. Any suggested rendering feature (SDFGI, some volumetric effects)
must be checked against Compatibility-renderer support, not just against
Godot 4 in general. See `technical-preferences.md` → Engine & Language.

## Post-Cutoff Version Timeline

| Version | Release | Risk Level | Key Theme |
|---------|---------|------------|-----------|
| 4.4 | ~Mid 2025 | MEDIUM | Jolt physics option, FileAccess return types, shader texture type changes, `@export_file` now stores `uid://` |
| 4.5 | ~Late 2025 | HIGH | Accessibility (AccessKit), variadic args, `@abstract`, shader baker, SMAA, TileMapLayer physics chunking on by default |
| 4.6 | Jan 2026 | HIGH | Jolt Physics default, glow rework (brighter), D3D12 default on Windows, IK restored, StringName-typed AnimationPlayer properties |
| 4.7 | July 2026 | HIGH | Mouse/keyboard device ID constants (`DEVICE_ID_MOUSE`/`DEVICE_ID_KEYBOARD`), Jolt SoftBody3D/WorldBoundaryShape3D behavior changes, shader preprocessor restrictions tightened |

See `breaking-changes.md` for the full version-by-version detail and
`deprecated-apis.md` for renamed/removed API lookups.

## Verified Sources

- Official docs: https://docs.godotengine.org/en/stable/
- 4.6→4.7 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html
- 4.5→4.6 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html
- 4.4→4.5 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.5.html
- 4.3→4.4 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.4.html
- Changelog: https://github.com/godotengine/godot/blob/master/CHANGELOG.md
- Release notes: https://github.com/godotengine/godot/releases/tag/4.7.1-stable
