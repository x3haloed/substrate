extends RefCounted
class_name CompanionAI

## Character trigger evaluation and initiative calculation
## Uses CharacterProfile and TriggerRegistry instead of legacy NPCState

var world_db: WorldDB
var trigger_registry: TriggerRegistry

func _init(p_world_db: WorldDB, p_trigger_registry: TriggerRegistry):
	world_db = p_world_db
	trigger_registry = p_trigger_registry

## Check if character should act based on triggers for an event
## Returns best matching trigger or null
func should_act(character_id: String, event: String, ns: String, context: Dictionary) -> TriggerDef:
	var character = world_db.get_character(character_id)
	if not character:
		return null
	
	# Build full context with character stats
	var full_context = context.duplicate()
	full_context["stats"] = world_db.get_character_stats(character_id)
	full_context["character"] = {
		"id": character_id,
		"name": character.name,
		"traits": character.traits,
		"style": character.style
	}
	
	# Get matching triggers
	var triggers = trigger_registry.get_matching_triggers(character, event, ns, full_context)
	if triggers.is_empty():
		return null
	
	# Return highest priority trigger (already sorted by registry)
	return triggers[0]

## Get character initiative for action queue ordering
## Reads stats.initiative or derives from mood/bond if not present
func get_initiative(character_id: String) -> int:
	var character = world_db.get_character(character_id)
	if not character:
		return 50  # Default middle priority
	
	# Check for explicit initiative stat
	if character.stats.has("initiative"):
		var explicit_initiative = character.stats.initiative
		if explicit_initiative is int or explicit_initiative is float:
			return int(clamp(explicit_initiative, 0, 100))
	
	# Derive from mood and bond_with_player
	var mood = character.get_stat("mood", "neutral")
	var bond = character.get_stat("bond_with_player", 0.5)
	
	var base_priority = 50  # Middle of 0-100 range
	
	# Mood modifiers
	var mood_modifier = 0
	match mood:
		"cheerful", "alert", "determined":
			mood_modifier = 20
		"content", "neutral":
			mood_modifier = 0
		"depressed", "tired", "frightened":
			mood_modifier = -20
		"angry", "hostile":
			mood_modifier = 15  # Higher initiative when hostile
	
	# Bond modifier (stronger bond = slightly higher initiative for helping)
	var bond_modifier = int((bond - 0.5) * 10)
	
	var initiative = base_priority + mood_modifier + bond_modifier
	return clamp(initiative, 0, 100)

## Get character emotional context for prompts
func get_character_influence(character_id: String) -> Dictionary:
	var character = world_db.get_character(character_id)
	if not character:
		return {}
	
	var stats = world_db.get_character_stats(character_id)
	
	return {
		"stats": stats,
		"traits": character.traits,
		"style": character.style,
		"mood": stats.get("mood", "neutral"),
		"bond": stats.get("bond_with_player", 0.5)
	}

## Legacy compatibility: check triggers (deprecated)
func check_triggers(scene_id: String, npc_id: String) -> Dictionary:
	var character = world_db.get_character(npc_id)
	if not character:
		return {}
	
	# Build context
	var context = {
		"scene_id": scene_id,
		"world": {
			"flags": world_db.flags
		}
	}
	
	# Check for scene.enter trigger
	var trigger = should_act(npc_id, "scene.enter", "global", context)
	if trigger:
		return {
			"verb": trigger.get_verb(),
			"target": trigger.get_target(),
			"narration": trigger.narration
		}
	
	return {}

## Legacy compatibility: get supportive action (deprecated)
func get_supportive_action(npc_id: String, context: Dictionary) -> Dictionary:
	if not context.has("command"):
		return {}
	
	var event = "player.command." + str(context.command)
	var trigger = should_act(npc_id, event, "global", context)
	if trigger:
		return {
			"verb": trigger.get_verb(),
			"target": trigger.get_target(),
			"narration": trigger.narration
		}
	
	return {}
