extends Resource
class_name LoreDB

## Global registry for lore entries, enabling scene-agnostic lookup.

@export var entries: Dictionary = {}  # entry_id -> Resource path or LoreEntry

var _cache: Dictionary = {}  # entry_id -> LoreEntry

func get_entry(entry_id: String) -> LoreEntry:
	if entry_id == "":
		return null
	if _cache.has(entry_id):
		return _cache[entry_id]
	if not entries.has(entry_id):
		return null
	var stored = entries[entry_id]
	var entry: LoreEntry = null
	match typeof(stored):
		TYPE_STRING:
			entry = load(stored) as LoreEntry
		TYPE_OBJECT:
			if stored is LoreEntry:
				entry = stored
		_:
			entry = null
	if entry:
		_cache[entry_id] = entry
	return entry

func register_entry(entry: LoreEntry, entry_resource_path: String = "") -> void:
	if entry == null:
		return
	if entry.entry_id == "":
		push_warning("LoreEntry missing entry_id; unable to register.")
		return
	if entry_resource_path != "":
		entries[entry.entry_id] = entry_resource_path
	else:
		entries[entry.entry_id] = entry
	_cache[entry.entry_id] = entry

func ensure_entry(entry_id: String, defaults: Dictionary = {}) -> LoreEntry:
	var existing := get_entry(entry_id)
	if existing:
		return existing
	if entry_id == "":
		return null
	var entry := LoreEntry.new()
	entry.entry_id = entry_id
	if defaults.has("title"):
		entry.title = str(defaults.title)
	if defaults.has("category"):
		entry.category = str(defaults.category)
	if defaults.has("summary"):
		entry.summary = str(defaults.summary)
	if defaults.has("article"):
		entry.article = str(defaults.article)
	if defaults.has("related_entity_ids") and defaults.related_entity_ids is Array:
		entry.related_entity_ids = defaults.related_entity_ids.duplicate()
	if defaults.has("default_visibility"):
		entry.default_visibility = str(defaults.default_visibility)
	if defaults.has("unlock_conditions") and defaults.unlock_conditions is Array:
		entry.unlock_conditions = defaults.unlock_conditions.duplicate()
	if defaults.has("tags") and defaults.tags is Array:
		entry.tags = defaults.tags.duplicate()
	register_entry(entry)
	return entry

func clear_cache() -> void:
	_cache.clear()

func list_entries() -> Array[LoreEntry]:
	var result: Array[LoreEntry] = []
	for entry_id in entries.keys():
		var entry := get_entry(entry_id)
		if entry:
			result.append(entry)
	return result

func find_entries_by_tag(tag: String) -> Array[LoreEntry]:
	var normalized := tag.strip_edges().to_lower()
	if normalized == "":
		return []
	var matches: Array[LoreEntry] = []
	for entry in list_entries():
		for t in entry.tags:
			if str(t).to_lower() == normalized:
				matches.append(entry)
				break
	return matches
