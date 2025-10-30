extends Resource
class_name WorldDB

## Canonical world state database
@export var scenes: Dictionary = {}  # scene_id -> SceneGraph resource path
@export var entities: Dictionary = {}  # entity_id -> Entity data
@export var npc_states: Dictionary = {}  # npc_id -> NPCState resource path
@export var history: Array[Dictionary] = []
@export var flags: Dictionary = {}  # Global world flags
@export var relationships: Dictionary = {}  # entity_id -> {related_entity_id: relationship_type}

var _loaded_scenes: Dictionary = {}
var _loaded_npc_states: Dictionary = {}

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

func get_npc_state(npc_id: String) -> NPCState:
	if _loaded_npc_states.has(npc_id):
		return _loaded_npc_states[npc_id]
	
	if npc_states.has(npc_id):
		var path = npc_states[npc_id]
		if path is String:
			var state = load(path) as NPCState
			if state:
				_loaded_npc_states[npc_id] = state
				return state
	return null

func add_history_entry(event: Dictionary):
	event["ts"] = Time.get_datetime_string_from_system()
	history.append(event)
	# Keep last 1000 entries
	if history.size() > 1000:
		history.pop_front()

## Record entity discovery - tracks who discovered what and when
func record_entity_discovery(entity_id: String, actor_id: String, scene_id: String = ""):
	var scene = get_scene(scene_id if scene_id != "" else flags.get("current_scene", ""))
	if scene:
		var entity = scene.get_entity(entity_id)
		if entity:
			entity.record_discovery(actor_id)
	
	# Also update world DB entities cache
	if entities.has(entity_id):
		var entity_data = entities[entity_id]
		if entity_data is Dictionary:
			if not entity_data.has("discovered_by"):
				entity_data["discovered_by"] = []
			if not actor_id in entity_data.discovered_by:
				entity_data.discovered_by.append(actor_id)
	
	# Record in global history
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

