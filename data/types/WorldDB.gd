extends Resource
class_name WorldDB

## Canonical world state database
signal lore_entry_unlocked(entry_id: String)

@export var scenes: Dictionary = {}  # scene_id -> SceneGraph resource path
@export var entities: Dictionary = {}  # entity_id -> Entity data
@export var characters: Dictionary = {}  # character_id -> CharacterProfile resource path
@export var characters_state: Dictionary = {}  # character_id -> { stats: Dictionary, flags: Dictionary }
@export var history: Array[Dictionary] = []
@export var flags: Dictionary = {}  # Global world flags
@export var relationships: Dictionary = {}  # entity_id -> {related_entity_id: relationship_type}
@export var player_inventory: Inventory
@export var party: Array[String] = []  # Current player party member IDs
@export var generated_scenes: Array[String] = []  # IDs of scenes generated at runtime (LLM-assisted)
@export var lore_db: LoreDB
@export var entity_discovery_state: Dictionary = {}  # entity_id -> {discovered_by: Array[String], first_seen_ts: String}
@export var unlocked_lore_entries: Dictionary = {}  # entry_id -> true

var _loaded_scenes: Dictionary = {}
var _loaded_characters: Dictionary = {}
var _world_entity_cache: Dictionary = {}  # entity_id -> Entity (materialized from world.entities)

func get_scene(scene_id: String) -> SceneGraph:
	if _loaded_scenes.has(scene_id):
		return _loaded_scenes[scene_id]
	
	if scenes.has(scene_id):
		var path = scenes[scene_id]
		if path is String:
			var scene = load(path) as SceneGraph
			if scene:
				_loaded_scenes[scene_id] = scene
				return scene
	return null
func get_world_entity_def(entity_id: String) -> Entity:
	if entity_id == "":
		return null
	if _world_entity_cache.has(entity_id):
		return _world_entity_cache[entity_id]
	if not entities.has(entity_id):
		return null
	var src = entities[entity_id]
	var ent: Entity = null
	match typeof(src):
		TYPE_STRING:
			var path := String(src)
			var loaded := load(path)
			if loaded is Entity:
				ent = loaded
		TYPE_DICTIONARY:
			var d: Dictionary = src
			ent = Entity.new()
			ent.id = String(d.get("id", entity_id))
			ent.type_name = String(d.get("type_name", d.get("type", "")))
			# Coerce arrays to typed Array[String]
			var verbs_typed: Array[String] = []
			var verbs_raw = d.get("verbs", [])
			if verbs_raw is Array:
				for v in verbs_raw:
					verbs_typed.append(String(v))
			ent.verbs = verbs_typed
			var tags_typed: Array[String] = []
			var tags_raw = d.get("tags", [])
			if tags_raw is Array:
				for t in tags_raw:
					tags_typed.append(String(t))
			ent.tags = tags_typed
			ent.props = d.get("props", {})
			ent.state = d.get("state", {})
			var contents_typed: Array[String] = []
			var contents_raw = d.get("contents", [])
			if contents_raw is Array:
				for c in contents_raw:
					contents_typed.append(String(c))
			ent.contents = contents_typed
			ent.lore = d.get("lore", {"discovered_by": [], "notes": []})
		TYPE_OBJECT:
			if src is Entity:
				ent = src
	if ent != null:
		_world_entity_cache[entity_id] = ent
	return ent

func materialize_world_entity(entity_id: String) -> Entity:
	var def := get_world_entity_def(entity_id)
	if def == null:
		return null
	return def.duplicate(true)

func clear_entity_cache() -> void:
	_world_entity_cache.clear()


## Register a generated scene and persist mapping
func register_generated_scene(scene_id: String, res_path: String) -> void:
	if scene_id == "" or res_path == "":
		return
	scenes[scene_id] = res_path
	if not (scene_id in generated_scenes):
		generated_scenes.append(scene_id)

## Get character profile (preferred method)
func get_character(character_id: String) -> CharacterProfile:
	if _loaded_characters.has(character_id):
		return _loaded_characters[character_id]
	
	if characters.has(character_id):
		var path = characters[character_id]
		if path is String:
			var character = load(path) as CharacterProfile
			if character:
				_loaded_characters[character_id] = character
				return character
	return null

