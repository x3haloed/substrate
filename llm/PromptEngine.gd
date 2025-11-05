extends RefCounted
class_name PromptEngine

## Builds prompts, parses JSON, hot-reload capable

var llm_client: LLMClient
var world_db: WorldDB
const PromptTemplateRegistryScript = preload("res://llm/PromptTemplateRegistry.gd")
var templates
const PromptInjectionManagerScript = preload("res://llm/PromptInjectionManager.gd")
var injection_manager
var injection_layers: Array = []
const PromptAssemblerScript = preload("res://llm/PromptAssembler.gd")



func _init(p_llm_client: LLMClient, p_world_db: WorldDB):
	llm_client = p_llm_client
	world_db = p_world_db
	templates = PromptTemplateRegistryScript.new()
	injection_manager = PromptInjectionManagerScript.new()

	# Default prompt injection layers (enabled). These reinforce output formats and
	# placement priorities across scopes, similar to ST's Prompt Manager behavior.
	var L = PromptInjectionManagerScript.LayerDef
	var P = PromptInjectionManagerScript.Position

	# Director: enforce strict JSON when schema is provided; avoid code fences/text.
	var dir_before := L.new()
	dir_before.id = "director.strict_json"
	dir_before.scope = "director"
	dir_before.position = P.BEFORE_SYSTEM
	dir_before.role = "system"
	dir_before.priority = 0
	dir_before.enabled = true
	dir_before.content = "When a JSON schema is provided, respond only with a single JSON object that strictly matches it. Do not include code fences or any extra commentary."
	injection_layers.append(dir_before)

	# NPC: reinforce single-object JSON and no extra commentary.
	var npc_before := L.new()
	npc_before.id = "npc.strict_json"
	npc_before.scope = "npc"
	npc_before.position = P.BEFORE_SYSTEM
	npc_before.role = "system"
	npc_before.priority = 0
	npc_before.enabled = true
	npc_before.content = "Output must be one JSON object only. No code fences, no explanations."
	injection_layers.append(npc_before)

	# Freeform: enforce strict JSON output as ResolutionEnvelope.
	var ff_before := L.new()
	ff_before.id = "freeform.strict_json"
	ff_before.scope = "freeform"
	ff_before.position = P.BEFORE_SYSTEM
	ff_before.role = "system"
	ff_before.priority = 0
	ff_before.enabled = true
	ff_before.content = "Respond only with a single JSON object conforming to the requested ResolutionEnvelope. No code fences or extra text."
	injection_layers.append(ff_before)

	# Narrator: gentle reminder to avoid structured outputs.
	var nar_after := L.new()
	nar_after.id = "narrator.prose_only"
	nar_after.scope = "narrator"
	nar_after.position = P.AFTER_SYSTEM
	nar_after.role = "system"
	nar_after.priority = 10
	nar_after.enabled = true
	nar_after.content = "Respond with plain prose only; do not output JSON or code fences."
	injection_layers.append(nar_after)

func build_narrator_prompt(scene_context: Dictionary, image: Image = null) -> Array[Dictionary]:
	var brief := format_scene_brief(scene_context)
	# Build recent chat snapshot to give narrator strong situational awareness
	var chat_snapshot = _build_chat_snapshot()
	var user_text = "Scene brief:\n" + brief + "\n\n" + "Recent chat snapshot:\n" + JSON.stringify(chat_snapshot, "\t") + "\n\nWrite a concise atmospheric paragraph (3-5 sentences)."
	var system_msg = {"role": "system", "content": templates.get_narrator_system_prompt()}
	var messages: Array[Dictionary] = []
	# If vision supported and image provided, embed as Base64 data URL
	if llm_client and llm_client.settings and llm_client.settings.supports_vision and image != null:
		var png_bytes: PackedByteArray = image.save_png_to_buffer()
		var base64_image := Marshalls.raw_to_base64(png_bytes)
		var data_url := "data:image/png;base64," + base64_image
		messages = [
			system_msg,
			{"role": "user", "content": [
				{"type": "text", "text": user_text},
				{"type": "image_url", "image_url": {"url": data_url}}
			]}
		]
	# Fallback: text-only
	else:
		messages = [
			system_msg,
			{"role": "user", "content": user_text}
		]
	return injection_manager.apply_layers("narrator", messages, {"scene_context": scene_context}, injection_layers)

