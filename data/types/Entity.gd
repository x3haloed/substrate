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

func _init(p_id: String = "", p_type_name: String = "", p_verbs: Array[String] = []):
	id = p_id
	type_name = p_type_name
	verbs = p_verbs

