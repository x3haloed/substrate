extends Resource
class_name OpenAreaDef

@export var area_id: String = ""
@export var title: String = ""
@export var design_brief: String = "" # High-level prompt to guide generation
@export var constraints: Dictionary = {} # e.g., required entities, themes, difficulty, tags

# Completion gate back to authored graph
# Example: { "target_scene_id": "tavern_back_room", "condition": { "discover_entity": "ancient_key" } }
@export var completion: Dictionary = {}

func is_valid() -> bool:
    return area_id != "" and completion.has("target_scene_id")