## Convert scene context JSON into a human-friendly brief to nudge prose outputs
static func format_scene_brief(scene_context: Dictionary) -> String:
	var lines: Array[String] = []
	if scene_context.has("description") and typeof(scene_context.get("description")) == TYPE_STRING:
		lines.append("Setting: " + str(scene_context.get("description")))
	
	if scene_context.has("entities") and scene_context.entities is Array:
		var entity_lines: Array[String] = []
		for e in scene_context.entities:
			if e is Dictionary and e.has("description") and str(e.get("description", "")) != "":
				var etype := str(e.get("type", e.get("type_name", "")))
				var edesc := str(e.get("description", ""))
				var piece := "- " + edesc + " (" + etype + ")"
				entity_lines.append(piece)
		if entity_lines.size() > 0:
			lines.append("Entities in the scene:\n" + "\n".join(entity_lines))
	
	return "\n".join(lines)

func build_director_prompt(action: ActionRequest, scene: SceneGraph, character_context: Dictionary = {}) -> Array[Dictionary]:
	var scene_info = {
		"scene_id": scene.scene_id,
		"description": scene.description,
		"entities": _serialize_entities(scene.entities),
		"rules": scene.rules
	}
	
	var action_info = {
		"actor": action.actor,
		"verb": action.verb,
		"target": action.target,
		"context": action.context
	}
	
	var user_sections: Array[String] = []
	user_sections.append("Current Scene:\n" + JSON.stringify(scene_info, "\t"))
	user_sections.append("Action Request:\n" + JSON.stringify(action_info, "\t"))
	
	# Add character context if actor is an NPC
	if character_context.size() > 0:
		var context_lines: Array[String] = []
		context_lines.append("Actor Character Context:")
		
		# Character core
		if character_context.has("name"):
			context_lines.append("- Name: " + str(character_context.name))
		if character_context.has("description"):
			context_lines.append("- Description: " + str(character_context.description))
		if character_context.has("personality"):
			context_lines.append("- Personality: " + str(character_context.personality))
		
		# Traits
		if character_context.has("traits") and character_context.traits is Array:
			if character_context.traits.size() > 0:
				context_lines.append("- Traits: " + ", ".join(character_context.traits))
		
		# Style
		if character_context.has("style") and character_context.style is Dictionary:
			var style_parts: Array[String] = []
			for key in character_context.style:
				style_parts.append(key + ": " + str(character_context.style[key]))
			if style_parts.size() > 0:
				context_lines.append("- Style: " + ", ".join(style_parts))
		
		# Stats
		if character_context.has("stats") and character_context.stats is Dictionary:
			var stats_parts: Array[String] = []
			for key in character_context.stats:
				stats_parts.append(key + ": " + str(character_context.stats[key]))
			if stats_parts.size() > 0:
				context_lines.append("- Current Stats: " + ", ".join(stats_parts))
		
		# Character book entries (simplified - just mention if present)
		if character_context.has("has_book") and character_context.has_book:
			context_lines.append("- Character has knowledge lorebook available")
		
		context_lines.append("")
		context_lines.append("Narration should reflect this character's personality, traits, style, and current emotional state.")
		user_sections.append("\n".join(context_lines))
	
	user_sections.append("Respond with a valid JSON object matching the ResolutionEnvelope format.")
	
	var messages_d: Array[Dictionary] = [
		{"role": "system", "content": templates.get_director_system_prompt()},
		{"role": "user", "content": "\n\n".join(user_sections)}
	]
	return injection_manager.apply_layers("director", messages_d, {"action": action, "scene": scene, "character_context": character_context}, injection_layers)

