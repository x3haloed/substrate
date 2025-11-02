extends Resource
class_name ResolutionEnvelope

## Director → UI resolution envelope
@export var narration: Array[NarrationEvent] = []
@export var patches: Array[Dictionary] = []  # JSON Patch operations
@export var ui_choices: Array[UIChoice] = []
@export var commands: Array[Dictionary] = []  # Engine-handled operations (e.g., transfer)
@export var scene_image_path: String = ""  # Optional resolved path/URL to display before narration

