extends Node
class_name Director

## Turn phases, arbitration, patches

signal action_resolved(envelope: ResolutionEnvelope)
signal action_queue_updated(queue_preview: Array[String], current_actor: String)

var prompt_engine: PromptEngine
var world_db: WorldDB
var companion_ai: CompanionAI
var trigger_registry: TriggerRegistry
var current_scene_id: String = ""
var action_queue: ActionQueue = ActionQueue.new()

func _init(p_prompt_engine: PromptEngine, p_world_db: WorldDB):
	prompt_engine = p_prompt_engine
	world_db = p_world_db
	trigger_registry = TriggerRegistry.new()
	companion_ai = CompanionAI.new(world_db, trigger_registry)

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
	
	# Evaluate scene.enter triggers AFTER initial narration has been displayed
	# by deferring execution to the next frame.
	call_deferred("_evaluate_scene_enter_triggers", scene, envelope)
	
	# Generate initial UI choices
	envelope.ui_choices = _generate_ui_choices(scene)
	
	return envelope

func process_player_action(action: ActionRequest) -> ResolutionEnvelope:
	if action.scene != current_scene_id:
		action.scene = current_scene_id
	
	var scene = world_db.get_scene(current_scene_id)
	if not scene:
		return _create_error_envelope("No active scene")
	
	# Check for NPC interjections before player action (event-driven)
	var interjections = _check_interjections()
	if interjections.size() > 0:
		# Process interjections first
		for interjection in interjections:
			var trigger = interjection.get("trigger")
			if trigger:
				await _execute_trigger_action(trigger, interjection.get("character_id", ""))
	
	# Validate verb is available
	var target_entity = scene.get_entity(action.target)
	if not target_entity or not action.verb in target_entity.verbs:
		return _create_error_envelope("Invalid action: " + action.verb + " on " + action.target)
	
	# Record entity discovery if this is first interaction
	world_db.record_entity_discovery(action.target, action.actor, current_scene_id)
	
	# Handle scene navigation for exit entities
	if action.verb == "move" and target_entity.type_name == "exit":
		var destination_scene_id = target_entity.props.get("leads", "")
		if destination_scene_id != "":
			# Transition to new scene
			return await enter_scene(destination_scene_id)
	
	# Get character context if actor is an NPC
	var character_context = {}
	if action.actor != "player":
		character_context = companion_ai.get_character_influence(action.actor)
	
	# Process through PromptEngine with character context
	var envelope = await prompt_engine.process_action(action, character_context)
	
	# Apply patches to world DB
	_apply_patches(envelope.patches)
	
	# Update history
	world_db.add_history_entry({
		"event": "action",
		"actor": action.actor,
		"verb": action.verb,
		"target": action.target
	})
	
	# Advance turn in action queue and trigger registry
	action_queue.advance_turn()
	trigger_registry.advance_turn()
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

## Evaluate scene.enter triggers for all characters in scene
func _evaluate_scene_enter_triggers(scene: SceneGraph, _envelope: ResolutionEnvelope):
	var npc_entities = scene.get_entities_by_type("npc")
	if npc_entities.is_empty():
		return
	
	# Build context for trigger evaluation
	var context = {
		"scene_id": current_scene_id,
		"world": {
			"flags": world_db.flags
		},
		"scene": {
			"id": scene.scene_id,
			"description": scene.description,
			"tags": scene.rules.get("tags", [])
		}
	}
	
	# Check each NPC for matching triggers
	for npc_entity in npc_entities:
		var character = world_db.get_character(npc_entity.id)
		if not character:
			continue
		
		# Get matching triggers for scene.enter event
		var triggers = trigger_registry.get_matching_triggers(character, "scene.enter", "global", context)
		
		# Execute highest priority trigger
		if triggers.size() > 0:
			var trigger = triggers[0]
			await _execute_trigger_action(trigger, npc_entity.id)
			trigger_registry.record_trigger_used(trigger)

