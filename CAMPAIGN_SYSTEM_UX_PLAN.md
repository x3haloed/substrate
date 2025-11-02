## Substrate Campaign System — UX and System Plan

### Goals
- **Portable campaigns**: Ship authored worlds as a single `.scrt` file.
- **Authoring flow**: Provide a Campaign Studio to draft, link, validate, playtest, and export.
- **Runtime flow**: Support linked scenes, travel affordances, save/load for long campaigns, and campaign switching.
- **Explorable hubs**: Allow the Director to create scenes at runtime within open-ended areas, with clear objectives that return the player to writer-defined scenes.

### Scope at a Glance
- **Cartridge format**: `.scrt` v1.0 ZIP with `manifest.json`, `world.json`, `scenes/*.tres`, `characters/*.tres`, optional `previews/*`, optional link graph (`links.json`).
- **Authoring UX**: Campaign Studio UI (scenes editor with Exit Wizard, link-graph view with open-area nodes, validation, playtest harness, packaging panel).
- **Player UX**: Campaign Browser, Campaign Detail (saves), in-session Travel, Save/Load, and mid-session Campaign Switching with state preservation.
- **Engine**: Import/Export world, linked-scene navigation, Director integration for open-area nodes, and cartridge management.

---

## Cartridge Format (.scrt)

### Structure
```
<id>.scrt
├─ manifest.json
├─ world.json                 # optional runtime snapshot
├─ scenes/                    # SceneGraph resources
│  └─ <scene_id>.tres
├─ characters/                # CharacterProfile resources
│  └─ <character_id>.tres
├─ links.json                 # optional link graph (see below)
└─ previews/
   ├─ thumbnail_512.png       # recommended
   ├─ thumbnail_256.png       # optional
   └─ thumbnail_1024.png      # optional
```

### manifest.json (unchanged core)
- Required: `id`, `name`, `version`, `spec_version`, `engine_version`, `initial_scene_id`, `contents.{scenes[],characters[]}`
- Optional: `description`, `author`, `integrity{ path->sha256 }`, `links_path` (path to `links.json` inside the archive)

### world.json (optional)
- Optional runtime bootstrap state: `{ flags, relationships, characters_state }`

### links.json (optional, recommended)
Defines a writer-curated travel graph. Supports writer scenes and open-ended areas.

```json
{
  "nodes": [
    { "id": "tavern_common", "type": "scene", "scene_id": "tavern_common" },
    { "id": "back_room", "type": "scene", "scene_id": "tavern_back_room" },
    {
      "id": "alley_open",
      "type": "open_area",
      "label": "Alleyways",
      "entry_template": { "scene": "cobblestone_alley" },
      "objective": {
        "kind": "discover_entity",
        "entity_id": "hidden_door"  
      },
      "on_complete": { "goto_scene_id": "sewer_entry" }
    },
    { "id": "sewer_entry", "type": "scene", "scene_id": "sewer_entry" }
  ],
  "edges": [
    { "from": "tavern_common", "to": "back_room", "via": "door_back", "label": "Back room" },
    { "from": "tavern_common", "to": "alley_open", "via": "front_door", "label": "Alley" },
    { "from": "alley_open", "to": "sewer_entry", "label": "Hidden door" }
  ]
}
```

Notes:
- `type: scene`: points to a concrete `SceneGraph` by `scene_id`.
- `type: open_area`: declares an explorative hub where the Director may create runtime scenes; completion returns the player into a writer-defined scene via `on_complete.goto_scene_id`.
- `objective` kinds to support initially:
  - `discover_entity`: player first discovers an entity id (tracked via `WorldDB.record_entity_discovery`).
  - `interact_entity`: specific verb executed on an entity.
  - `flag_equals`: world flag reaches a value (e.g., puzzle solved).

---

## Writer Experience — Campaign Studio

### Campaign Dashboard
- Metadata: `id`, `name`, `version`, `author`, `description`, `initial_scene_id`.
- Content summary: counts of scenes/characters; warnings (orphans, broken links, duplicates, missing refs).
- Actions: Validate, Playtest from scene/node, Export `.scrt`.

### Scenes Workspace
- Scene list with filters/tags.
- Scene editor: edit `SceneGraph` (`scene_id`, `description`, `rules`, entities CRUD).
- Exit Wizard:
  - Creates `type_name = "exit"`, adds `verbs += ["move"]`, sets `props.leads = "<scene_id>"`, optional `props.label`.
  - Optionally writes/updates an `edges` entry in `links.json`.

### Link Graph View
- Nodes: `scene` and `open_area`; edges derived from exits and `links.json`.
- Interactions:
  - Click node to open the scene editor (or open-area editor for objectives and entry template).
  - Click edge to edit underlying exit or link metadata.
  - Validation overlays: missing `scene_id`, broken `props.leads`, unreachable nodes, duplicate ids.

### Open-Area Editor
- Configure `label`, `entry_template` (starter scene or template), and `objective`:
  - Objective pickers: discover/interact/flag.
  - Completion target: `goto_scene_id`.
  - Optional: hint text to present in Travel UI.

### Playtest Harness
- Start from selected scene or graph node.
- Modes: Full LLM, Deterministic (no LLM variance), Offline stubs.
- Dev HUD: current scene/node, recent triggers, flags, token counts (if enabled).

### Packaging Panel
- Export options: full set or subset (select scenes/characters).
- Include/exclude `world.json` snapshot; include thumbnails; compute integrity hashes.
- Emits `links.json` and adds `links_path` to `manifest.json` when present.

---

