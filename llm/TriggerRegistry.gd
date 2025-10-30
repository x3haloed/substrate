extends RefCounted
class_name TriggerRegistry

## Global registry for trigger events, verb schemas, and condition evaluation
## Handles event dispatching, condition evaluation, and cooldown tracking

# Cooldown tracking: trigger_id -> last_used_turn
var cooldowns: Dictionary = {}
var current_turn: int = 0

# Verb schema: verb -> {min_params: Array[String], max_params: Array[String]}
var verb_schemas: Dictionary = {}

# Known global events
var global_events: Array[String] = [
	"scene.enter",
	"scene.exit",
	"tick.turn",
	"player.action",
	"player.command.cover_me",
	"entity.discovered",
	"entity.changed"
]

func _init():
	# Register default verb schemas
	_register_default_verbs()

## Register a verb schema
func register_verb(verb: String, min_params: Array[String] = [], max_params: Array[String] = []):
	verb_schemas[verb] = {
		"min_params": min_params,
		"max_params": max_params
	}

## Register default verbs
func _register_default_verbs():
	register_verb("talk", ["target"], ["target", "topic"])
	register_verb("cover", ["target"], ["target"])
	register_verb("blunder", ["target"], ["target"])
	register_verb("move", ["target"], ["target"])
	register_verb("examine", ["target"], ["target"])
	register_verb("take", ["target"], ["target"])
	register_verb("buy_drink", ["target"], ["target"])

## Validate action against verb schema
func validate_action(action: Dictionary) -> bool:
	if not action.has("verb") or not action.has("target"):
		return false
	
	var verb = action.get("verb", "")
	if not verb_schemas.has(verb):
		# Unknown verb - allow but warn
		push_warning("Unknown verb: " + verb)
		return true
	
	var schema = verb_schemas[verb]
	var params = action.get("params", {})
	
	# Check required params
	for min_param in schema.get("min_params", []):
		if not params.has(min_param) and not action.has(min_param):
			push_warning("Missing required param for verb " + verb + ": " + min_param)
			return false
	
	return true

## Evaluate condition triplet against context
func evaluate_condition(condition: Dictionary, context: Dictionary) -> bool:
	if not condition.has("left") or not condition.has("op"):
		return false
	
	var left_path = condition.get("left", "")
	var op = condition.get("op", "")
	var right_value = condition.get("right", null)
	
	# Resolve left value from context using dotted path
	var left_value = _resolve_path(left_path, context)
	
	match op:
		"==":
			return left_value == right_value
		"!=":
			return left_value != right_value
		">":
			return _compare_numeric(left_value, right_value, 1)
		">=":
			return _compare_numeric(left_value, right_value, 1) or left_value == right_value
		"<":
			return _compare_numeric(left_value, right_value, -1)
		"<=":
			return _compare_numeric(left_value, right_value, -1) or left_value == right_value
		"includes":
			if left_value is Array:
				return right_value in left_value
			elif left_value is String:
				return left_value.contains(str(right_value))
			return false
		"not_in":
			if left_value is Array:
				return not (right_value in left_value)
			elif left_value is String:
				return not left_value.contains(str(right_value))
			return false
		"exists":
			return left_value != null
		"true":
			return left_value == true
		"false":
			return left_value == false
		_:
			push_warning("Unknown condition operator: " + op)
			return false

## Resolve dotted path from context (e.g., "stats.mood" or "world.flags.danger")
func _resolve_path(path: String, context: Dictionary):
	var parts = path.split(".")
	var current = context
	
	for i in range(parts.size()):
		var part = parts[i]
		
		# Handle special includes syntax: "scene.tags.includes.bandit"
		if part == "includes" and i > 0 and current is Array:
			if i + 1 < parts.size():
				var search_value = parts[i + 1]
				return search_value in current
			return false
		
		if current is Dictionary:
			if not current.has(part):
				return null
			current = current[part]
		elif current is Array:
			var idx = part.to_int()
			if idx < 0 or idx >= current.size():
				return null
			current = current[idx]
		else:
			return null
	
	return current

## Compare numeric values
func _compare_numeric(left, right, direction: int) -> bool:
	if not (left is int or left is float) or not (right is int or right is float):
		return false
	
	if direction > 0:
		return left > right
	else:
		return left < right

## Evaluate all conditions for a trigger
func evaluate_conditions(trigger, context: Dictionary) -> bool:
	if trigger.conditions.is_empty():
		return true
	
	for condition in trigger.conditions:
		if not evaluate_condition(condition, context):
			return false
	
	return true

## Check if trigger is on cooldown
func is_on_cooldown(trigger) -> bool:
	if trigger.cooldown <= 0.0:
		return false
	
	var key = trigger.id
	if not cooldowns.has(key):
		return false
	
	var last_used = cooldowns[key]
	return (current_turn - last_used) < trigger.cooldown

## Record trigger usage
func record_trigger_used(trigger):
	if trigger.cooldown > 0.0:
		cooldowns[trigger.id] = current_turn

## Advance turn counter
func advance_turn():
	current_turn += 1

## Get matching triggers for an event
func get_matching_triggers(character, event: String, ns: String, context: Dictionary) -> Array:
	var candidates: Array = []
	
	# Collect triggers matching event and namespace
	for trigger in character.triggers:
		if trigger.matches_event(event) and trigger.is_in_namespace(ns):
			# Check conditions
			if evaluate_conditions(trigger, context):
				# Check cooldown
				if not is_on_cooldown(trigger):
					candidates.append(trigger)
	
	# Sort by priority (higher first)
	candidates.sort_custom(func(a, b): return a.priority > b.priority)
	
	return candidates

## Check if event is global
func is_global_event(event: String) -> bool:
	return event in global_events or event.begins_with("player.command.")

## Register a global event
func register_global_event(event: String):
	if not event in global_events:
		global_events.append(event)

