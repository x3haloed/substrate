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
var open_area_generator: OpenAreaGenerator
var _active_open_area: Dictionary = {} # { area_id, target_scene_id, condition, generated_scene_id }

func _init(p_prompt_engine: PromptEngine, p_world_db: WorldDB):
	prompt_engine = p_prompt_engine
	world_db = p_world_db
	trigger_registry = TriggerRegistry.new()
	companion_ai = CompanionAI.new(world_db, trigger_registry)
	open_area_generator = OpenAreaGenerator.new(prompt_engine, world_db)

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
	
	# Optional scene image: load from image_path and pass Image to narrator
	var scene_image: Image = null
	if typeof(scene.image_path) == TYPE_STRING and scene.image_path != "":
		var ip := str(scene.image_path)
		var load_path := PathResolver.resolve_path(ip, world_db)
		if load_path != "":
			var img := Image.new()
			var err := img.load(load_path)
			if err == OK:
				scene_image = img
			else:
				push_warning("Failed to load scene image: " + load_path)
	var narration_text = await prompt_engine.process_narrator_request(context, scene_image)
	
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
	# Resolve image path for UI display (absolute or local path)
	var resolved_path := ""
	if typeof(scene.image_path) == TYPE_STRING and scene.image_path != "":
		var ip2 := str(scene.image_path)
		resolved_path = PathResolver.resolve_path(ip2, world_db)
	envelope.scene_image_path = resolved_path
	# Notify listeners so UI can update
	action_resolved.emit(envelope)
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

	# Handle open area portals (LLM-assisted generation)
	if action.verb == "enter" and target_entity.type_name == "portal":
		var kind = str(target_entity.props.get("kind", ""))
		if kind == "open_area":
			var area_id = str(target_entity.props.get("area_id", ""))
			if area_id != "":
				var def := _load_open_area_def(area_id)
				if def != null and def is OpenAreaDef:
					var gen_scene_id := await open_area_generator.generate(def, str(world_db.flags.get("cartridge_id", "default")))
					if gen_scene_id != "":
						_active_open_area = {
							"area_id": area_id,
							"target_scene_id": def.completion.get("target_scene_id", ""),
							"condition": def.completion.get("condition", {}),
							"generated_scene_id": gen_scene_id
						}
						return await enter_scene(gen_scene_id)
	
	# Get character context if actor is an NPC
	var character_context = {}
	if action.actor != "player":
		character_context = companion_ai.get_character_influence(action.actor)
	
	# Process through PromptEngine with character context
	var envelope = await prompt_engine.process_action(action, character_context)

	# Ensure voice formatting for talk: speaker is target when player talks; otherwise it's the actor
	if action.verb == "talk":
		var speaker_id = action.target if action.actor == "player" else action.actor
		if envelope.narration.size() == 0:
			var n = NarrationEvent.new()
			n.style = "npc"
			n.speaker = speaker_id
			n.text = "..."
			envelope.narration.append(n)
		else:
			# Force style/speaker for first entry
			envelope.narration[0].style = "npc"
			envelope.narration[0].speaker = speaker_id
	
	# Apply patches to world DB
	_apply_patches(envelope.patches)

	# Engine-handled commands (e.g., transfer)
	_process_commands(envelope.commands)

	# Post-patch intervention for 'take': allow LLM first, then fallback
	if action.verb == "take":
		_fallback_take_if_needed(action, envelope)
	
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
	# Evaluate open area completion after action
	var maybe_transition := await _maybe_complete_open_area()
	if maybe_transition != null:
		return maybe_transition
	return envelope