## Player Experience

### Campaign Browser
- Scans `user://cartridges` for `.scrt`. Shows cards with thumbnails, title, author, version.
- Selecting a campaign opens the detail view.

### Campaign Detail View
- Shows metadata and description.
- Save management for that campaign id: list slots with scene and timestamp.
- Actions: New Game, Load Slot, Delete Slot.

### In-Session Travel
- Travel dropdown populated from current scene `exit` entities (`props.label` fallback to `leads`/id).
- Selecting a destination emits a standard `move` action on the chosen exit entity.

### Save/Load
- Panel with slot list and a text field for new slot name.
- Writes sidecar JSON with `scene` and `timestamp` for labeling.

### Mid-Session Campaign Switching
- Auto-save current session to a `last_played` slot.
- Import selected `.scrt`, build a new `WorldDB`, optionally load a slot, then enter `current_scene` or `initial_scene_id`.
- Rebind UI and systems without restarting the app.

---

## Engine Integration

### Cartridge Model and Management
- `Cartridge` Resource mirrors `manifest.json` and resolves contents, `links_path`, and thumbnails.
- `CartridgeManager` Autoload:
  - Discovers `.scrt` files in a library directory.
  - Reads `manifest.json` via `ZIPReader` to build `Cartridge` metadata.
  - Imports a cartridge into `res://worlds/<id>/` and constructs a `WorldDB` mapping.
  - Loads optional `world.json` and applies state to `WorldDB`.
  - Exposes `library_updated` and `cartridge_imported` signals.

### World Import/Export
- Exporter stages `.tres`, emits `manifest.json`, optional `world.json`, and optional `links.json`, then zips to `.scrt`.
- Importer extracts `.scrt`, validates manifest and integrity, assembles a `WorldDB`, persists to `res://worlds/<id>/world_state.tres` (optional).

### Linked Scenes Runtime
- `Director` already supports `move` on `exit` with `props.leads` to transition.
- `ChoicePanel` populates Travel options from exit entities.
- Narrator prompt context can include an `exits` summary to increase clarity for the model.

### Open-Area Nodes (Director-Created Scenes)

Runtime semantics when entering a `type: open_area` node:
1. Director sets `world_db.flags.current_graph_node = <node_id>` and `flags.current_scene` to an entry scene (from `entry_template.scene` or last open-area subscene).
2. While in the open-area node, Director may create or modify scenes at runtime:
   - Generate ephemeral `SceneGraph` instances or load template scenes and decorate with dynamic entities.
   - Ensure runtime-created scenes are not exported unless promoted by the author.
3. Objective evaluation loop:
   - `discover_entity`: satisfied when `WorldDB.record_entity_discovery(entity_id, actor, scene)` logs the first discovery by the player; 
   - `interact_entity`: satisfied when `process_player_action` resolves with matching `verb`+`target`.
   - `flag_equals`: satisfied when `WorldDB.flags[key] == value`.
4. On objective completion: Director transitions to the writer-defined scene: `enter_scene(on_complete.goto_scene_id)` and updates `current_graph_node` accordingly.

Suggested API additions:
```gdscript
# Director.gd (conceptual)
func enter_graph_node(node_id: String) -> ResolutionEnvelope
func is_in_open_area() -> bool
func try_complete_open_area_objective(event: Dictionary) -> bool
```

Data persistence:
- Track `current_graph_node` and any open-area local flags in `world.json` to resume mid-area.

---

## Validation
- Broken exit targets (`props.leads` not found in `WorldDB.scenes`).
- Duplicate `scene_id` or entity ids within a scene.
- Characters referenced by NPC entities exist in `WorldDB.characters`.
- Link graph:
  - Nodes reference real scenes or valid `open_area` configs.
  - All writer scenes reachable from `initial_scene_id`.

---

## Acceptance Criteria
- Export baseline world to `.scrt` and import it; start at `initial_scene_id` without errors.
- Campaign Browser shows library with thumbnails; Detail View lists save slots with scene labels.
- Travel dropdown lists exits and triggers `move` transitions cleanly.
- Save/Load panel writes/reads slots; sidecar JSON displays scene and timestamp.
- Mid-session Campaign Switching preserves current session to `last_played` and loads the new campaign, rebinding UI/state without restart.
- Open-area node: entering the node allows exploration through director-created or decorated scenes; on objective completion, the player is returned to the target writer scene.

---

## Milestones

### M1 — Packaging and Library
- Finalize `.scrt` exporter/importer and integrity checks.
- Cartridge discovery and metadata rendering in Campaign Browser.

### M2 — Player UX
- Campaign Detail save management.
- Travel dropdown and narration exits context.
- Save/Load panel polish.
- Mid-session campaign switching (auto-save + rebind + load).

### M3 — Authoring UX
- Campaign Studio shell with Scenes Workspace + Exit Wizard.
- Link Graph View rendering from scenes + `links.json`.
- Open-Area Editor (objectives, entry template, on-complete target).
- Validation pass with navigable errors.

### M4 — Director + Open Areas
- Director entry/exit flows for `open_area` nodes.
- Objective detection (`discover_entity`, `interact_entity`, `flag_equals`).
- Persistence of `current_graph_node` and open-area local flags.

---

## Notes on Data Hygiene and Security
- Keep `.tres` resources authoritative; prefer resources over ad-hoc dictionaries.
- Avoid storing large base64 portrait data in PRs; use `previews/` thumbnails for cards and Quick Look.
- Treat cartridges as data-only; do not execute scripts from `.scrt` without explicit sandbox policy.
