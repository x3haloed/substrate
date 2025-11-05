# Lore System Implementation Plan

## Vision
- Give campaign authors a scene-agnostic, encyclopedic space for entity lore with discovery gating.
- Let runtime systems (Director, generators, triggers) register new entities and lore without hand-editing resources.
- Ensure the Lore Panel can always resolve a rich article for any known entity, regardless of current scene or origin.

## Current Gaps
- Lore data lives on per-scene `Entity` resources and the lightweight `world_db.entities` map; neither stores long-form articles or visibility rules.
- The Lore Panel only queries the active scene; global entities or those generated at runtime drop on the floor.
- Discovery state is limited to ad-hoc fields like `seen`; there is no consistent lock/unlock model for lore text.
- Character biographies (`CharacterProfile`) are rich but disconnected from the Lore Panel and discovery flow.
- Director patches modify only the in-scene entity instance and do not persist lore updates to a canonical index.

## Proposed Architecture

### Lore Resources
- **LoreEntry.gd** (new Resource, `class_name LoreEntry`)
  - `@export var entry_id: String`
  - `@export var title: String`
  - `@export var category: String` (npc, item, location, faction, misc)
  - `@export var summary: String`
  - `@export var article: String` (BBCode-capable long-form text)
  - `@export var related_entity_ids: Array[String]`
  - `@export var default_visibility: String = "locked"` (`always`, `discovered`, `hidden`)
  - `@export var unlock_conditions: Array[String]` (simple tokens such as `discover:entity_id`, `flag:quest_complete`)
  - `@export var tags: Array[String]`
  - `@export var notes: Array[String]` (internal author notes or change log)
  - `func is_unlocked(world_db: WorldDB) -> bool` uses discovery + world flags to evaluate availability.
- **LoreDB.gd** (new Resource, `class_name LoreDB`)
  - `@export var entries: Dictionary` mapping entry_id → `LoreEntry` resource path.
  - Runtime cache similar to `WorldDB.get_scene` for fast access.
  - APIs: `get_entry(entry_id)`, `register_entry(entry: LoreEntry)`, `ensure_entry_for_entity(entity_id, defaults: Dictionary)`, `unlock_entry(entry_id, context)`.

### World Integration
- Extend `WorldDB`:
  - `@export var lore_db: LoreDB`
  - Index discovery history: `@export var entity_discovery_state: Dictionary` (entity_id → { discovered_by: [], first_seen_ts }).
  - Helper methods to bridge scenes/entities and lore: `get_lore_entry_for_entity(entity_id)`, `record_lore_unlock(entry_id, source)`.
  - Ensure autosave/serialization includes `lore_db` and discovery state.
- Modify Director patches:
  - When applying lore-related JSON patches (`/entities/<id>/lore/...`), ensure `LoreDB.ensure_entry_for_entity` is called so runtime discoveries stay persistent.
  - When generating new entities (e.g., OpenAreaGenerator), create a stub `LoreEntry` with default text and category inferred from props.
  - When `record_entity_discovery` runs, call `LoreDB` to unlock entries whose `default_visibility` is `discovered`.

### UI & Gameplay
- **LorePanel**:
  - Load `LoreEntry` objects instead of scene entities.
  - Show `summary` and `article` with tabs (Overview, Timeline, Relationships, Notes).
  - Respect `is_unlocked`; display lock message & hint if locked.
  - Provide search/filter by category/tags if entry count grows.
- **ChatWindow entity clicks**:
  - For NPC portraits or character chat, ensure mapping from entity id → lore entry id (fallback to world_db mapping).
- **Discovery Flow**:
  - Expand `record_entity_discovery` to mark entities discovered globally and emit a signal (`lore_entry_unlocked(entry_id)`).
  - Hook UI to show a toast when new lore unlocks.

### Authoring Workflow
- Update Campaign Studio:
  - Add Lore tab to create/manage `LoreEntry` resources.
  - Allow linking entities → lore entries via dropdown.
  - Display visibility rules and quick preview.
- Provide template `res://data/lore/` folder with sample entries.
- Add validation tool (CLI or editor plugin) to ensure every referenced entity has a lore entry or explicit opt-out.

### Data Migration
- Script to scan existing scenes and `world_state.tres` to create stub `LoreEntry` resources per entity.
- Merge character bios (`CharacterProfile.description`) into corresponding lore entries.
- Default visibility to `discovered` for interactive NPCs/items, `always` for world concepts already exposed.

## Implementation Phases

### Phase 1 – Resource Foundations
1. Implement `LoreEntry.gd` and `LoreDB.gd`.
2. Extend `WorldDB` to reference `LoreDB`, add discovery tracking, and expose helper APIs.
3. Provide stub lore entries for existing sample entities (minimal text to verify wiring).
4. Update autosave/load to persist `LoreDB` references.

### Phase 2 – UI & Game Loop Integration
1. Refactor `LorePanel` to query `WorldDB.get_lore_entry_for_entity`.
2. Update display logic to render `LoreEntry` fields and lock messaging.
3. Emit unlock notifications when discovery occurs.
4. Ensure chat entity clicks and other UI paths resolve through the new APIs.

### Phase 3 – Runtime Entity Support
1. Modify Director patch handling to register/update lore entries when `/lore` paths change.
2. Ensure generated entities create or update lore entries with inferred defaults.
3. Add regression tests (GUT or unit-like) validating unlock flow and persistent storage.

### Phase 4 – Authoring Tooling
1. Expand Campaign Studio UI to manage lore entries, link them to entities, and edit visibility rules.
2. Build migration tool (Godot Editor script or CLI) to create initial lore entries from existing data.
3. Document author workflow (README section + video/gif for UI changes).

### Phase 5 – Polish & Extensions
1. Add search/filter options in Lore Panel (optional but desirable for large campaigns).
2. Support cross-references between lore entries (e.g., `[link:lore_id]` markup).
3. Introduce analytics hooks (optional) for tracking which lore players read.
4. Prepare localization-friendly structure (split article text into translatable resources).
5. Integrate Character Card v2 `character_book` / World Info concepts:
   - Treat lore entries as prompt-ready capsules with activation keywords and insertion order metadata so they can back the CCv2 lorebook on import.
   - Provide export/import helpers to map between `LoreEntry` fields and `character_book`/World Info entries (keys, content, order, insertion position).
   - Extend PromptEngine to read activated lore entries (from global or character-specific pools) and inject them alongside existing prompts using configurable strategies (global-first, character-first).

## Acceptance Criteria
- Lore Panel shows authored article text for any entity, irrespective of scene, once unlocked.
- Entries respect visibility rules and only unlock when corresponding discovery/flags fire.
- Director-generated entities create persistent lore entries that survive scene transitions and save/load.
- Authors can create/edit lore entries without hand-editing JSON dictionaries.
- Migration script produces valid stubs for all existing entities with no missing references warnings.

## Open Questions
- Do we need per-player vs global discovery in multiplayer? (Assume single-player for now.)
- Should lore entries support multiple articles/sections (e.g., timeline vs bio) or rely on BBCode and panel tabs?
- How should conflicting runtime edits be resolved when multiple systems update the same entry?
- Confirm whether prompt activation keywords and insertion priorities should live on `LoreEntry` or companion structures to keep CCv2 compatibility clean.