## Get character stats as dictionary for trigger context
func get_character_state(character_id: String) -> Dictionary:
	# Ensure runtime state exists; initialize from template on first access
	if not characters_state.has(character_id) or not (characters_state[character_id] is Dictionary):
		var character = get_character(character_id)
		var initial_stats: Dictionary = {}
		if character:
			initial_stats = character.stats.duplicate()
		characters_state[character_id] = {
			"stats": initial_stats,
			"flags": {}
		}
	return characters_state[character_id]

func get_character_stats(character_id: String) -> Dictionary:
	var state = get_character_state(character_id)
	if state.has("stats") and state.stats is Dictionary:
		return state.stats.duplicate()
	return {}

func get_character_stat(character_id: String, key: String, default_value = null):
	var stats = get_character_stats(character_id)
	return stats.get(key, default_value)

func set_character_stat(character_id: String, key: String, value) -> void:
	var state = get_character_state(character_id)
	if not state.has("stats") or not (state.stats is Dictionary):
		state["stats"] = {}
	state.stats[key] = value
	# Record in global history
	add_history_entry({
		"event": "character_stat_change",
		"character_id": character_id,
		"key": key,
		"value": value
	})

## Merge scenario overlay into character (for scenario-specific stats/triggers)
func merge_character_overlay(character_id: String, overlay: Dictionary) -> CharacterProfile:
	var base = get_character(character_id)
	if not base:
		return null
	
	# Create a copy (shallow for now)
	var merged = base.duplicate()
	
	# Merge stats
	if overlay.has("stats") and overlay.stats is Dictionary:
		for key in overlay.stats:
			merged.stats[key] = overlay.stats[key]
	
	# Merge triggers (scenario triggers override global with same id)
	if overlay.has("triggers") and overlay.triggers is Array:
		# Remove existing triggers with same id from scenario namespace
		var scenario_namespace = overlay.get("namespace", "scenario.default")
		var existing_ids = {}
		for trigger in merged.triggers:
			if trigger.namespace == scenario_namespace:
				existing_ids[trigger.id] = true
		
		# Add new triggers
		for trigger in overlay.triggers:
			if trigger is TriggerDef:
				if existing_ids.has(trigger.id):
					# Replace existing
					for i in range(merged.triggers.size()):
						if merged.triggers[i].id == trigger.id and merged.triggers[i].namespace == scenario_namespace:
							merged.triggers[i] = trigger
							break
				else:
					merged.triggers.append(trigger)
	
	return merged

func add_history_entry(event: Dictionary):
	event["ts"] = Time.get_datetime_string_from_system()
	history.append(event)
	# Keep last 1000 entries
	if history.size() > 1000:
		history.pop_front()

## Record entity discovery - tracks who discovered what and when
func record_entity_discovery(entity_id: String, actor_id: String, scene_id: String = ""):
	var scene = get_scene(scene_id if scene_id != "" else flags.get("current_scene", ""))
	var already_discovered_by_actor := false
	if scene:
		var entity = scene.get_entity(entity_id)
		if entity:
			# Check if this actor has already discovered the entity (avoid duplicate logs)
			for disc in entity.get_discoveries():
				if disc.get("actor") == actor_id:
					already_discovered_by_actor = true
					break
			if not already_discovered_by_actor:
				entity.record_discovery(actor_id)
	
	# Also update world DB entities cache
	if entities.has(entity_id):
		var entity_data = entities[entity_id]
		if entity_data is Dictionary:
			if not entity_data.has("discovered_by"):
				entity_data["discovered_by"] = []
			if not actor_id in entity_data.discovered_by:
				entity_data.discovered_by.append(actor_id)
			else:
				already_discovered_by_actor = true
	_update_discovery_state(entity_id, actor_id)
	_unlock_lore_for_discovery(entity_id, actor_id)
	
	# Record in global history
	if not already_discovered_by_actor:
		add_history_entry({
			"event": "entity_discovery",
			"entity_id": entity_id,
			"actor": actor_id,
			"scene": scene_id if scene_id != "" else flags.get("current_scene", "")
		})

## Record entity change - tracks property/state/lore modifications
func record_entity_change(entity_id: String, change_type: String, path: String, old_value, new_value, actor_id: String = "system"):
	var scene = get_scene(flags.get("current_scene", ""))
	if scene:
		var entity = scene.get_entity(entity_id)
		if entity:
			entity.record_change(change_type, path, old_value, new_value, actor_id)
	
	# Record in global history
	add_history_entry({
		"event": "entity_change",
		"entity_id": entity_id,
		"change_type": change_type,
		"path": path,
		"actor": actor_id
	})

