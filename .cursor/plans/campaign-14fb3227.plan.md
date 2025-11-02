<!-- 14fb3227-1747-4e89-8f9f-aa31ee7cd306 7a7182ab-11fc-4eaf-a798-119f61716577 -->
# Campaign Cartridge + Open Areas + Player & Writer UX

## Scope

Implement a complete campaign experience: portable `.scrt` cartridges; Campaign Browser and Detail views with per‑cartridge save slots; mid‑session switching; LLM‑assisted open areas that generate revisitable scenes; and a full Campaign Studio for writers. All integrates with `WorldDB`, `Director`, and existing UI.

## Key Decisions

- Open areas are LLM‑assisted: on entry, synthesize a concrete `SceneGraph`, persist it, and register it so it becomes canonical and revisitable.
- Link graph includes `scene` and `open_area` node types; edges represent exits/links.
- Save system is per‑cartridge with named slots; no New Game+.

## Data Model & Files

- `data/types/Cartridge.gd` (Resource): manifest metadata (`id`, `name`, `version`, `spec_version`, `engine_version`, `initial_scene_id`, `description`, `author`, `scenes[]`, `characters[]`, `links_path`, `thumbnails{}`).
- `tools/CartridgeManager.gd` (autoload): discover `.scrt`, parse `manifest.json`→`Cartridge`, import/extract to `res://worlds/<id>/`, build `WorldDB`, handle mid‑session switching.
- `data/types/LinkGraph.gd` (Resource): `nodes: Array[GraphNode]`, `edges: Array[GraphEdge]`.
  - `GraphNode = { id: String, type: "scene"|"open_area", ref_id: String }`
  - `GraphEdge = { from: String, to: String, label: String }`
- `data/types/OpenAreaDef.gd` (Resource): `area_id`, `title`, `design_brief`, `constraints{}`, `completion{ target_scene_id, condition{} }`.
- `.scrt` additions: optional `links/graph.tres`, `open_areas/<area_id>.tres`; `manifest.json` optional `links_path`, `open_areas[]`.

## Engine Integration

- `llm/OpenAreaGenerator.gd`: use `PromptEngine` to generate a `SceneGraph` from `OpenAreaDef` + world context; save under `user://campaigns/<cartridge_id>/generated/<gen_id>.tres`; register in `WorldDB.scenes` as `oa.<area_id>.<hash>`.
- `llm/Director.gd`:
  - Detect entering open areas via link graph or `portal` entity (`props.kind == "open_area"`, `props.area_id`).
  - On entry: call `OpenAreaGenerator` then `enter_scene(generated_scene_id)`.
  - Monitor completion condition (e.g., discovery/interaction with specific entity) and transition to `completion.target_scene_id` when satisfied.
- `WorldDB.gd`: helpers to register/persist generated scenes; include generated scenes and link graph path in saves.

## Player UX

- Campaign Browser (`ui/CampaignBrowser.tscn/.gd`): grid with `thumbnail_512.png`, title, author, version; filter/search.
- Campaign Detail (`ui/CampaignDetail.tscn/.gd`): metadata, cover, description; per‑cartridge save slots (New, Load, Delete, Rename); Import/Update.
- Header: “Play Cartridge”, “Manage Worlds”, “Save/Load”.
- Travel polish: “Travel” dropdown listing exits by label; dispatches `move` to selected exit entity.
- Mid‑session switching: auto‑save current slot, load target cartridge → either New Game or selected slot.

## Writer UX (Campaign Studio)

- Entry
  - Header button “Campaign Studio” alongside `CardEditor`/`CardManager`.
  - Opens scoped to active cartridge (or prompts to select). 
- Dashboard
  - Edit cartridge metadata; overview counts; warnings feed; quick actions: Validate, Playtest from scene, Export `.scrt`.