func process_freeform_player_input(text: String) -> ResolutionEnvelope:
	if current_scene_id == "":
		return _create_error_envelope("No active scene")
	var scene = world_db.get_scene(current_scene_id)
	if not scene:
		return _create_error_envelope("No active scene")
	# Let PromptEngine interpret and resolve the freeform input
	var envelope = await prompt_engine.process_freeform_input(scene, text)
	# Apply patches and advance systems like a normal action
	_apply_patches(envelope.patches)
	# Process engine commands from freeform
	_process_commands(envelope.commands)
	# Minimal heuristic: parse 'give <item> to <target>' if no commands returned
	if (envelope.commands == null or envelope.commands.is_empty()):
		var lower = text.strip_edges().to_lower()
		if lower.begins_with("give ") and " to " in lower:
			var parts = lower.substr(5).split(" to ")
			if parts.size() == 2:
				var item_id = parts[0].strip_edges().replace("[", "").replace("]", "")
				var target_id = parts[1].strip_edges().replace("[", "").replace("]", "")
				var cmd = {"type": "transfer", "from": "player", "to": target_id, "item": item_id, "quantity": 1}
				_process_commands([cmd])
	world_db.add_history_entry({
		"event": "freeform_input",
		"text": text
	})
	action_queue.advance_turn()
	trigger_registry.advance_turn()
	_emit_queue_update()
	# Refresh choices
	envelope.ui_choices = _generate_ui_choices(scene)
	action_resolved.emit(envelope)
	var maybe_transition := await _maybe_complete_open_area()
	if maybe_transition != null:
		return maybe_transition
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
										var prop_key_exists = false
										if dict != null and prop_path_parts.size() > 0:
											prop_key_exists = dict.has(prop_path_parts[-1])
											old_value = dict.get(prop_path_parts[-1])
										var effective_op = patch.get("op", "")
										if effective_op == "replace" and not prop_key_exists:
											effective_op = "add"
										var rel_patch = {
											"op": effective_op,
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
										var state_key_exists = false
										if state_dict != null and state_path_parts.size() > 0:
											state_key_exists = state_dict.has(state_path_parts[-1])
											old_value = state_dict.get(state_path_parts[-1])
										var effective_op_s = patch.get("op", "")
										if effective_op_s == "replace" and not state_key_exists:
											effective_op_s = "add"
										var rel_patch_s = {
											"op": effective_op_s,
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
										var lore_key_exists = false
										if lore_dict != null and lore_path_parts.size() > 0:
											lore_key_exists = lore_dict.has(lore_path_parts[-1])
											old_value = lore_dict.get(lore_path_parts[-1])
										var effective_op_l = patch.get("op", "")
										if effective_op_l == "replace" and not lore_key_exists:
											effective_op_l = "add"
										var rel_patch_l = {
											"op": effective_op_l,
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
		# Hide entities already taken/removed
		if entity.state.get("taken", false):
			continue
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

## Deterministic fallback for 'take' verb when LLM patches do not handle removal/ownership
func _fallback_take_if_needed(action: ActionRequest, envelope: ResolutionEnvelope) -> void:
	var scene = world_db.get_scene(current_scene_id)
	if not scene:
		return
	var e = scene.get_entity(action.target)
	if e == null:
		return
	if e.state.get("taken", false):
		return
	# Prefer Phase 2 Inventory if available
	world_db.ensure_player_inventory()
	if world_db.player_inventory != null:
		var def := _resolve_item_def_for_entity(e)
		if def != null:
			var stack := ItemStack.new()
			stack.item = def
			stack.quantity = 1
			if world_db.player_inventory.can_accept(stack):
				world_db.player_inventory.try_add_stack(stack)
			else:
				# Inventory full: do not move item; inform via narration and exit
				if envelope.narration.size() == 0:
					var n = NarrationEvent.new()
					n.style = "world"
					n.text = "Your pack is full. You can't carry the %s." % e.id
					envelope.narration.append(n)
				return
	else:
		# Phase 1 fallback to contents
		world_db.ensure_player_entity()
		var player_data = world_db.entities.get("player", {})
		if player_data is Dictionary:
			if not player_data.has("contents"):
				player_data["contents"] = []
			var contents = player_data["contents"]
			if contents is Array and not (action.target in contents):
				contents.append(action.target)
				player_data["contents"] = contents
	# Mark entity as taken so it no longer appears in choices
	e.state["taken"] = true
	# Add a minimal narration line if LLM didn't provide one
	if envelope.narration.size() == 0:
		var n = NarrationEvent.new()
		n.style = "world"
		n.text = "You take the %s." % e.id
		envelope.narration.append(n)

## Simple resolver that maps a scene entity to an ItemDef (placeholder: generates inline defs)
func _resolve_item_def_for_entity(entity: Entity) -> ItemDef:
	if entity == null:
		return null
	var def := ItemDef.new()
	def.id = entity.id
	def.display_name = entity.props.get("display_name", entity.id.capitalize())
	def.description = entity.props.get("description", "")
	def.weight_kg = float(entity.props.get("weight_kg", 0.5))
	def.max_stack = int(entity.props.get("max_stack", 1))
	return def

## Process engine-handled commands from the envelope
func _process_commands(commands: Array) -> void:
	if commands == null or commands.is_empty():
		return
	for cmd in commands:
		if not (cmd is Dictionary):
			continue
		var ctype = str(cmd.get("type", ""))
		match ctype:
			"transfer":
				_handle_transfer_command(cmd)
			_:
				# Unsupported command types are ignored for now
				pass

## Transfer items between owners (player inventory ↔ entity.contents)
func _handle_transfer_command(cmd: Dictionary) -> void:
	var from_id = str(cmd.get("from", ""))
	var to_id = str(cmd.get("to", ""))
	var item_id = str(cmd.get("item", ""))
	var qty = int(cmd.get("quantity", 1))
	if from_id == "" or to_id == "" or item_id == "" or qty <= 0:
		return
	# Player → NPC transfer
	if from_id == "player":
		world_db.ensure_player_inventory()
		var inv = world_db.player_inventory
		if inv == null:
			return
		# Remove from player inventory by ItemDef id
		var removed := 0
		for i in range(inv.slots.size() - 1, -1, -1):
			var s: ItemStack = inv.slots[i]
			if s and s.item and s.item.id == item_id:
				var take = min(qty - removed, s.quantity)
				s.quantity -= take
				removed += take
				if s.quantity <= 0:
					inv.slots.remove_at(i)
				if removed >= qty:
					break
		if removed <= 0:
			return
		inv.emit_signal("changed")
		# Add to target entity.contents
		var scene = world_db.get_scene(current_scene_id)
		if not scene:
			return
		var target_entity = scene.get_entity(to_id)
		if target_entity == null:
			return
		if not (target_entity.contents is Array):
			target_entity.contents = []
		for j in range(removed):
			if not (item_id in target_entity.contents):
				target_entity.contents.append(item_id)
		# Optionally mark owner
		var item_entity = scene.get_entity(item_id)
		if item_entity:
			item_entity.state["taken"] = true
			item_entity.props["owner"] = to_id

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

func _load_open_area_def(area_id: String) -> OpenAreaDef:
	var base := PathResolver.resolve_world_base_path(world_db)
	if base == "":
		return null
	var path := base + "/open_areas/" + area_id + ".tres"
	if ResourceLoader.exists(path):
		return load(path) as OpenAreaDef
	return null

func _maybe_complete_open_area() -> ResolutionEnvelope:
	if _active_open_area.is_empty():
		return null
	var cond: Dictionary = _active_open_area.get("condition", {})
	var target := str(_active_open_area.get("target_scene_id", ""))
	var gen_scene := str(_active_open_area.get("generated_scene_id", ""))
	if current_scene_id != gen_scene or target == "":
		return null
	# Basic condition: { "discover_entity": "id" } or { "interact": "id" }
	if cond is Dictionary:
		var discover := str(cond.get("discover_entity", ""))
		var interact := str(cond.get("interact", ""))
		if discover != "":
			var discovered := world_db.get_entities_discovered_by("player")
			if discover in discovered:
				_active_open_area = {}
				return await enter_scene(target)
		elif interact != "":
			# Heuristic: check world history for last action on that target
			for i in range(world_db.history.size() - 1, -1, -1):
				var h = world_db.history[i]
				if h.get("event", "") == "action" and h.get("target", "") == interact:
					_active_open_area = {}
					return await enter_scene(target)
	return null

func _create_error_envelope(message: String) -> ResolutionEnvelope:
	var envelope = ResolutionEnvelope.new()
	var narr = NarrationEvent.new()
	narr.style = "world"
	narr.text = "[Error: " + message + "]"
	envelope.narration.append(narr)
	return envelope