# Build NPC dialog prompt when player talks to an NPC
func build_npc_prompt(action: ActionRequest, scene: SceneGraph, character: CharacterProfile) -> Array[Dictionary]:
	var scene_info = {
		"scene_id": scene.scene_id,
		"description": scene.description,
		"entities": _serialize_entities(scene.entities),
		"rules": scene.rules
	}

	var player_text := str(action.context.get("utterance", ""))
	var chat_snapshot := _build_chat_snapshot()

	# Build macro context for safe expansion
	var macro_ctx: Dictionary = {}
	macro_ctx["user_name"] = str(world_db.flags.get("player_name", "You"))
	macro_ctx["character_name"] = character.name
	macro_ctx["char_name"] = character.name
	macro_ctx["char_description"] = character.description
	macro_ctx["char_personality"] = character.personality
	macro_ctx["mes_examples"] = character.mes_example
	macro_ctx["char_version"] = character.character_version
	macro_ctx["scene_description"] = str(scene_info.get("description", ""))
	macro_ctx["vars_local"] = world_db.flags.get("vars_local", {})
	macro_ctx["vars_global"] = world_db.flags.get("vars_global", {})
	# Recent chat-derived values
	var last_msg := ""
	if chat_snapshot.has("recent_messages") and chat_snapshot.recent_messages is Array and chat_snapshot.recent_messages.size() > 0:
		last_msg = str(chat_snapshot.recent_messages[chat_snapshot.recent_messages.size() - 1].get("text", ""))
	macro_ctx["last_message"] = last_msg
	# Last user message
	var last_user := ""
	if chat_snapshot.has("recent_messages") and chat_snapshot.recent_messages is Array:
		for i in range(chat_snapshot.recent_messages.size() - 1, -1, -1):
			var m = chat_snapshot.recent_messages[i]
			if m.get("event", "") == "player_text":
				last_user = str(m.get("text", ""))
				break
	macro_ctx["last_user_message"] = last_user
	# Last char message (fallback to stored flag)
	macro_ctx["last_char_message"] = str(world_db.flags.get("last_npc_line", ""))

	# Build messages via shared PromptAssembler (ST card support)
	var messages_npc: Array[Dictionary] = PromptAssemblerScript.build_npc_messages(
		character,
		player_text,
		scene_info,
		chat_snapshot,
		templates.get_npc_system_prompt(),
		macro_ctx
	)
	# Apply character-specific post-history instructions, if present, as a per-call IN_CHAT layer
	var layers := injection_layers.duplicate()
	if typeof(character.post_history_instructions) == TYPE_STRING and character.post_history_instructions.strip_edges() != "":
		var L = PromptInjectionManagerScript.LayerDef
		var P = PromptInjectionManagerScript.Position
		var ph := L.new()
		ph.id = "card.post_history_instructions:" + character.name
		ph.scope = "npc"
		ph.position = P.IN_CHAT   # ensures it comes after the user/history payload
		ph.role = "system"
		ph.priority = 50
		ph.enabled = true
		ph.content = MacroExpander.expand(character.post_history_instructions.strip_edges(), macro_ctx)
		layers.append(ph)
	return injection_manager.apply_layers("npc", messages_npc, {"action": action, "scene": scene, "character": character}, layers)

# Build a prompt to interpret freeform player input and resolve it
func build_freeform_prompt(scene: SceneGraph, player_text: String) -> Array[Dictionary]:
	var scene_info = {
		"scene_id": scene.scene_id,
		"description": scene.description,
		"entities": _serialize_entities(scene.entities),
		"rules": scene.rules
	}
	# Build a chat snapshot from recent world history so the model can infer implied addresses
	var chat_snapshot = _build_chat_snapshot()

	var instructions = templates.get_freeform_system_prompt()
	var messages_ff: Array[Dictionary] = [
		{"role": "system", "content": instructions},
		{"role": "user", "content": JSON.stringify({
			"scene": scene_info,
			"chat_snapshot": chat_snapshot,
			"player_text": player_text
		}, "\t")}
	]
	return injection_manager.apply_layers("freeform", messages_ff, {"scene": scene, "player_text": player_text}, injection_layers)

