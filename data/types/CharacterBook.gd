extends Resource
class_name CharacterBook

## Character-specific lorebook that stacks above world book
## Mirrors CC_v2 character_book semantics

@export var name: String = ""
@export var description: String = ""
@export var scan_depth: int = 32
@export var token_budget: int = 1024
@export var recursive_scanning: bool = false
@export var extensions: Dictionary = {}
@export var entries: Array[CharacterBookEntry] = []

# Optional CC_v2 fields
@export var case_sensitive: bool = false
@export var priority: int = 0
@export var id: String = ""
@export var comment: String = ""

func _init():
	if extensions.is_empty():
		extensions = {}
	if entries.is_empty():
		entries = []

## Get enabled entries sorted by insertion_order
func get_enabled_entries() -> Array[CharacterBookEntry]:
	var enabled: Array[CharacterBookEntry] = []
	for entry in entries:
		if entry.enabled:
			enabled.append(entry)
	enabled.sort_custom(func(a, b): return a.insertion_order < b.insertion_order)
	return enabled

## Find entries matching keywords
func find_entries_by_keys(keywords: Array[String]) -> Array[CharacterBookEntry]:
	var result: Array[CharacterBookEntry] = []
	var enabled = get_enabled_entries()
	
	for entry in enabled:
		for keyword in keywords:
			var keyword_lower = keyword.to_lower() if not case_sensitive else keyword
			for key in entry.keys:
				var key_lower = key.to_lower() if not case_sensitive else key
				if key_lower.contains(keyword_lower) or keyword_lower.contains(key_lower):
					if not entry in result:
						result.append(entry)
					break
	
	return result