## Get entity history (discoveries and changes)
func get_entity_history(entity_id: String) -> Array[Dictionary]:
	var scene = get_scene(flags.get("current_scene", ""))
	if scene:
		var entity = scene.get_entity(entity_id)
		if entity:
			return entity.get_history_sorted()
	
	# Fallback: search global history for entity events
	var entity_history: Array[Dictionary] = []
	for entry in history:
		if entry.get("entity_id") == entity_id:
			entity_history.append(entry)
	
	entity_history.sort_custom(func(a, b): return a.get("ts", "") > b.get("ts", ""))
	return entity_history

## Add or update a relationship between two entities
func add_relationship(entity_id: String, related_entity_id: String, relationship_type: String):
	if not relationships.has(entity_id):
		relationships[entity_id] = {}
	
	if relationships[entity_id] is Dictionary:
		relationships[entity_id][related_entity_id] = relationship_type
		
		# Add reverse relationship if bidirectional (owned_by, contains, etc.)
		var bidirectional_types = ["related_to", "allied_with", "enemy_of"]
		if relationship_type in bidirectional_types:
			if not relationships.has(related_entity_id):
				relationships[related_entity_id] = {}
			if relationships[related_entity_id] is Dictionary:
				relationships[related_entity_id][entity_id] = relationship_type

## Get all relationships for an entity
func get_entity_relationships(entity_id: String) -> Dictionary:
	if relationships.has(entity_id):
		return relationships[entity_id].duplicate()
	return {}

## Get entities discovered by a specific actor
func get_entities_discovered_by(actor_id: String) -> Array[String]:
	var discovered: Array[String] = []
	
	# Check scene entities
	var scene = get_scene(flags.get("current_scene", ""))
	if scene:
		for entity in scene.entities:
			var discoveries = entity.get_discoveries()
			for disc in discoveries:
				if disc.get("actor") == actor_id:
					if not entity.id in discovered:
						discovered.append(entity.id)
	
	# Check world DB entities cache
	for entity_id in entities.keys():
		var entity_data = entities[entity_id]
		if entity_data is Dictionary:
			if entity_data.has("discovered_by") and entity_data.discovered_by is Array:
				if actor_id in entity_data.discovered_by:
					if not entity_id in discovered:
						discovered.append(entity_id)
	
	return discovered

## Build entity relationship graph (for visualization)
func build_entity_graph() -> Dictionary:
	var graph = {
		"nodes": [],
		"edges": []
	}
	
	# Collect all entities
	var all_entity_ids = {}
	var scene = get_scene(flags.get("current_scene", ""))
	if scene:
		for entity in scene.entities:
			all_entity_ids[entity.id] = {
				"id": entity.id,
				"type": entity.type_name,
				"tags": entity.tags
			}
	
	# Add nodes
	for entity_id in all_entity_ids.keys():
		graph.nodes.append(all_entity_ids[entity_id])
	
	# Add edges from relationships
	for entity_id in relationships.keys():
		if relationships[entity_id] is Dictionary:
			for related_id in relationships[entity_id].keys():
				graph.edges.append({
					"from": entity_id,
					"to": related_id,
					"type": relationships[entity_id][related_id]
				})
	
	return graph

## Save world state to a file (preserves history and relationships)
func save_to_file(path: String) -> bool:
	var error = ResourceSaver.save(self, path)
	if error != OK:
		push_error("Failed to save world state to " + path + ": " + str(error))
		return false
	print("World state saved to: " + path)
	return true

## Autosave to user data directory with timestamp
func autosave() -> bool:
	var timestamp = Time.get_datetime_string_from_system()
	timestamp = timestamp.replace(":", "-").replace(" ", "_")
	var save_dir = "user://saves"
	var save_path = save_dir + "/world_state_" + timestamp + ".tres"
	
	# Ensure save directory exists
	var dir = DirAccess.open("user://")
	if not dir.dir_exists(save_dir):
		dir.make_dir_recursive(save_dir)
	
	return save_to_file(save_path)

## Load world state from file
static func load_from_file(path: String) -> WorldDB:
	var world_db = load(path) as WorldDB
	if world_db:
		print("World state loaded from: " + path)
	return world_db