- Scenes Workspace
  - Scene list with search/filter; create/duplicate/delete scenes.
  - Scene editor bound to `SceneGraph`: edit `scene_id`, `description`, `rules`, and entity list with inspector.
  - Exit Wizard: create `exit` entity (`verbs += ["move"]`, `props.leads`, optional `props.label`).
  - Open Area Wizard: create `portal` entity (`props.kind = "open_area"`, `props.area_id`, optional `props.label`).
  - Entity templates (npc, item, exit, portal) and verb presets.
- Graph View
  - Visualizes `LinkGraph`: Scene nodes vs OpenArea nodes; edges = exits.
  - Click node to open editor; click edge to jump to the source exit entity; auto‑layout; unreachable/broken links highlighted.
- Characters Workspace
  - List from `WorldDB.characters`; open in `CardEditor`; quick links to `CharacterBook` entries.
- Playtest Harness
  - Start from specific scene or open area; modes: Full LLM / Deterministic / Offline; Dev HUD shows scene, last triggers, key flags; reset world.
- Packaging Panel
  - Subset export (select scenes/characters/open areas), include `world.json`, thumbnails, integrity hashes; import tester to validate a produced `.scrt`.
- Validation Panel
  - Checks: duplicate ids, broken `props.leads`, missing characters, unreachable scenes from `initial_scene_id`, oversized base64; click‑through fixes.

## Save/Load

- Slots at `user://saves/<cartridge_id>/<slot>.tres` with sidecar `slot.json` (scene id, timestamp, playtime, party summary).
- UI: save menu (Create, Overwrite, Rename, Delete); load menu scoped to current cartridge.

## Essential Snippets

- Cartridge resource skeleton:
```gdscript
extends Resource
class_name Cartridge

@export var id := ""
@export var name := ""
@export var version := "1.0.0"
@export var spec_version := "1.0"
@export var engine_version := ProjectSettings.get_setting("application/config/version", "4.5")
@export var initial_scene_id := ""
@export var description := ""
@export var author := ""
@export var scenes: Array[String] = []
@export var characters: Array[String] = []
@export var links_path := ""
@export var thumbnails := {}
```

- Open area portal entity:
```gdscript
id = "mysterious_portal"
type_name = "portal"
verbs = ["enter", "examine"]
props = { "kind": "open_area", "area_id": "forest_depths", "label": "Enter the shimmering portal" }
```

- Link graph node (concept):
```gdscript
{ "id": "oa_forest_depths", "type": "open_area", "ref_id": "forest_depths" }
```


## Risks & Mitigations

- LLM variability → deterministic seeding and persistence; validate generated scenes (ids unique, verbs valid) before registration.
- ZIP portability → prefer `ZIPReader` for manifest reads; extract to temp if needed.
- UID churn on import → resave resources to refresh UIDs on 4.4+ when required.

### To-dos

- [ ] Add `data/types/Cartridge.gd` resource for manifest metadata
- [ ] Create `tools/CartridgeManager.gd` autoload for discover/import/load/switch
- [ ] Build `ui/CampaignBrowser.tscn/.gd` listing library with thumbnails
- [ ] Build `ui/CampaignDetail.tscn/.gd` with per-cartridge save slot manager
- [ ] Implement `tools/WorldExporter.gd` to stage and zip `.scrt`
- [ ] Implement `tools/WorldImporter.gd` to unpack/validate/build WorldDB
- [ ] Add `data/types/LinkGraph.gd` and render Graph View in Studio
- [ ] Add `data/types/OpenAreaDef.gd` for LLM-assisted areas
- [ ] Create `llm/OpenAreaGenerator.gd` to synthesize SceneGraph and persist
- [ ] Update `Director.gd` to handle portals/open areas and completion return
- [ ] Extend `WorldDB.gd` to register and serialize generated scenes
- [ ] Add Travel dropdown UI integrating with existing choices
- [ ] Add Save/Load menus with slots under `user://saves/<cartridge_id>/`
- [ ] Create `ui/CampaignStudio.tscn/.gd` shell with tabs/workspaces
- [ ] Implement validation: broken exits, missing chars, unreachable scenes
- [ ] Parse manifest.json into Cartridge via `ZIPReader` with fallback extract
- [ ] Implement mid-session cartridge switching with auto-save of previous