extends RefCounted
class_name PathResolver

## Centralized helpers for resolving cartridge-relative and absolute asset paths.

static func resolve_world_base_path(world_db: WorldDB) -> String:
	if world_db == null:
		return ""
	# 1) Prefer explicit base provided in flags
	var base := str(world_db.flags.get("cartridge_base_path", ""))
	if base != "":
		return base
	# 2) Derive from any scene path in the world DB (…/scenes/<id>.tres → base)
	for sid in world_db.scenes.keys():
		var v = world_db.scenes[sid]
		if v is String:
			var dir := String(v).get_base_dir()
			if dir.ends_with("/scenes"):
				return dir.get_base_dir()
	# 3) Fallbacks based on cartridge_id
	var cid := str(world_db.flags.get("cartridge_id", ""))
	if cid != "":
		# Prefer editor worlds base when playtesting
		var editor_base := "user://editor/worlds/" + cid
		if DirAccess.dir_exists_absolute(editor_base):
			return editor_base
		# Player worlds base
		var player_base := "user://player/worlds/" + cid
		if DirAccess.dir_exists_absolute(player_base):
			return player_base
	return ""

static func resolve_path(path: String, world_db: WorldDB = null) -> String:
	# Return an absolute/local path suitable for FileAccess
	if typeof(path) != TYPE_STRING or path == "":
		return ""
	if path.begins_with("res://") or path.begins_with("user://") or path.begins_with("/"):
		return path
	var base := resolve_world_base_path(world_db)
	if base != "":
		return base.rstrip("/") + "/" + path.lstrip("/")
	# Fallback to user storage
	return "user://" + path.lstrip("/")

static func try_load_image(path: String, world_db: WorldDB = null) -> Image:
	# Attempts to resolve and load an Image from path (relative or absolute)
	var img := Image.new()
	var candidate := resolve_path(path, world_db)
	if candidate != "" and FileAccess.file_exists(candidate):
		if img.load(candidate) == OK:
			return img
	# Fallback attempts: user:// and res://
	var user_path := "user://" + path.lstrip("/")
	if FileAccess.file_exists(user_path) and img.load(user_path) == OK:
		return img
	var res_path := "res://" + path.lstrip("/")
	if FileAccess.file_exists(res_path) and img.load(res_path) == OK:
		return img
	return null