## Ensure a canonical player entity exists for inventory/ownership
func ensure_player_entity() -> void:
	if not entities.has("player") or not (entities["player"] is Dictionary):
		entities["player"] = {
			"type": "player",
			"contents": []
		}
		return
	var player = entities["player"]
	if not player.has("type"):
		player["type"] = "player"
	if not player.has("contents"):
		player["contents"] = []

## Ensure a player inventory resource exists (Phase 2)
func ensure_player_inventory() -> void:
	if player_inventory == null:
		player_inventory = Inventory.new()

func ensure_lore_database() -> LoreDB:
	if lore_db == null:
		lore_db = LoreDB.new()
	return lore_db

func get_lore_entry(entry_id: String) -> LoreEntry:
	if lore_db == null:
		return null
	return lore_db.get_entry(entry_id)

func get_lore_entry_for_entity(entity_id: String) -> LoreEntry:
	if lore_db == null:
		return null
	var entry = lore_db.get_entry(entity_id)
	if entry:
		return entry
	# Check current scene entity metadata
	var scene = get_scene(flags.get("current_scene", ""))
	if scene:
		var entity := scene.get_entity(entity_id)
		if entity:
			var lore_id := ""
			if entity.props.has("lore_entry_id"):
				lore_id = str(entity.props.get("lore_entry_id"))
			elif entity.lore.has("entry_id"):
				lore_id = str(entity.lore.get("entry_id"))
			if lore_id != "":
				var from_entity := lore_db.get_entry(lore_id)
				if from_entity:
					return from_entity
	# Fallback: allow entities to define explicit lore_entry_id in data dictionary.
	if entities.has(entity_id):
		var entity_data = entities[entity_id]
		if entity_data is Dictionary and entity_data.has("lore_entry_id"):
			return lore_db.get_entry(str(entity_data.lore_entry_id))
	return null

func has_entity_been_discovered(entity_id: String) -> bool:
	if entity_id == "":
		return false
	if entity_discovery_state.has(entity_id):
		var state = entity_discovery_state[entity_id]
		if state is Dictionary:
			var discovered_list = state.get("discovered_by", [])
			if discovered_list is Array and discovered_list.size() > 0:
				return true
	# Fallback: check scene entities
	var scene = get_scene(flags.get("current_scene", ""))
	if scene:
		var entity = scene.get_entity(entity_id)
		if entity:
			return entity.get_discoveries().size() > 0
	# Check world entities cache flag
	if entities.has(entity_id):
		var entity_data = entities[entity_id]
		if entity_data is Dictionary and entity_data.get("seen", false):
			return true
		if entity_data is Dictionary and entity_data.has("discovered_by"):
			var discovered_list = entity_data.discovered_by
			if discovered_list is Array and discovered_list.size() > 0:
				return true
	return false

func record_lore_unlock(entry_id: String, source: String = "") -> void:
	if entry_id == "":
		return
	if lore_db == null:
		return
	if unlocked_lore_entries.get(entry_id, false):
		return
	var entry = lore_db.get_entry(entry_id)
	if entry == null:
		return
	# Currently unlocks are passive; in future we can record explicit state.
	add_history_entry({
		"event": "lore_unlock",
		"entry_id": entry_id,
		"source": source
	})
	unlocked_lore_entries[entry_id] = true
	lore_entry_unlocked.emit(entry_id)

func _update_discovery_state(entity_id: String, actor_id: String) -> void:
	if entity_id == "":
		return
	var state: Dictionary = entity_discovery_state.get(entity_id, {
		"discovered_by": [],
		"first_seen_ts": Time.get_datetime_string_from_system()
	})
	if not state.has("discovered_by") or not (state.get("discovered_by") is Array):
		state["discovered_by"] = []
	var discovered_by: Array = state.get("discovered_by")
	if not actor_id in discovered_by:
		discovered_by.append(actor_id)
		state["discovered_by"] = discovered_by
	entity_discovery_state[entity_id] = state

func _unlock_lore_for_discovery(entity_id: String, actor_id: String) -> void:
	if lore_db == null:
		return
	var entry = get_lore_entry_for_entity(entity_id)
	if entry and entry.is_unlocked(self, actor_id):
		record_lore_unlock(entry.entry_id, "discovery")