## Build a compact snapshot of recent dialog/narration for context-aware prompts
func _build_chat_snapshot() -> Dictionary:
	var recent: Array[Dictionary] = []
	var max_messages = 12
	for i in range(world_db.history.size() - 1, -1, -1):
		var h = world_db.history[i]
		if not (h is Dictionary):
			continue
		var ev = str(h.get("event", ""))
		if ev == "narration" or ev == "player_text":
			# Prepend by inserting at 0 to keep chronological order
			recent.insert(0, {
				"event": ev,
				"style": h.get("style", ""),
				"speaker": h.get("speaker", ""),
				"text": h.get("text", "")
			})
			if recent.size() >= max_messages:
				break
	return {
		"recent_messages": recent,
		"last_npc_speaker": world_db.flags.get("last_npc_speaker", ""),
		"last_npc_line": world_db.flags.get("last_npc_line", ""),
		"last_player_line": world_db.flags.get("last_player_line", "")
	}

func process_action(action: ActionRequest, character_context: Dictionary = {}) -> ResolutionEnvelope:
	var scene = world_db.get_scene(action.scene)
	if not scene:
		push_error("Scene not found: " + action.scene)
		return _create_error_envelope("Scene not found")
	
	# Branch: NPC dialog
	var target_entity := scene.get_entity(action.target)
	var actor_entity := scene.get_entity(action.actor)
	# Player addressing an NPC
	if action.actor == "player" and action.verb == "talk" and target_entity and target_entity.type_name == "npc":
		var target_character = world_db.get_character(action.target)
		if target_character:
			var npc_messages = build_npc_prompt(action, scene, target_character)
			var npc_response = await _make_llm_request(npc_messages, _resolution_envelope_schema(), {"source": "npc", "npc_id": action.target})
			if npc_response != "":
				var npc_envelope = _parse_response(npc_response)
				# Ensure speaker/style are set correctly
				if npc_envelope.narration.size() > 0:
					npc_envelope.narration[0].style = "npc"
					npc_envelope.narration[0].speaker = action.target
				return npc_envelope
			return _create_error_envelope("Empty NPC response")
	# NPC taking a talk action (NPC's turn)
	elif action.verb == "talk" and actor_entity and actor_entity.type_name == "npc":
		var actor_character = world_db.get_character(action.actor)
		if actor_character:
			var npc_messages_actor = build_npc_prompt(action, scene, actor_character)
			var npc_response_actor = await _make_llm_request(npc_messages_actor, _resolution_envelope_schema(), {"source": "npc", "npc_id": action.actor})
			if npc_response_actor != "":
				var npc_envelope_actor = _parse_response(npc_response_actor)
				if npc_envelope_actor.narration.size() > 0:
					npc_envelope_actor.narration[0].style = "npc"
					npc_envelope_actor.narration[0].speaker = action.actor
				return npc_envelope_actor
			return _create_error_envelope("Empty NPC response")

	# Build full character context if actor is an NPC
	var full_context = character_context.duplicate()
	if action.actor != "player":
		var character = world_db.get_character(action.actor)
		if character:
			full_context["name"] = character.name
			full_context["description"] = character.description
			full_context["personality"] = character.personality
			full_context["traits"] = character.traits
			full_context["style"] = character.style
			full_context["stats"] = character.stats
			full_context["has_book"] = character.character_book != null
			
			# Include character book content if available (simplified for now)
			if character.character_book:
				var book_summary = _summarize_character_book(character.character_book)
				if book_summary != "":
					full_context["book_summary"] = book_summary
	
	var messages = build_director_prompt(action, scene, full_context)
	var response_text = await _make_llm_request(messages, _resolution_envelope_schema(), {"source": "director"})
	
	if response_text == "":
		return _create_error_envelope("LLM request failed")
	
	return _parse_response(response_text)

