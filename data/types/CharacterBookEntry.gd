extends Resource
class_name CharacterBookEntry

## Single entry in a CharacterBook
## Mirrors CC_v2 character_book entry semantics

@export var keys: Array[String] = []
@export var content: String = ""
@export var extensions: Dictionary = {}
@export var enabled: bool = true
@export var insertion_order: int = 0

# Optional CC_v2 fields
@export var case_sensitive: bool = false
@export var priority: int = 0
@export var id: String = ""
@export var comment: String = ""
@export var selective: bool = false
@export var secondary_keys: Array[String] = []
@export var constant: bool = false
@export var position: String = "before_char"  # before_char, after_char

func _init():
	if extensions.is_empty():
		extensions = {}
	if keys.is_empty():
		keys = []
	if secondary_keys.is_empty():
		secondary_keys = []

## Check if entry matches a keyword
func matches_keyword(keyword: String, case_sensitive_override: bool = false) -> bool:
	var keyword_check = keyword if (case_sensitive or case_sensitive_override) else keyword.to_lower()
	
	for key in keys:
		var key_check = key if (case_sensitive or case_sensitive_override) else key.to_lower()
		if key_check.contains(keyword_check) or keyword_check.contains(key_check):
			return true
	
	for key in secondary_keys:
		var key_check = key if (case_sensitive or case_sensitive_override) else key.to_lower()
		if key_check.contains(keyword_check) or keyword_check.contains(keyword_check):
			return true
	
	return false

