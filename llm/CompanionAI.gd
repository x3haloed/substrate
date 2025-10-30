extends RefCounted
class_name CompanionAI

## NPC state vectors, triggers, and delegation

var world_db: WorldDB

func _init(p_world_db: WorldDB):
	world_db = p_world_db

func check_triggers(scene_id: String, npc_id: String) -> Dictionary:
	var npc_state = world_db.get_npc_state(npc_id)
	if not npc_state:
		return {}
	
	# Check for trigger conditions
	for trigger_key in npc_state.triggers.keys():
		var action = npc_state.triggers[trigger_key]
		
		# Simple trigger matching for MVP
		if trigger_key == "on_arrival" and scene_id == world_db.flags.get("current_scene", ""):
			return {
				"verb": action if action is String else action.get("verb", ""),
				"target": action.get("target", "") if action is Dictionary else "",
				"narration": action.get("narration", "") if action is Dictionary else ""
			}
	
	return {}

func should_act_assertively(npc_id: String) -> bool:
	var npc_state = world_db.get_npc_state(npc_id)
	if not npc_state:
		return false
	
	# Calculate dynamic assertiveness based on mood and bond
	var dynamic_assertiveness = _calculate_dynamic_assertiveness(npc_state)
	
	# Roll based on dynamic assertiveness value
	var roll = randf()
	return roll < dynamic_assertiveness

func _calculate_dynamic_assertiveness(npc_state: NPCState) -> float:
	# base assertiveness modified by mood and bond
	var base = npc_state.assertiveness
	
	# Mood modifiers (affect willingness to act)
	var mood_modifier = 0.0
	match npc_state.mood:
		"cheerful", "alert", "determined":
			mood_modifier = 0.2
		"content", "neutral":
			mood_modifier = 0.0
		"depressed", "tired", "frightened":
			mood_modifier = -0.3
		"angry", "hostile":
			mood_modifier = 0.3  # High assertiveness when hostile
	
	# Bond modifier (higher bond = more willing to act assertively to help)
	var bond_modifier = (npc_state.bond_with_player - 0.5) * 0.2
	
	return clamp(base + mood_modifier + bond_modifier, 0.0, 1.0)

func get_supportive_action(npc_id: String, context: Dictionary) -> Dictionary:
	var npc_state = world_db.get_npc_state(npc_id)
	if not npc_state:
		return {}
	
	# Check if specific command trigger exists
	if context.has("command") and npc_state.triggers.has("on_command_" + context.command):
		var action = npc_state.triggers["on_command_" + context.command]
		var narration = action.get("narration", "")
		
		# Enhance narration with emotional context
		if narration != "":
			narration = _add_emotional_flavor(narration, npc_state)
		
		return {
			"verb": action.get("verb", ""),
			"target": action.get("target", ""),
			"narration": narration
		}
	
	return {}

func _add_emotional_flavor(text: String, npc_state: NPCState) -> String:
	# Add emotional flavor based on mood and bond
	var flavor_prefix = ""
	
	if npc_state.bond_with_player > 0.7:
		match npc_state.mood:
			"cheerful":
				flavor_prefix = "Eagerly, "
			"alert":
				flavor_prefix = "Without hesitation, "
			"determined":
				flavor_prefix = "Resolutely, "
	elif npc_state.bond_with_player < 0.3:
		match npc_state.mood:
			"depressed":
				flavor_prefix = "Slowly, "
			"tired":
				flavor_prefix = "Wearily, "
			"neutral":
				flavor_prefix = "Reluctantly, "
	
	return flavor_prefix + text

func get_npc_line_influence(npc_id: String) -> Dictionary:
	# Returns emotional context for use in LLM prompts
	var npc_state = world_db.get_npc_state(npc_id)
	if not npc_state:
		return {}
	
	return {
		"mood": npc_state.mood,
		"bond": npc_state.bond_with_player,
		"conviction": npc_state.conviction,
		"goals": npc_state.goals
	}
