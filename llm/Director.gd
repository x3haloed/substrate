extends Node
class_name Director

## Turn phases, arbitration, patches

signal action_resolved(envelope: ResolutionEnvelope)

var prompt_engine: PromptEngine
var world_db: WorldDB
var companion_ai: CompanionAI
var current_scene_id: String = ""

func _init(p_prompt_engine: PromptEngine, p_world_db: WorldDB):
	prompt_engine = p_prompt_engine
	world_db = p_world_db
	companion_ai = CompanionAI.new(world_db)

func enter_scene(scene_id: String) -> ResolutionEnvelope:
	current_scene_id = scene_id
	world_db.flags["current_scene"] = scene_id
	world_db.add_history_entry({"event": "scene_enter", "scene": scene_id})
	
	var scene = world_db.get_scene(scene_id)
	if not scene:
		return _create_error_envelope("Scene not found: " + scene_id)
	
	# Frame initial narration
	var context = {
		"scene_id": scene_id,
		"description": scene.description,
		"entities": _get_entity_summaries(scene)
	}
	
	var narration_text = await prompt_engine.process_narrator_request(context)
	
	var envelope = ResolutionEnvelope.new()
	var narr = NarrationEvent.new()
	narr.style = "world"
	narr.text = narration_text if narration_text != "" else scene.description
	envelope.narration.append(narr)
	
	# Check for on_enter triggers
	if scene.rules.has("on_enter"):
		var trigger_ids = scene.rules.on_enter
		if trigger_ids is Array:
			for trigger_id in trigger_ids:
				await _process_trigger(trigger_id, envelope)
	
	# Generate initial UI choices
	envelope.ui_choices = _generate_ui_choices(scene)
	
	return envelope

func process_player_action(action: ActionRequest) -> ResolutionEnvelope:
	if action.scene != current_scene_id:
		action.scene = current_scene_id
	
	var scene = world_db.get_scene(current_scene_id)
	if not scene:
		return _create_error_envelope("No active scene")
	
	# Validate verb is available
	var target_entity = scene.get_entity(action.target)
	if not target_entity or not action.verb in target_entity.verbs:
		return _create_error_envelope("Invalid action: " + action.verb + " on " + action.target)
	
	# Process through PromptEngine
	var envelope = await prompt_engine.process_action(action)
	
	# Apply patches to world DB
	_apply_patches(envelope.patches)
	
	# Update history
	world_db.add_history_entry({
		"event": "action",
		"actor": action.actor,
		"verb": action.verb,
		"target": action.target
	})
	
	# Generate new UI choices from scene
	envelope.ui_choices = _generate_ui_choices(scene)
	
	action_resolved.emit(envelope)
	return envelope

func process_companion_action(npc_id: String, verb: String, target: String, narration_override: String = "") -> ResolutionEnvelope:
	var action = ActionRequest.new()
	action.actor = npc_id
	action.verb = verb
	action.target = target
	action.scene = current_scene_id
	
	var envelope = await process_player_action(action)
	
	# Override narration if provided
	if narration_override != "" and envelope.narration.size() > 0:
		envelope.narration[0].text = narration_override
		envelope.narration[0].speaker = npc_id
	
	return envelope

func _process_trigger(trigger_id: String, envelope: ResolutionEnvelope):
	# Parse trigger_id format: "npc_assertive_{action}"
	if trigger_id.begins_with("npc_assertive_"):
		var parts = trigger_id.split("_")
		if parts.size() >= 3:
			var npc_action = parts[2]  # e.g., "fool_trip"
			# Look up trigger data
			var trigger_data = _get_trigger_data(npc_action)
			if trigger_data.size() > 0:
				var narr = NarrationEvent.new()
				narr.style = "world"
				narr.text = trigger_data.get("narration", "")
				envelope.narration.append(narr)
				
				# Perform the action
				if trigger_data.has("verb") and trigger_data.has("target"):
					await process_companion_action(
						trigger_data.get("npc_id", ""),
						trigger_data.verb,
						trigger_data.target,
						trigger_data.narration
					)

func _get_trigger_data(trigger_key: String) -> Dictionary:
	# MVP: Hardcoded triggers
	match trigger_key:
		"fool_trip":
			return {
				"npc_id": "fool",
				"verb": "blunder",
				"target": "mug",
				"narration": "The fool stumbles forward, knocking a mug off the counter with a clatter."
			}
		_:
			return {}

func _apply_patches(patches: Array):
	for patch in patches:
		if patch is Dictionary:
			# Apply to world DB entities
			var path = patch.get("path", "")
			if path.begins_with("/entities/"):
				var parts = path.split("/")
				if parts.size() >= 4:
					var entity_id = parts[2]
					var _prop_key = parts[3]
					
					var scene = world_db.get_scene(current_scene_id)
					if scene:
						var entity = scene.get_entity(entity_id)
						if entity:
							JsonPatch.apply_patch(entity.props, patch)
							
							# Also update world DB cache
							if world_db.entities.has(entity_id):
								var entity_data = world_db.entities[entity_id]
								if entity_data is Dictionary:
									JsonPatch.apply_patch(entity_data, patch)

func _generate_ui_choices(scene: SceneGraph) -> Array[UIChoice]:
	var choices: Array[UIChoice] = []
	
	for entity in scene.entities:
		for verb in entity.verbs:
			var choice = UIChoice.new()
			choice.verb = verb
			choice.target = entity.id
			choice.label = verb.capitalize() + " [" + entity.id + "]"
			choices.append(choice)
	
	return choices

func _get_entity_summaries(scene: SceneGraph) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entity in scene.entities:
		result.append({
			"id": entity.id,
			"type": entity.type_name,
			"description": entity.props.get("description", "")
		})
	return result

func _create_error_envelope(message: String) -> ResolutionEnvelope:
	var envelope = ResolutionEnvelope.new()
	var narr = NarrationEvent.new()
	narr.style = "world"
	narr.text = "[Error: " + message + "]"
	envelope.narration.append(narr)
	return envelope
