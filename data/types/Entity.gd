extends Resource
class_name Entity

## Canonical entity record in the world DB
@export var id: String = ""
@export var type_name: String = ""  # "npc", "item", "exit", etc.
@export var verbs: Array[String] = []
@export var tags: Array[String] = []
@export var props: Dictionary = {}
@export var state: Dictionary = {}
@export var contents: Array[String] = []  # IDs of contained entities
@export var lore: Dictionary = {"discovered_by": [], "notes": []}
@export var history: Array[Dictionary] = []  # Per-entity history: who discovered, when, changes

func _init(p_id: String = "", p_type_name: String = "", p_verbs: Array[String] = []):
	id = p_id
	type_name = p_type_name
	verbs = p_verbs

## Record a discovery event for this entity
func record_discovery(actor_id: String, timestamp: String = ""):
	if timestamp == "":
		timestamp = Time.get_datetime_string_from_system()
	
	# Check if already discovered by this actor
	var already_discovered = false
	for entry in history:
		if entry.get("type") == "discovery" and entry.get("actor") == actor_id:
			already_discovered = true
			break
	
	if not already_discovered:
		var discovery_entry = {
			"type": "discovery",
			"actor": actor_id,
			"timestamp": timestamp
		}
		history.append(discovery_entry)
		
		# Update lore discovered_by list
		if not lore.has("discovered_by"):
			lore["discovered_by"] = []
		if not actor_id in lore.discovered_by:
			lore.discovered_by.append(actor_id)

## Record a change event (property, state, or lore modification)
func record_change(change_type: String, path: String, old_value, new_value, actor_id: String = "system", timestamp: String = ""):
	if timestamp == "":
		timestamp = Time.get_datetime_string_from_system()
	
	var change_entry = {
		"type": "change",
		"change_type": change_type,  # "prop", "state", "lore"
		"path": path,
		"old_value": old_value,
		"new_value": new_value,
		"actor": actor_id,
		"timestamp": timestamp
	}
	history.append(change_entry)
	
	# Keep history limited to last 100 entries per entity
	if history.size() > 100:
		history.pop_front()

## Get all discovery events for this entity
func get_discoveries() -> Array[Dictionary]:
	var discoveries: Array[Dictionary] = []
	for entry in history:
		if entry.get("type") == "discovery":
			discoveries.append(entry)
	return discoveries

## Get all changes for this entity
func get_changes() -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	for entry in history:
		if entry.get("type") == "change":
			changes.append(entry)
	return changes

## Get history entries sorted by timestamp (most recent first)
func get_history_sorted() -> Array[Dictionary]:
	var sorted = history.duplicate()
	sorted.sort_custom(func(a, b): return a.get("timestamp", "") > b.get("timestamp", ""))
	return sorted

