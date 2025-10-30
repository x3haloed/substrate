extends Node
class_name Director

## Turn phases, arbitration, patches

signal action_resolved(envelope: ResolutionEnvelope)
signal action_queue_updated(queue_preview: Array[String], current_actor: String)

var prompt_engine: PromptEngine
var world_db: WorldDB
var companion_ai: CompanionAI
var current_scene_id: String = ""
var action_queue: ActionQueue = ActionQueue.new()

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
	
	# Initialize action queue for this scene
	_initialize_action_queue(scene)
	
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
	
	# Check for NPC interjections before player action
	var interjections = await _check_interjections()
	if interjections.size() > 0:
		# Process interjections first
		for interjection in interjections:
			await process_companion_action(
				interjection.actor_id,
				interjection.verb,
				interjection.target,
				interjection.narration
			)
	
	# Validate verb is available
	var target_entity = scene.get_entity(action.target)
	if not target_entity or not action.verb in target_entity.verbs:
		return _create_error_envelope("Invalid action: " + action.verb + " on " + action.target)
	
	# Handle scene navigation for exit entities
	if action.verb == "move" and target_entity.type_name == "exit":
		var destination_scene_id = target_entity.props.get("leads", "")
		if destination_scene_id != "":
			# Transition to new scene
			return await enter_scene(destination_scene_id)
	
	# Get emotional context if actor is an NPC
	var emotional_context = {}
	if action.actor != "player":
		emotional_context = companion_ai.get_npc_line_influence(action.actor)
	
	# Process through PromptEngine with emotional context
	var envelope = await prompt_engine.process_action(action, emotional_context)
	
	# Apply patches to world DB
	_apply_patches(envelope.patches)
	
	# Update history
	world_db.add_history_entry({
		"event": "action",
		"actor": action.actor,
		"verb": action.verb,
		"target": action.target
	})
	
	# Advance turn in action queue
	action_queue.advance_turn()
	_emit_queue_update()
	
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
			if path.begins_with("/"):
				path = path.substr(1)
			if path.begins_with("entities/"):
				var parts = path.split("/")
				if parts.size() >= 3:
					var entity_id = parts[1]
					var scene = world_db.get_scene(current_scene_id)
					if scene:
						var entity = scene.get_entity(entity_id)
						if entity:
							# Route patches by sub-root (props/state/lore supported). Arrays like verbs/tags are ignored for now.
							if parts.size() >= 4:
								var sub_root = parts[2]
								match sub_root:
									"props":
										var rel_path = "/" + "/".join(parts.slice(3))
										var rel_patch = {
											"op": patch.get("op", ""),
											"path": rel_path,
											"value": patch.get("value")
										}
										JsonPatch.apply_patch(entity.props, rel_patch)
										# Also update world DB cache copy if present
										if world_db.entities.has(entity_id):
											var entity_data = world_db.entities[entity_id]
											if entity_data is Dictionary and entity_data.has("props") and entity_data.props is Dictionary:
												JsonPatch.apply_patch(entity_data.props, rel_patch)
									"state":
										var rel_path_s = "/" + "/".join(parts.slice(3))
										var rel_patch_s = {
											"op": patch.get("op", ""),
											"path": rel_path_s,
											"value": patch.get("value")
										}
										JsonPatch.apply_patch(entity.state, rel_patch_s)
										if world_db.entities.has(entity_id):
											var entity_data_s = world_db.entities[entity_id]
											if entity_data_s is Dictionary and entity_data_s.has("state") and entity_data_s.state is Dictionary:
												JsonPatch.apply_patch(entity_data_s.state, rel_patch_s)
									"lore":
										var rel_path_l = "/" + "/".join(parts.slice(3))
										var rel_patch_l = {
											"op": patch.get("op", ""),
											"path": rel_path_l,
											"value": patch.get("value")
										}
										JsonPatch.apply_patch(entity.lore, rel_patch_l)
										if world_db.entities.has(entity_id):
											var entity_data_l = world_db.entities[entity_id]
											if entity_data_l is Dictionary and entity_data_l.has("lore") and entity_data_l.lore is Dictionary:
												JsonPatch.apply_patch(entity_data_l.lore, rel_patch_l)
									_:
										push_warning("Unsupported patch target: " + sub_root + ", supported: props/state/lore")

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

func _initialize_action_queue(scene: SceneGraph):
	action_queue.clear()
	
	# Add player first (always priority 0)
	action_queue.add_actor("player", 0, false)
	
	# Add NPCs from scene (they can interject)
	var npc_entities = scene.get_entities_by_type("npc")
	for npc_entity in npc_entities:
		var npc_state = world_db.get_npc_state(npc_entity.id)
		if npc_state:
			# Priority based on assertiveness (higher assertiveness = earlier priority)
			var priority = int((1.0 - npc_state.assertiveness) * 10)
			var can_interject = npc_state.assertiveness > 0.3
			action_queue.add_actor(npc_entity.id, priority, can_interject)
	
	_emit_queue_update()

func _check_interjections() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var interjecting_actors = action_queue.get_interjecting_actors()
	
	for actor_id in interjecting_actors:
		if companion_ai.should_act_assertively(actor_id):
			# Check for available interjection actions
			var scene = world_db.get_scene(current_scene_id)
			if scene:
				var npc_state = world_db.get_npc_state(actor_id)
				if npc_state:
					# Simple interjection: NPC might make a comment or minor action
					# For now, check triggers for context-appropriate actions
					var trigger_result = companion_ai.check_triggers(current_scene_id, actor_id)
					if trigger_result.size() > 0:
						result.append({
							"actor_id": actor_id,
							"verb": trigger_result.get("verb", ""),
							"target": trigger_result.get("target", ""),
							"narration": trigger_result.get("narration", "")
						})
	
	return result

func _emit_queue_update():
	var preview = action_queue.get_queue_preview(3)
	var current = action_queue.get_next_actor()
	action_queue_updated.emit(preview, current)

func _create_error_envelope(message: String) -> ResolutionEnvelope:
	var envelope = ResolutionEnvelope.new()
	var narr = NarrationEvent.new()
	narr.style = "world"
	narr.text = "[Error: " + message + "]"
	envelope.narration.append(narr)
	return envelope
