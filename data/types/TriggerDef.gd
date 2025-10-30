extends Resource
class_name TriggerDef

## Event-driven action trigger for characters
## Defines when and how a character should act

@export var id: String = ""  # Unique within character
@export var ns: String = "global"  # "global" or "scenario.<id>"
@export var when: String = ""  # Event selector (e.g., "scene.enter", "player.command.cover_me")
@export var conditions: Array[Dictionary] = []  # Array of {left, op, right} predicates
@export var action: Dictionary = {}  # {verb: String, target: String, params?: Dictionary}
@export var narration: String = ""  # Optional narration override
@export var priority: int = 0  # Higher = earlier (typical range 0-100)
@export var cooldown: float = 0.0  # Turns or seconds

func _init():
	if conditions.is_empty():
		conditions = []
	if action.is_empty():
		action = {}

## Get action verb
func get_verb() -> String:
	return action.get("verb", "")

## Get action target
func get_target() -> String:
	return action.get("target", "")

## Get action params
func get_params() -> Dictionary:
	return action.get("params", {})

## Check if trigger matches an event
func matches_event(event: String) -> bool:
	return when == event

## Check if trigger is in namespace
func is_in_namespace(ns_prefix: String) -> bool:
	return ns == ns_prefix or ns.begins_with(ns_prefix + ".")

## Validate trigger structure
func is_valid() -> bool:
	return id != "" and when != "" and action.has("verb") and action.has("target")
