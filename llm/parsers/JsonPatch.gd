extends RefCounted
class_name JsonPatch

## Apply JSON Patch operations to dictionaries
## Supports: replace, add, remove

static func apply_patch(target: Dictionary, patch: Dictionary) -> bool:
	var op = patch.get("op", "")
	var path = patch.get("path", "")
	
	if path.begins_with("/"):
		path = path.substr(1)
	
	var path_parts = path.split("/")
	var current = target
	
	# Navigate to parent of target
	for i in range(path_parts.size() - 1):
		var part = path_parts[i]
		if not current.has(part):
			if op == "add":
				current[part] = {}
			else:
				push_error("JsonPatch: Path not found: " + path)
				return false
		current = current[part]
	
	var key = path_parts[path_parts.size() - 1]
	
	match op:
		"replace":
			if not current.has(key):
				push_error("JsonPatch: Key not found for replace: " + path)
				return false
			current[key] = patch.get("value")
			return true
		"add":
			current[key] = patch.get("value")
			return true
		"remove":
			if not current.has(key):
				push_error("JsonPatch: Key not found for remove: " + path)
				return false
			current.erase(key)
			return true
		_:
			push_error("JsonPatch: Unknown operation: " + op)
			return false

static func apply_patches(target: Dictionary, patches: Array) -> int:
	var applied = 0
	for patch in patches:
		if patch is Dictionary:
			if apply_patch(target, patch):
				applied += 1
	return applied
