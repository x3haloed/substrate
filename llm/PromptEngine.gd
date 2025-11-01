extends RefCounted
class_name PromptEngine

## Builds prompts, parses JSON, hot-reload capable

var llm_client: LLMClient
var world_db: WorldDB

const NARRATOR_SYSTEM_PROMPT = """You are the Narrator, the invisible voice of the world. You describe scenes, state changes, and consequences in evocative prose. You do not speak as a character or DM—you are the world itself.

Guidelines:
- Write in third person, present tense
- Be concise but atmospheric
- Highlight sensory details
- When state changes occur, describe them naturally
- Never break character or address the player directly"""

const DIRECTOR_SYSTEM_PROMPT = """You are the Director, arbitrating actions and maintaining world consistency. You resolve player actions, enforce scene rules, and update world state.

Respond with a JSON object with these fields:
{
  "narration": [{"style": "world", "text": "...", "speaker": ""}],
  "patches": [{"op": "replace", "path": "/entities/{id}/props/{key}", "value": "..."}],
  "commands": [{"type": "transfer", "from": "player|<entity_id>", "to": "<entity_id>", "item": "<entity_id>", "quantity": 1}],
  "ui_choices": [...]
}

Rules:
- Prefer engine-handled "commands" for inventory/ownership changes (e.g., give/take/transfer). Do NOT attempt to edit arrays like scene entities or contents directly via patches.
- Patches must modify only supported domains: /entities/{id}/props, /entities/{id}/state, /entities/{id}/lore and /characters/{id}/stats/.. (use op=add or replace appropriately).
- Keep narration concise and reflect consequences.
- Only offer verbs that are legal in scene for player actions.
"""

# Character dialog writer for NPCs
const NPC_SYSTEM_PROMPT = """You are a character dialog writer.
Your job is to write a single first-person reply as the specified character.

Output MUST be a JSON object matching this schema:
{
  "narration": [
	{"style": "npc", "speaker": "<target_entity_id>", "text": "<the character's spoken line only>"}
  ],
  "patches": [ {"op": "...", "path": "...", "value": ... } ]
}

Rules:
- Reply strictly in first-person as the character; no out-of-character commentary.
- Do not include world narration or stage directions; write only what the character says.
- Keep it concise and true to the character's personality, traits, and style.
- If relevant, you MAY include JSON patches to update state as consequences of speech or minor reactions.
- You MAY reference scene entities by their exact IDs in square brackets like [barkeep]; do not invent new IDs.
- Do NOT include code fences or any extra text outside the JSON object.
"""

func _init(p_llm_client: LLMClient, p_world_db: WorldDB):
	llm_client = p_llm_client
	world_db = p_world_db

func build_narrator_prompt(scene_context: Dictionary) -> Array[Dictionary]:
	var brief := format_scene_brief(scene_context)
	# Build recent chat snapshot to give narrator strong situational awareness
	var chat_snapshot = _build_chat_snapshot()
	var user_content = "Scene brief:\n" + brief + "\n\n" + "Recent chat snapshot:\n" + JSON.stringify(chat_snapshot, "\t") + "\n\nWrite a concise atmospheric paragraph (3-5 sentences)."
	return [
		{"role": "system", "content": NARRATOR_SYSTEM_PROMPT + "\n\n" + "Respond only with prose. Do not output JSON or code fences."},
		{"role": "user", "content": user_content}
	]

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
	
	var prompt = DIRECTOR_SYSTEM_PROMPT + "\n\n"
	prompt += "Current Scene:\n" + JSON.stringify(scene_info, "\t") + "\n\n"
	prompt += "Action Request:\n" + JSON.stringify(action_info, "\t") + "\n\n"
	
	# Add character context if actor is an NPC
	if character_context.size() > 0:
		prompt += "Actor Character Context:\n"
		
		# Character core
		if character_context.has("name"):
			prompt += "- Name: " + str(character_context.name) + "\n"
		if character_context.has("description"):
			prompt += "- Description: " + str(character_context.description) + "\n"
		if character_context.has("personality"):
			prompt += "- Personality: " + str(character_context.personality) + "\n"
		
		# Traits
		if character_context.has("traits") and character_context.traits is Array:
			if character_context.traits.size() > 0:
				prompt += "- Traits: " + ", ".join(character_context.traits) + "\n"
		
		# Style
		if character_context.has("style") and character_context.style is Dictionary:
			var style_parts: Array[String] = []
			for key in character_context.style:
				style_parts.append(key + ": " + str(character_context.style[key]))
			if style_parts.size() > 0:
				prompt += "- Style: " + ", ".join(style_parts) + "\n"
		
		# Stats
		if character_context.has("stats") and character_context.stats is Dictionary:
			var stats_parts: Array[String] = []
			for key in character_context.stats:
				stats_parts.append(key + ": " + str(character_context.stats[key]))
			if stats_parts.size() > 0:
				prompt += "- Current Stats: " + ", ".join(stats_parts) + "\n"
		
		# Character book entries (simplified - just mention if present)
		if character_context.has("has_book") and character_context.has_book:
			prompt += "- Character has knowledge lorebook available\n"
		
		prompt += "\nNarration should reflect this character's personality, traits, style, and current emotional state.\n\n"
	
	prompt += "Respond with a valid JSON object matching the ResolutionEnvelope format."
	
	return [
		{"role": "system", "content": prompt}
	]