## Summarize character book for prompt inclusion
func _summarize_character_book(book: CharacterBook) -> String:
	if not book or book.entries.is_empty():
		return ""
	
	var enabled = book.get_enabled_entries()
	if enabled.is_empty():
		return ""
	
	var summaries: Array[String] = []
	for entry in enabled:
		if entry.content != "":
			summaries.append(entry.content)
	
	if summaries.size() > 0:
		return "\n".join(summaries)
	return ""

func process_narrator_request(context: Dictionary, image: Image = null) -> String:
	var messages = build_narrator_prompt(context, image)
	var response_text = await _make_llm_request(messages, {}, {"source": "narrator"})
	return response_text

static func _apply_character_system_prompt(character: CharacterProfile, original_template: String) -> String:
	var card_prompt := ""
	if character and typeof(character.system_prompt) == TYPE_STRING:
		card_prompt = character.system_prompt
	if card_prompt.strip_edges() == "":
		return original_template
	# Support placeholder merge
	return card_prompt.replace("{{original}}", original_template)

func _make_llm_request(messages: Array[Dictionary], json_schema: Dictionary = {}, meta: Dictionary = {}) -> String:
	return await llm_client.make_request(messages, "", json_schema, meta)

func process_freeform_input(scene: SceneGraph, player_text: String) -> ResolutionEnvelope:
	var messages = build_freeform_prompt(scene, player_text)
	var response_text = await _make_llm_request(messages, _resolution_envelope_schema(), {"source": "director", "npc_hint": world_db.flags.get("last_npc_speaker", "")})
	if response_text == "":
		return _create_error_envelope("LLM request failed")
	return _parse_response(response_text)

## Remove meta-thought tags and code fences from model output
static func _sanitize_llm_text(text: String) -> String:
	var out := text
	# Strip common code fences
	out = out.replace("```json", "")
	out = out.replace("```JSON", "")
	out = out.replace("```", "")
	# Strip leading/trailing whitespace early
	out = out.strip_edges()
	# Remove <think>...</think> and <thinking>...</thinking> blocks (can appear multiple times)
	var open_close_pairs := [
		["<think>", "</think>"],
		["<thinking>", "</thinking>"]
	]
	for pair in open_close_pairs:
		var open_tag: String = pair[0]
		var close_tag: String = pair[1]
		while true:
			var s := out.find(open_tag)
			if s == -1:
				break
			var e := out.find(close_tag, s + open_tag.length())
			if e == -1:
				# No closing tag; drop the opening tag only
				out = out.substr(0, s) + out.substr(s + open_tag.length())
				break
			out = out.substr(0, s) + out.substr(e + close_tag.length())
		out = out.strip_edges()
	return out

## Extract the first top-level JSON object from arbitrary text
static func _extract_first_json_object(text: String) -> String:
	var s := text
	var start := -1
	var depth := 0
	var in_string := false
	var escape_next := false
	for i in s.length():
		var ch := s[i]
		if start == -1:
			if ch == '{':
				start = i
				depth = 1
				in_string = false
				escape_next = false
			continue
		# After we've started scanning an object
		if in_string:
			if escape_next:
				escape_next = false
			elif ch == '\\':
				escape_next = true
			elif ch == '"':
				in_string = false
		else:
			if ch == '"':
				in_string = true
			elif ch == '{':
				depth += 1
			elif ch == '}':
				depth -= 1
				if depth == 0:
					var end_inclusive := i
					return s.substr(start, end_inclusive - start + 1)
	return ""


