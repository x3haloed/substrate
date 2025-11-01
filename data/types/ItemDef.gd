extends Resource
class_name ItemDef

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var weight_kg: float = 0.0
@export var max_stack: int = 99
@export var base_value: int = 0
@export var tags: Array[StringName] = []

func is_stackable() -> bool:
    return max_stack > 1


