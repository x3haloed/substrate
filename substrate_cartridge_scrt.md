## Substrate Cartridge (.scrt) — ZIP-backed World Package

### Purpose
- Bundle a complete playable world (scenes, characters, flags, relationships, optional runtime state) into a single portable file that can be shared and mounted at runtime.
- Support macOS Quick Look thumbnails and file association without custom binary parsers.

### Container
- File extension: `.scrt` (Substrate Cartridge)
- Format: Standard ZIP archive
- Mounting in Godot: treated as a resource pack via `ProjectSettings.load_resource_pack` (ZIP packs are supported alongside PCK).

### High-level Contents
```
<package-id>.scrt
├─ manifest.json
├─ world.json
├─ scenes/
│  ├─ <scene_id>.tres        # SceneGraph resources
│  └─ ...
├─ characters/
│  ├─ <character_id>.tres    # CharacterProfile resources
│  └─ ...
└─ previews/
   ├─ thumbnail_1024.png     # optional
   ├─ thumbnail_512.png      # recommended (Quick Look default)
   └─ thumbnail_256.png      # optional
```

### `manifest.json` (Schema)
- Required keys:
  - `id`: string — package id (slug; recommended unique)
  - `name`: string — human readable title
  - `version`: string — semantic version (e.g., "1.0.0")
  - `spec_version`: string — cartridge spec version (e.g., "1.0")
  - `engine_version`: string — Godot version string (e.g., "4.3")
  - `initial_scene_id`: string — scene to enter on start
  - `contents`: object
    - `scenes`: string[] — list of scene ids included
    - `characters`: string[] — list of character ids included
- Optional keys:
  - `integrity`: object — sha256 hashes by path inside the archive
  - `description`: string — package description
  - `author`: string

Example:
```json
{
  "id": "starter_tavern",
  "name": "Starter Tavern",
  "version": "1.0.0",
  "spec_version": "1.0",
  "engine_version": "4.3",
  "initial_scene_id": "tavern_common",
  "contents": {
    "scenes": ["tavern_common", "tavern_back_room", "cobblestone_alley"],
    "characters": ["barkeep", "fool", "archer", "elaria"]
  },
  "integrity": {
    "scenes/tavern_common.tres": "<sha256>",
    "characters/elaria.tres": "<sha256>"
  }
}
```

### `world.json` (Schema)
- Optional runtime/bootstrap state separate from static resources.
- Keys:
  - `flags`: object — global flags (e.g., `{ "current_scene": "tavern_common" }`)
  - `relationships`: object — map of entity relationships
  - `characters_state`: object — optional per-character runtime stats snapshot

Example:
```json
{
  "flags": {
    "current_scene": "tavern_common"
  },
  "relationships": {
    "player": { "elaria": "friendly" }
  },
  "characters_state": {
    "elaria": { "stats": { "mood": "calm", "bond_with_player": 3 }, "flags": {} }
  }
}
```

### Resource Files
- `scenes/*.tres` must be `SceneGraph` resources, self-contained.
- `characters/*.tres` must be `CharacterProfile` resources.
- Embedded portrait and thumbnails inside `CharacterProfile` are preserved.

### Thumbnails for macOS Quick Look
- Store precomputed PNGs in `previews/` within the archive:
  - Prefer `thumbnail_512.png` (Finder commonly requests medium sizes quickly).
  - Optionally include `thumbnail_1024.png` and `thumbnail_256.png`.
- A Swift Quick Look extension can open the ZIP, read `previews/thumbnail_*.png`, and render without parsing `.tres`.
- Fallback: Swift can parse `.tres` text to extract `thumbnail_*_base64` or `portrait_base64` if previews are omitted (see `macos-file-association-and-thumbnail-plan.md`).

### Export Pipeline (WorldExporter)
1) Gather references
   - Read `WorldDB.scenes` and `WorldDB.characters` to enumerate ids and source paths.
2) Validate
   - Ensure each referenced `.tres` loads; collect errors.
3) Stage
   - Copy `.tres` files into a temp dir under `scenes/` and `characters/` filenames by id.
   - Generate `manifest.json` and `world.json` (runtime snapshots optional).
   - Optionally write `previews/thumbnail_*.png` from portraits or custom cover art.
4) Integrity (optional)
   - Compute sha256 for staged files; add to `manifest.json.integrity`.
5) Pack
   - Zip the staging dir; set extension to `.scrt`.

### Import Pipeline (WorldImporter)
1) Unpack
   - Extract `.scrt` ZIP into a sandboxed path (e.g., `res://worlds/<id>/`).
2) Validate
   - Read `manifest.json`; check `spec_version` and (warn on) `engine_version` mismatch.
   - Verify hashes in `integrity` if present.
3) Build `WorldDB`
   - Construct a `WorldDB` instance:
     - `scenes = { id: "res://worlds/<id>/scenes/<id>.tres" }`
     - `characters = { id: "res://worlds/<id>/characters/<id>.tres" }`
     - `flags`, `relationships` from `world.json`.
     - Do not preload; lazy-load via existing `WorldDB` methods.
4) Persist (optional)
   - Save assembled `WorldDB` to `res://worlds/<id>/world_state.tres` for fast reloads.
5) UID maintenance (Godot ≥4.4)
   - Optionally resave imported resources to update UIDs; use project helper if needed.

### Runtime Integration
- Selection
  - If the user selects a cartridge, import it and switch the running session to the constructed `WorldDB`.
- Mounting (alternative)
  - Instead of extracting, call `ProjectSettings.load_resource_pack(<path_to>.scrt, true)`, then `load("res://characters/elaria.tres")` etc., if the archive paths mirror project paths. For clean isolation, extraction to a namespaced folder is recommended.

### Versioning
- `spec_version`: governs this `.scrt` structure; start at `1.0`.
- `engine_version`: informational; warn if major.minor differs.

### Security & Sandboxing
- Treat `.scrt` as data-only. Do not execute scripts from cartridges unless explicitly allowed by your game design and sandbox policy.
- Prefer extraction into an app-controlled directory.

### Acceptance Criteria
- Export default world to `.scrt`, import it in a clean session, and start at `initial_scene_id` without errors.
- NPC dialog uses the imported `CharacterProfile` data (traits/style/book).
- macOS Quick Look shows thumbnails from `previews/thumbnail_*.png`.

### Future Enhancements
- Subset exports (select scenes/characters)
- Delta/state-only cartridges
- Optional compression level control
- Optional signature block for authenticated cartridges

### Minimal Godot Snippets
Mounting a ZIP-backed cartridge directly:
```gdscript
var ok = ProjectSettings.load_resource_pack("/path/to/world.scrt")
if ok:
    var scene: Resource = load("res://scenes/tavern_common.tres")
```

Importing via extraction (recommended isolation):
```gdscript
# 1) unzip to res://worlds/<id>/ (use FileAccess + helper or OS.execute("unzip"))
# 2) construct WorldDB with paths under res://worlds/<id> and pass to Game
```


