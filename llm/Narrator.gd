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


## Naive post-processing to bracket entity IDs mentioned in text.
## For each entity id provided, wraps standalone occurrences with [brackets].
## Skips words that are already bracketed like [barkeep]. Case-insensitive.
static func auto_tag_entities(text: String, entity_ids: Array[String]) -> String:
	var result: String = text
	if entity_ids.is_empty():
		return result

	for raw_id in entity_ids:
		var entity_id: String = str(raw_id)
		if entity_id == "":
			continue
		
		var re := RegEx.new()
		# Match standalone word (case-insensitive). Avoid manual escaping since IDs are simple.
		var err := re.compile("(?i)\\b" + entity_id + "\\b")
		if err != OK:
			continue
		
		# Replace from end to start to keep indices stable
		var matches := re.search_all(result)
		if matches.is_empty():
			continue
		for i in range(matches.size() - 1, -1, -1):
			var m: RegExMatch = matches[i]
			var start_i: int = m.get_start()
			var end_i: int = m.get_end()
			
			# Skip if already bracketed as [word]
			var before_char := result.substr(start_i - 1, 1) if start_i > 0 else ""
			var after_char := result.substr(end_i, 1) if end_i < result.length() else ""
			if before_char == "[" and after_char == "]":
				continue
			
			var word := result.substr(start_i, end_i - start_i)
			result = result.substr(0, start_i) + "[" + word + "]" + result.substr(end_i)

	return result
