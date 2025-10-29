extends RefCounted
class_name Narrator

## Text voice formatting and styles

static func format_narration(text: String, style: String = "world") -> String:
	match style:
		"world":
			return "[color=#aaaaaa]" + text + "[/color]"
		"npc":
			return "[color=#4a9eff]" + text + "[/color]"
		"player":
			return "[color=#ffffff]" + text + "[/color]"
		_:
			return text

static func add_entity_tags(text: String, entities: Dictionary) -> String:
	var result = text
	for entity_id in entities.keys():
		var tag = "[" + entity_id + "]"
		if result.contains(tag):
			# Make it clickable (will be handled by UI)
			result = result.replace(tag, "[url=" + entity_id + "]" + tag + "[/url]")
	return result

