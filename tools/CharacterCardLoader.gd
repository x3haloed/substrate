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
	return import_from_json_text(json_text)

## Import from a raw JSON string
static func import_from_json_text(json_text: String) -> CharacterProfile:
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
	# Populate typed arrays to satisfy Array[String] constraints
	profile.alternate_greetings.clear()
	if card_data.has("alternate_greetings") and card_data.alternate_greetings is Array:
		for g in card_data.alternate_greetings:
			if g is String:
				profile.alternate_greetings.append(g)
			else:
				profile.alternate_greetings.append(str(g))
	profile.tags.clear()
	if card_data.has("tags") and card_data.tags is Array:
		for t in card_data.tags:
			if t is String:
				profile.tags.append(t)
			else:
				profile.tags.append(str(t))
	profile.creator = card_data.get("creator", "")
	profile.character_version = card_data.get("character_version", "1.0")
	# Character book (V2 only)
	if card_data.has("character_book") and card_data.character_book is Dictionary:
		profile.character_book = _import_character_book(card_data.character_book)
	# Stats and traits (not in CC spec, initialize empty/typed)
	profile.stats = {}
	profile.traits.clear()
	if card_data.has("traits") and card_data.traits is Array:
		for trait_value in card_data.traits:
			profile.traits.append(str(trait_value))
	profile.style = {}
	profile.triggers.clear()
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

## Import a CC v2 PNG with embedded base64 JSON under the "Chara" metadata
static func import_from_png(png_path: String) -> CharacterProfile:
	var bytes := FileAccess.get_file_as_bytes(png_path)
	if bytes.is_empty():
		push_error("Failed to read PNG: " + png_path)
		return null
	var maybe_b64 := _extract_chara_from_png(bytes)
	if maybe_b64 == "":
		push_error("PNG does not contain 'Chara' metadata: " + png_path)
		return null
	var json_text := ""
	# "Chara" contains base64-encoded JSON string per spec
	var decoded := Marshalls.base64_to_raw(maybe_b64)
	if decoded.is_empty():
		push_error("Failed to base64-decode 'Chara' metadata")
		return null
	json_text = decoded.get_string_from_utf8()
	var profile := import_from_json_text(json_text)
	if profile == null:
		return null
	# Load image and set as portrait; re-encoding strips metadata
	var img := Image.new()
	var err := img.load(png_path)
	if err != OK:
		push_error("Failed to load PNG image pixels: " + png_path)
		return null
	var tex := ImageTexture.create_from_image(img)
	profile.set_portrait_texture(tex)
	return profile

## Parse PNG chunks and extract Chara payload from tEXt/iTXt/zTXt (case-insensitive key)
static func _extract_chara_from_png(bytes: PackedByteArray) -> String:
	# Validate PNG signature
	if bytes.size() < 8:
		return ""
	var sig := PackedByteArray([137,80,78,71,13,10,26,10])
	for i in range(8):
		if bytes[i] != sig[i]:
			return ""
	var pos := 8
	while pos + 8 <= bytes.size():
		var length := int(bytes[pos]) << 24 | int(bytes[pos+1]) << 16 | int(bytes[pos+2]) << 8 | int(bytes[pos+3])
		var type_str := String.chr(bytes[pos+4]) + String.chr(bytes[pos+5]) + String.chr(bytes[pos+6]) + String.chr(bytes[pos+7])
		var data_start := pos + 8
		var data_end := data_start + length
		if data_end + 4 > bytes.size():
			break
		var chunk_data := bytes.slice(data_start, data_end)
		# tEXt: keyword\0text
		if type_str == "tEXt":
			var sep := chunk_data.find(0)
			if sep != -1:
				var key := chunk_data.slice(0, sep).get_string_from_ascii()
				var val := chunk_data.slice(sep+1, chunk_data.size()).get_string_from_ascii()
				if key.to_lower() == "chara":
					return val
		# zTXt: keyword\0compression_method(1) + compressed text
		elif type_str == "zTXt":
			var sepz := chunk_data.find(0)
			if sepz != -1 and sepz + 1 < chunk_data.size():
				var keyz := chunk_data.slice(0, sepz).get_string_from_ascii()
				var comp_method := chunk_data[sepz+1]
				var comp_data := chunk_data.slice(sepz+2, chunk_data.size())
				if keyz.to_lower() == "chara" and comp_method == 0:
					var decompressed := comp_data.decompress_dynamic(1)
					return decompressed.get_string_from_ascii()
		# iTXt: keyword\0comp_flag(1) comp_method(1) lang\0 transkey\0 text
		elif type_str == "iTXt":
			var p := 0
			var kw_end := chunk_data.find(0)
			if kw_end == -1: 
				pass
			else:
				var keyi := chunk_data.slice(0, kw_end).get_string_from_utf8()
				p = kw_end + 1
				if p + 2 > chunk_data.size():
					pass
				else:
					var comp_flag := int(chunk_data[p]); p += 1
					var comp_method_i := int(chunk_data[p]); p += 1
					# language tag
					var lang_end := chunk_data.find(0, p)
					if lang_end == -1: lang_end = p
					else: p = lang_end + 1
					# translated keyword
					var trans_end := chunk_data.find(0, p)
					if trans_end == -1: trans_end = p
					else: p = trans_end + 1
					var text_bytes := chunk_data.slice(p, chunk_data.size())
					if keyi.to_lower() == "chara":
						if comp_flag == 1 and comp_method_i == 0:
							var decomp := text_bytes.decompress_dynamic(1)
							return decomp.get_string_from_utf8()
						else:
							return text_bytes.get_string_from_utf8()
		# Move to next chunk (skip CRC)
		pos = data_end + 4
		if type_str == "IEND":
			break
	return ""

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

	# Populate typed arrays for keys/secondary_keys
	entry.keys.clear()
	if entry_data.has("keys") and entry_data.keys is Array:
		for k in entry_data.keys:
			entry.keys.append(str(k))
	entry.content = entry_data.get("content", "")
	entry.enabled = entry_data.get("enabled", true)
	entry.insertion_order = entry_data.get("insertion_order", 0)
	entry.case_sensitive = entry_data.get("case_sensitive", false)
	entry.priority = entry_data.get("priority", 0)
	entry.id = entry_data.get("id", "")
	entry.comment = entry_data.get("comment", "")
	entry.selective = entry_data.get("selective", false)
	entry.secondary_keys.clear()
	if entry_data.has("secondary_keys") and entry_data.secondary_keys is Array:
		for sk in entry_data.secondary_keys:
			entry.secondary_keys.append(str(sk))
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