func _parse_response(json_text: String) -> ResolutionEnvelope:
	# Clean known wrappers and extract the first JSON object if extra text exists
	var cleaned := _sanitize_llm_text(json_text)
	var candidate := _extract_first_json_object(cleaned)
	var to_parse := candidate if candidate != "" else cleaned
	var json = JSON.new()
	var parse_error = json.parse(to_parse)
	if parse_error != OK:
		push_error("Failed to parse LLM response: " + json_text)
		if llm_client and llm_client.settings and llm_client.settings.debug_trace:
			print("*** LLM PARSE ERROR INPUT ***")
			print(json_text)
		return _create_error_envelope("Invalid JSON response")
	
	var data = json.data
	var envelope = ResolutionEnvelope.new()
	
	# Parse narration
	if data.has("narration") and data.narration is Array:
		for narr_data in data.narration:
			var narr = NarrationEvent.new()
			var style_val = narr_data.get("style", "world")
			if typeof(style_val) != TYPE_STRING:
				style_val = "world"
			narr.style = style_val
			var text_val = narr_data.get("text", "")
			if typeof(text_val) != TYPE_STRING:
				text_val = ""
			narr.text = text_val
			var speaker_val = narr_data.get("speaker", "")
			if typeof(speaker_val) != TYPE_STRING:
				speaker_val = ""
			narr.speaker = speaker_val
			envelope.narration.append(narr)
	
	# Parse patches
	if data.has("patches") and data.patches is Array:
		var patch_list: Array[Dictionary] = []
		for patch in data.patches:
			if patch is Dictionary:
				patch_list.append(patch)
			envelope.patches = patch_list
	
	# Parse UI choices
	if data.has("ui_choices") and data.ui_choices is Array:
		for choice_data in data.ui_choices:
			var choice = UIChoice.new()
			choice.verb = choice_data.get("verb", "")
			choice.target = choice_data.get("target", "")
			choice.label = choice_data.get("label", "")
			envelope.ui_choices.append(choice)
	
	# Parse commands (engine-handled operations)
	if data.has("commands") and data.commands is Array:
		var out_cmds: Array[Dictionary] = []
		for cmd in data.commands:
			if cmd is Dictionary:
				out_cmds.append(cmd)
			envelope.commands = out_cmds
	
	return envelope

func _serialize_entities(entities: Array[Entity]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entity in entities:
		result.append({
			"id": entity.id,
			"type_name": entity.type_name,
			"verbs": entity.verbs,
			"tags": entity.tags,
			"props": entity.props
		})
	return result

func _create_error_envelope(message: String) -> ResolutionEnvelope:
	var envelope = ResolutionEnvelope.new()
	var narr = NarrationEvent.new()
	narr.style = "world"
	narr.text = "[Error: " + message + "]"
	envelope.narration.append(narr)
	return envelope

## JSON Schema for enforcing structured outputs from the LLM
func _resolution_envelope_schema() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"narration": {
				"type": "array",
				"items": {
					"type": "object",
					"properties": {
						"style": {"type": "string", "enum": ["world", "npc"]},
						"text": {"type": "string"},
						"speaker": {
							"anyOf": [
								{"type": "string"},
								{"type": "null"}
							]
						}
					},
					"required": ["style", "text", "speaker"],
					"additionalProperties": false
				}
			},
			"patches": {
				"type": "array",
				"items": {
					"type": "object",
					"properties": {
						"op": {"type": "string"},
						"path": {"type": "string"},
						"value": {
							"anyOf": [
								{"type": "string"},
								{"type": "number"},
								{"type": "boolean"},
								{"type": "object"},
								{"type": "array"},
								{"type": "null"}
							]
						}
					},
					"required": ["op", "path", "value"],
					"additionalProperties": false
				}
			},
			"ui_choices": {
				"type": "array",
				"items": {
					"type": "object",
					"properties": {
						"verb": {"type": "string"},
						"target": {"type": "string"},
						"label": {"type": "string"}
					},
					"required": ["verb", "target", "label"],
					"additionalProperties": false
				}
			},
			"commands": {
				"type": "array",
				"items": {
					"type": "object",
					"properties": {
						"type": {"type": "string", "enum": ["transfer"]},
						"from": {"type": "string"},
						"to": {"type": "string"},
						"item": {"type": "string"},
						"quantity": {"type": "number"}
					},
					"required": ["type", "from", "to", "item"],
					"additionalProperties": false
				}
			}
		},
		"required": ["narration", "patches", "ui_choices"],
		"additionalProperties": false
	}
