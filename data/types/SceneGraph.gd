extends Resource
class_name SceneGraph

## Authored scene topology
@export var scene_id: String = ""
@export var description: String = ""
@export var image_path: String = ""  # Optional: file/URL for scene image (no base64)
@export var entities: Array[Entity] = []
@export var include_entity_ids: Array[String] = []  # World-level entity IDs to include at runtime
@export var rules: Dictionary = {}  # "on_enter", "combat_allowed", etc.

func get_entity(entity_id: String) -> Entity:
	for entity in entities:
		if entity.id == entity_id:
			return entity
	return null

func get_entities_by_type(type: String) -> Array[Entity]:
	var result: Array[Entity] = []
	for entity in entities:
		if entity.type_name == type:
			result.append(entity)
	return result

