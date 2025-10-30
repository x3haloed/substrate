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

Given an ActionRequest, respond with a JSON object containing:
{
  "narration": [{"style": "world", "text": "..."}],
  "patches": [{"op": "replace", "path": "/entities/{id}/props/{key}", "value": "..."}],
  "ui_choices": [{"verb": "...", "target": "...", "label": "..."}]
}

Rules:
- Only include verbs available in the current scene
- Patches must follow JSON Patch format
- Narration should reflect the action's consequences"""

func _init(p_llm_client: LLMClient, p_world_db: WorldDB):
	llm_client = p_llm_client
	world_db = p_world_db

func build_narrator_prompt(scene_context: Dictionary) -> Array[Dictionary]:
	var brief := format_scene_brief(scene_context)
	return [
		{"role": "system", "content": NARRATOR_SYSTEM_PROMPT + "\n\n" + "Respond only with prose. Do not output JSON or code fences."},
		{"role": "user", "content": "Scene brief:\n" + brief + "\n\nWrite a concise atmospheric paragraph (3-5 sentences)."}
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

func process_action(action: ActionRequest, character_context: Dictionary = {}) -> ResolutionEnvelope:
	var scene = world_db.get_scene(action.scene)
	if not scene:
		push_error("Scene not found: " + action.scene)
		return _create_error_envelope("Scene not found")
	
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
	var response_text = await _make_llm_request(messages, true)
	
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
	var response_text = await _make_llm_request(messages, false)
	return response_text

func _make_llm_request(messages: Array[Dictionary], expect_json: bool = false) -> String:
	return await llm_client.make_request(messages, "", expect_json)

func _parse_response(json_text: String) -> ResolutionEnvelope:
	var json = JSON.new()
	var parse_error = json.parse(json_text)
	if parse_error != OK:
		push_error("Failed to parse LLM response: " + json_text)
		return _create_error_envelope("Invalid JSON response")
	
	var data = json.data
	var envelope = ResolutionEnvelope.new()
	
	# Parse narration
	if data.has("narration") and data.narration is Array:
		for narr_data in data.narration:
			var narr = NarrationEvent.new()
			narr.style = narr_data.get("style", "world")
			narr.text = narr_data.get("text", "")
			narr.speaker = narr_data.get("speaker", "")
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
