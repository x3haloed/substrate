extends Resource
class_name CharacterProfile

## Substrate Character Card v1 - Portable character definition
## See substrate_card_v1.md for full specification

# Spec identity
@export var spec: String = "substrate_card_v1"
@export var spec_version: String = "1.0"

# Core fields (required)
@export var name: String = ""
@export var description: String = ""
@export var personality: String = ""
@export var first_mes: String = ""
@export var mes_example: String = ""

# Optional metadata
@export var creator_notes: String = ""
@export var system_prompt: String = "{{original}}"
@export var alternate_greetings: Array[String] = []
@export var tags: Array[String] = []
@export var creator: String = ""
@export var character_version: String = "1.0"

# Character knowledge
@export var character_book: CharacterBook = null

# State and behavior
@export var stats: Dictionary = {}  # Arbitrary key-value trackers (mood, bond_with_player, etc.)
@export var traits: Array[String] = []  # Stable descriptors
@export var style: Dictionary = {}  # Voice, diction, pacing, etc.
@export var triggers: Array[TriggerDef] = []  # Event-driven actions

# Extensibility
@export var extensions: Dictionary = {}  # MUST preserve unknown keys

func _init():
	if extensions.is_empty():
		extensions = {}

## Validate spec version
func is_valid() -> bool:
	return spec == "substrate_card_v1" and spec_version == "1.0"

## Get a stat value, with optional default
func get_stat(key: String, default_value = null):
	return stats.get(key, default_value)

## Set a stat value
func set_stat(key: String, value):
	stats[key] = value

## Check if character has a trait
func has_trait(trait_name: String) -> bool:
	return trait_name in traits

## Get style property
func get_style(key: String, default_value = null):
	return style.get(key, default_value)

## Find triggers matching a namespace and event
func get_triggers_for_event(ns: String, event: String) -> Array[TriggerDef]:
	var result: Array[TriggerDef] = []
	for trigger in triggers:
		if trigger.ns == ns and trigger.when == event:
			result.append(trigger)
	return result

## Get all triggers for a namespace
func get_triggers_for_namespace(ns: String) -> Array[TriggerDef]:
	var result: Array[TriggerDef] = []
	for trigger in triggers:
		if trigger.ns == ns:
			result.append(trigger)
	return result