# Build NPC dialog prompt when player talks to an NPC
func build_npc_prompt(action: ActionRequest, scene: SceneGraph, character: CharacterProfile) -> Array[Dictionary]:
	var scene_info = {
		"scene_id": scene.scene_id,
		"description": scene.description,
		"entities": _serialize_entities(scene.entities),
		"rules": scene.rules
	}

	var character_info = {
		"id": action.target,
		"name": character.name,
		"description": character.description,
		"personality": character.personality,
		"traits": character.traits,
		"style": character.style
	}

	var user_context: Dictionary = {
		"player_message": str(action.context.get("utterance", "")),
		"character": character_info,
		"scene": scene_info,
		"chat_snapshot": _build_chat_snapshot()
	}

	# Include brief character book if present
	if character.character_book:
		var summary = _summarize_character_book(character.character_book)
		if summary != "":
			user_context["lorebook_summary"] = summary

	return [
		{"role": "system", "content": NPC_SYSTEM_PROMPT},
		{"role": "user", "content": JSON.stringify(user_context, "\t")}
	]

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

	var instructions = """
You are the Director, arbitrating freeform player input without an addressed target.

Task:
- Decide if the player's text is dialog (a spoken line) or an action description.
- If dialog: pick the most appropriate NPC (by id in the scene) to react, or choose a world reaction if no NPC is appropriate.
- If action: interpret the player's intent as an ActionRequest (actor is player) and resolve it.
- Always reply with a valid ResolutionEnvelope JSON object: narration (npc or world), patches (if any), and ui_choices.

Rules:
- Maintain world consistency and scene rules.
- Prefer concise but evocative narration.
- Do not invent entity IDs; only use those present in the scene.
 - When the player's text looks like a reply and no addressee is explicit, prefer responding to last_npc_speaker from chat_snapshot.
"""
	return [
		{"role": "system", "content": instructions},
		{"role": "user", "content": JSON.stringify({
			"scene": scene_info,
			"chat_snapshot": chat_snapshot,
			"player_text": player_text
		}, "\t")}
	]

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
			var npc_response = await _make_llm_request(npc_messages, _resolution_envelope_schema())
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
			var npc_response_actor = await _make_llm_request(npc_messages_actor, _resolution_envelope_schema())
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
	var response_text = await _make_llm_request(messages, _resolution_envelope_schema())
	
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

func process_narrator_request(context: Dictionary) -> String:
	var messages = build_narrator_prompt(context)
	var response_text = await _make_llm_request(messages)
	return response_text

func _make_llm_request(messages: Array[Dictionary], json_schema: Dictionary = {}) -> String:
	return await llm_client.make_request(messages, "", json_schema)

func process_freeform_input(scene: SceneGraph, player_text: String) -> ResolutionEnvelope:
	var messages = build_freeform_prompt(scene, player_text)
	var response_text = await _make_llm_request(messages, _resolution_envelope_schema())
	if response_text == "":
		return _create_error_envelope("LLM request failed")
	return _parse_response(response_text)

func _parse_response(json_text: String) -> ResolutionEnvelope:
	var json = JSON.new()
	var parse_error = json.parse(json_text)
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
						"speaker": {"type": ["string", "null"]}
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
