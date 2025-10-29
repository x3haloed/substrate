extends Resource
class_name UIChoice

## Available action choice for the player
@export var verb: String = ""
@export var target: String = ""
@export var label: String = ""

func get_display_label() -> String:
	if label != "":
		return label
	return verb.capitalize() + " " + target

