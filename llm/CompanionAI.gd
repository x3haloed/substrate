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
	
	# Roll based on assertiveness value
	var roll = randf()
	return roll < npc_state.assertiveness

func get_supportive_action(npc_id: String, context: Dictionary) -> Dictionary:
	var npc_state = world_db.get_npc_state(npc_id)
	if not npc_state:
		return {}
	
	# Check if specific command trigger exists
	if context.has("command") and npc_state.triggers.has("on_command_" + context.command):
		var action = npc_state.triggers["on_command_" + context.command]
		return {
			"verb": action.get("verb", ""),
			"target": action.get("target", ""),
			"narration": action.get("narration", "")
		}
	
	return {}
