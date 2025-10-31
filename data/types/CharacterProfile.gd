@tool
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
@export var portrait_base64: String = ""

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

# --- Portrait helpers & editor integration ---

var _portrait_texture_cache: Texture2D = null

func _encode_texture_to_base64(texture: Texture2D) -> String:
	if texture == null:
		return ""
	var img: Image = texture.get_image()
	if img == null:
		return ""
	# Always store as PNG for deterministic round-trips
	var bytes: PackedByteArray = img.save_png_to_buffer()
	return Marshalls.raw_to_base64(bytes)

func _decode_base64_to_texture() -> Texture2D:
	if portrait_base64 == "":
		return null
	if _portrait_texture_cache != null:
		return _portrait_texture_cache
	var bytes: PackedByteArray = Marshalls.base64_to_raw(portrait_base64)
	var img := Image.new()
	var err := img.load_png_from_buffer(bytes)
	if err != OK:
		return null
	_portrait_texture_cache = ImageTexture.create_from_image(img)
	return _portrait_texture_cache

func get_portrait_texture() -> Texture2D:
	return _decode_base64_to_texture()

func set_portrait_texture(texture: Texture2D) -> void:
	portrait_base64 = _encode_texture_to_base64(texture)
	_portrait_texture_cache = texture
	emit_changed()

func clear_portrait() -> void:
	portrait_base64 = ""
	_portrait_texture_cache = null
	emit_changed()

func _get_property_list() -> Array:
	var props: Array = []
	# Editor-only proxy to view/set the portrait as a Texture2D without persisting it
	props.append({
		"name": "portrait_image",
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "Texture2D",
		"usage": PROPERTY_USAGE_EDITOR
	})
	return props

func _get(p_name):
	if String(p_name) == "portrait_image":
		return _decode_base64_to_texture()
	return null

func _set(p_name, value) -> bool:
	if String(p_name) == "portrait_image":
		if value == null:
			clear_portrait()
			return true
		if value is Texture2D:
			set_portrait_texture(value)
			return true
		return false
	return false
