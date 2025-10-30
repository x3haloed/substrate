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
	return [
		{"role": "system", "content": NARRATOR_SYSTEM_PROMPT},
		{"role": "user", "content": "Describe this scene: " + JSON.stringify(scene_context)}
	]

func build_director_prompt(action: ActionRequest, scene: SceneGraph, emotional_context: Dictionary = {}) -> Array[Dictionary]:
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
	
	# Add emotional context if actor is an NPC
	if emotional_context.size() > 0:
		action_info["emotional_state"] = emotional_context
	
	var prompt = DIRECTOR_SYSTEM_PROMPT + "\n\n"
	prompt += "Current Scene:\n" + JSON.stringify(scene_info, "\t") + "\n\n"
	prompt += "Action Request:\n" + JSON.stringify(action_info, "\t") + "\n\n"
	
	# Add emotional context guidance for NPCs
	if emotional_context.size() > 0:
		prompt += "Actor Emotional Context:\n"
		prompt += "- Mood: " + emotional_context.get("mood", "neutral") + "\n"
		prompt += "- Bond with player: " + str(emotional_context.get("bond", 0.5)) + "\n"
		prompt += "- Conviction: " + str(emotional_context.get("conviction", 0.5)) + "\n"
		if emotional_context.has("goals"):
			prompt += "- Goals: " + str(emotional_context.get("goals", [])) + "\n"
		prompt += "Narration should reflect this emotional state.\n\n"
	
	prompt += "Respond with a valid JSON object matching the ResolutionEnvelope format."
	
	return [
		{"role": "system", "content": prompt}
	]

func process_action(action: ActionRequest, emotional_context: Dictionary = {}) -> ResolutionEnvelope:
	var scene = world_db.get_scene(action.scene)
	if not scene:
		push_error("Scene not found: " + action.scene)
		return _create_error_envelope("Scene not found")
	
	var messages = build_director_prompt(action, scene, emotional_context)
	var response_text = await _make_llm_request(messages)
	
	if response_text == "":
		return _create_error_envelope("LLM request failed")
	
	return _parse_response(response_text)

func process_narrator_request(context: Dictionary) -> String:
	var messages = build_narrator_prompt(context)
	var response_text = await _make_llm_request(messages)
	return _extract_narration_text(response_text)

func _make_llm_request(messages: Array[Dictionary]) -> String:
	return await llm_client.make_request(messages)

func _extract_narration_text(raw_text: String) -> String:
	# Remove code fences if present
	var cleaned = _strip_code_fences(raw_text)
	var trimmed = cleaned.strip_edges()
	
	# Try to parse JSON-shaped responses and extract a narration field
	if trimmed.begins_with("{") or trimmed.begins_with("["):
		var json = JSON.new()
		var err = json.parse(trimmed)
		if err == OK:
			var data = json.data
			if data is Dictionary:
				if data.has("narrative"):
					return str(data.get("narrative"))
				if data.has("text"):
					return str(data.get("text"))
				if data.has("narration"):
					var narr_val = data.get("narration")
					if narr_val is String:
						return narr_val
					if narr_val is Array and narr_val.size() > 0:
						var first = narr_val[0]
						if first is Dictionary and first.has("text"):
							return str(first.get("text"))
			# If it's an array, just fall through and return cleaned text
	
	# Fallback: return the cleaned raw text
	return cleaned

func _strip_code_fences(text: String) -> String:
	var t = text.strip_edges()
	if t.begins_with("```"):
		var start = t.find("```")
		var end = t.rfind("```")
		if end > start:
			var inner = t.substr(start + 3, end - (start + 3))
			# Remove leading language hint if present (e.g., json, gdscript)
			inner = inner.strip_edges()
			if inner.begins_with("json") or inner.begins_with("JSON") or inner.begins_with("gdscript"):
				var nl = inner.find("\n")
				if nl != -1:
					inner = inner.substr(nl + 1)
			return inner.strip_edges()
	return t

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
