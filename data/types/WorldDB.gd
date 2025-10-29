extends Resource
class_name WorldDB

## Canonical world state database
@export var scenes: Dictionary = {}  # scene_id -> SceneGraph resource path
@export var entities: Dictionary = {}  # entity_id -> Entity data
@export var npc_states: Dictionary = {}  # npc_id -> NPCState resource path
@export var history: Array[Dictionary] = []
@export var flags: Dictionary = {}  # Global world flags

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

