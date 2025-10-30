extends RefCounted
class_name CharacterCardLoader

## Imports Tavern Character Card V1/V2 JSON into Substrate CharacterProfile .tres format
## See substrate_card_v1.md for import mapping details

## Import a CC JSON file (V1 or V2) and return a CharacterProfile
static func import_from_json(json_path: String) -> CharacterProfile:
	var file = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("Failed to open JSON file: " + json_path)
		return null
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_error = json.parse(json_text)
	if parse_error != OK:
		push_error("Failed to parse JSON: " + json.get_error_message())
		return null
	
	var data = json.data
	if not data is Dictionary:
		push_error("JSON root must be a Dictionary")
		return null
	
	# Detect version
	var is_v2 = data.has("spec") and data.has("data")
	var card_data = data.get("data", data) if is_v2 else data
	
	var profile = CharacterProfile.new()
	
	# Set spec identity
	profile.spec = "substrate_card_v1"
	profile.spec_version = "1.0"
	
	# Core fields (direct mapping)
	profile.name = card_data.get("name", "")
	profile.description = card_data.get("description", "")
	profile.personality = card_data.get("personality", "")
	profile.first_mes = card_data.get("first_mes", "")
	profile.mes_example = card_data.get("mes_example", "")
	
	# Optional metadata (V2 only, defaults for V1)
	profile.creator_notes = card_data.get("creator_notes", "")
	profile.system_prompt = card_data.get("system_prompt", "{{original}}")
	profile.alternate_greetings = card_data.get("alternate_greetings", [])
	profile.tags = card_data.get("tags", [])
	profile.creator = card_data.get("creator", "")
	profile.character_version = card_data.get("character_version", "1.0")
	
	# Character book (V2 only)
	if card_data.has("character_book") and card_data.character_book is Dictionary:
		profile.character_book = _import_character_book(card_data.character_book)
	
	# Stats and traits (not in CC spec, initialize empty)
	profile.stats = {}
	profile.traits = []
	profile.style = {}
	profile.triggers = []
	
	# Extensions (preserve unknown keys)
	if card_data.has("extensions") and card_data.extensions is Dictionary:
		profile.extensions = card_data.extensions.duplicate()
	else:
		profile.extensions = {}
	
	# Also preserve top-level extensions if present
	if data.has("extensions") and data.extensions is Dictionary:
		for key in data.extensions:
			if not profile.extensions.has(key):
				profile.extensions[key] = data.extensions[key]
	
	return profile

## Import character book from CC V2 format
static func _import_character_book(book_data: Dictionary) -> CharacterBook:
	var book = CharacterBook.new()
	
	book.name = book_data.get("name", "")
	book.description = book_data.get("description", "")
	book.scan_depth = book_data.get("scan_depth", 32)
	book.token_budget = book_data.get("token_budget", 1024)
	book.recursive_scanning = book_data.get("recursive_scanning", false)
	book.case_sensitive = book_data.get("case_sensitive", false)
	book.priority = book_data.get("priority", 0)
	book.id = book_data.get("id", "")
	book.comment = book_data.get("comment", "")
	
	if book_data.has("extensions") and book_data.extensions is Dictionary:
		book.extensions = book_data.extensions.duplicate()
	else:
		book.extensions = {}
	
	# Import entries
	if book_data.has("entries") and book_data.entries is Array:
		for entry_data in book_data.entries:
			if entry_data is Dictionary:
				var entry = _import_book_entry(entry_data)
				if entry:
					book.entries.append(entry)
	
	return book

## Import a single book entry
static func _import_book_entry(entry_data: Dictionary) -> CharacterBookEntry:
	var entry = CharacterBookEntry.new()
	
	entry.keys = entry_data.get("keys", [])
	entry.content = entry_data.get("content", "")
	entry.enabled = entry_data.get("enabled", true)
	entry.insertion_order = entry_data.get("insertion_order", 0)
	entry.case_sensitive = entry_data.get("case_sensitive", false)
	entry.priority = entry_data.get("priority", 0)
	entry.id = entry_data.get("id", "")
	entry.comment = entry_data.get("comment", "")
	entry.selective = entry_data.get("selective", false)
	entry.secondary_keys = entry_data.get("secondary_keys", [])
	entry.constant = entry_data.get("constant", false)
	entry.position = entry_data.get("position", "before_char")
	
	if entry_data.has("extensions") and entry_data.extensions is Dictionary:
		entry.extensions = entry_data.extensions.duplicate()
	else:
		entry.extensions = {}
	
	return entry

## Save CharacterProfile to .tres file
static func save_profile(profile: CharacterProfile, output_path: String) -> bool:
	var error = ResourceSaver.save(profile, output_path)
	if error != OK:
		push_error("Failed to save CharacterProfile to " + output_path + ": " + str(error))
		return false
	print("CharacterProfile saved to: " + output_path)
	return true

## Import from JSON and save to .tres in one step
static func import_and_save(json_path: String, output_path: String) -> bool:
	var profile = import_from_json(json_path)
	if not profile:
		return false
	
	return save_profile(profile, output_path)

## Validate imported profile
static func validate_profile(profile: CharacterProfile) -> bool:
	if not profile.is_valid():
		push_error("Profile spec validation failed")
		return false
	
	if profile.name.is_empty():
		push_error("Profile name is required")
		return false
	
	if profile.description.is_empty():
		push_error("Profile description is required")
		return false
	
	if profile.personality.is_empty():
		push_error("Profile personality is required")
		return false
	
	if profile.first_mes.is_empty():
		push_error("Profile first_mes is required")
		return false
	
	if profile.mes_example.is_empty():
		push_error("Profile mes_example is required")
		return false
	
	return true

