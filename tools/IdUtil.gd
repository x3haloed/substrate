extends RefCounted
class_name IdUtil

## Shared ID normalizer: lowercase, spaces->underscore, strip non [a-z0-9_],
## collapse multiple underscores, and trim leading/trailing underscores.

static func normalize_id(text: String) -> String:
	if typeof(text) != TYPE_STRING:
		return ""
	var s := text.strip_edges().to_lower()
	# Replace all whitespace with underscore
	var rx_space := RegEx.new()
	if rx_space.compile("\\s+") == OK:
		s = rx_space.sub(s, "_", true)
	# Remove invalid characters
	var rx_bad := RegEx.new()
	if rx_bad.compile("[^a-z0-9_]") == OK:
		s = rx_bad.sub(s, "", true)
	# Collapse multiple underscores
	var rx_multi := RegEx.new()
	if rx_multi.compile("_+") == OK:
		s = rx_multi.sub(s, "_", true)
	# Trim leading/trailing underscores
	while s.begins_with("_"):
		s = s.substr(1)
	while s.ends_with("_"):
		s = s.substr(0, max(0, s.length() - 1))
	if s == "":
		return "id"
	return s

static func normalize_ref_token(token: String) -> String:
	# For tokens like "discover:<id>" or "lore:<id>", normalize the <id> part.
	if typeof(token) != TYPE_STRING:
		return ""
	var t := token.strip_edges()
	var idx := t.find(":")
	if idx <= 0:
		return normalize_id(t)
	var kind := t.substr(0, idx)
	var value := t.substr(idx + 1)
	return kind + ":" + normalize_id(value)
