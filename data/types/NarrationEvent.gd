extends Resource
class_name NarrationEvent

## Single narration message
@export var style: String = "world"  # "world", "npc", "player"
@export var text: String = ""
@export var speaker: String = ""  # Optional entity ID for NPCs