## Execute a trigger action
func _execute_trigger_action(trigger: TriggerDef, character_id: String):
	if not trigger.is_valid():
		return
	
	# Validate action
	if not trigger_registry.validate_action(trigger.action):
		push_warning("Invalid action for trigger " + trigger.id)
		return
	
	var action = ActionRequest.new()
	action.actor = character_id
	action.verb = trigger.get_verb()
	action.target = trigger.get_target()
	action.scene = current_scene_id
	
	# Use trigger params if present
	var params = trigger.get_params()
	if params.size() > 0:
		action.context = params
	
	# Process action
	var envelope = await process_player_action(action)
	
	# Override narration if trigger provides it
	if trigger.narration != "" and envelope.narration.size() > 0:
		envelope.narration[0].text = trigger.narration
		envelope.narration[0].speaker = character_id

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
								var old_value = null
								var change_type = ""
								var rel_path = ""
								
								match sub_root:
									"props":
										change_type = "prop"
										rel_path = "/" + "/".join(parts.slice(3))
										# Get old value for history
										var prop_path_parts = rel_path.trim_prefix("/").split("/")
										var dict = entity.props
										for i in range(prop_path_parts.size() - 1):
											if dict.has(prop_path_parts[i]) and dict[prop_path_parts[i]] is Dictionary:
												dict = dict[prop_path_parts[i]]
											else:
												dict = null
												break
										if dict != null and prop_path_parts.size() > 0:
											old_value = dict.get(prop_path_parts[-1])
										
										var rel_patch = {
											"op": patch.get("op", ""),
											"path": rel_path,
											"value": patch.get("value")
										}
										JsonPatch.apply_patch(entity.props, rel_patch)
										
										# Record change in history
										world_db.record_entity_change(entity_id, change_type, path, old_value, patch.get("value"), "player")
									"state":
										change_type = "state"
										var rel_path_s = "/" + "/".join(parts.slice(3))
										# Get old value for history
										var state_path_parts = rel_path_s.trim_prefix("/").split("/")
										var state_dict = entity.state
										for i in range(state_path_parts.size() - 1):
											if state_dict.has(state_path_parts[i]) and state_dict[state_path_parts[i]] is Dictionary:
												state_dict = state_dict[state_path_parts[i]]
											else:
												state_dict = null
												break
										if state_dict != null and state_path_parts.size() > 0:
											old_value = state_dict.get(state_path_parts[-1])
										
										var rel_patch_s = {
											"op": patch.get("op", ""),
											"path": rel_path_s,
											"value": patch.get("value")
										}
										JsonPatch.apply_patch(entity.state, rel_patch_s)
										
										# Record change in history
										world_db.record_entity_change(entity_id, change_type, path, old_value, patch.get("value"), "player")
									"lore":
										change_type = "lore"
										var rel_path_l = "/" + "/".join(parts.slice(3))
										# Get old value for history
										var lore_path_parts = rel_path_l.trim_prefix("/").split("/")
										var lore_dict = entity.lore
										for i in range(lore_path_parts.size() - 1):
											if lore_dict.has(lore_path_parts[i]) and lore_dict[lore_path_parts[i]] is Dictionary:
												lore_dict = lore_dict[lore_path_parts[i]]
											else:
												lore_dict = null
												break
										if lore_dict != null and lore_path_parts.size() > 0:
											old_value = lore_dict.get(lore_path_parts[-1])
										
										var rel_patch_l = {
											"op": patch.get("op", ""),
											"path": rel_path_l,
											"value": patch.get("value")
										}
										JsonPatch.apply_patch(entity.lore, rel_patch_l)
										
										# Record change in history
										world_db.record_entity_change(entity_id, change_type, path, old_value, patch.get("value"), "player")
									_:
										push_warning("Unsupported patch target: " + sub_root + ", supported: props/state/lore")
			elif path.begins_with("characters/"):
				var cparts = path.split("/")
				if cparts.size() >= 3:
					var char_id = cparts[1]
					var sub = cparts[2]
					match sub:
						"stats":
							var rel_path_c = "/" + "/".join(cparts.slice(3))
							var state = world_db.get_character_state(char_id)
							if state.has("stats") and state.stats is Dictionary:
								var rel_patch_c = {
									"op": patch.get("op", ""),
									"path": rel_path_c,
									"value": patch.get("value")
								}
								JsonPatch.apply_patch(state.stats, rel_patch_c)
								# Record in global history
								world_db.add_history_entry({
									"event": "character_stat_change",
									"character_id": char_id,
									"path": rel_path_c,
									"op": patch.get("op", ""),
									"value": patch.get("value")
								})
						_:
							push_warning("Unsupported character patch target: " + sub + ", supported: stats")

func _generate_ui_choices(scene: SceneGraph) -> Array[UIChoice]:
	var choices: Array[UIChoice] = []
	
	for entity in scene.entities:
		for verb in entity.verbs:
			# Filter out talk actions; conversations are handled via chat addressing
			if verb == "talk":
				continue
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
	
	# Add NPCs from scene using initiative for priority
	var npc_entities = scene.get_entities_by_type("npc")
	for npc_entity in npc_entities:
		var character = world_db.get_character(npc_entity.id)
		if character:
			# Use initiative, invert to queue priority (lower priority = earlier turn)
			var initiative = companion_ai.get_initiative(npc_entity.id)
			var priority = clamp(100 - initiative, 0, 100)
			# Characters with triggers can interject
			var can_interject = character.triggers.size() > 0
			action_queue.add_actor(npc_entity.id, priority, can_interject)
	
	_emit_queue_update()

func _check_interjections() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var interjecting_actors = action_queue.get_interjecting_actors()
	
	if interjecting_actors.is_empty():
		return result
	
	var scene = world_db.get_scene(current_scene_id)
	if not scene:
		return result
	
	# Build context for trigger evaluation
	var context = {
		"scene_id": current_scene_id,
		"world": {
			"flags": world_db.flags
		},
		"scene": {
			"id": scene.scene_id,
			"description": scene.description
		}
	}
	
	# Check each interjecting actor for matching triggers
	for actor_id in interjecting_actors:
		# Check for tick.turn triggers (for interjections)
		var trigger = companion_ai.should_act(actor_id, "tick.turn", "global", context)
		if trigger:
			result.append({
				"character_id": actor_id,
				"trigger": trigger
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
