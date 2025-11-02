extends Node
class_name CartridgeManager

signal library_updated()
signal cartridge_imported(cartridge_id: String)

const SCRT_EXTENSION := ".scrt"

var library_dir: String = "user://cartridges"
var _library_cache: Array = [] # Array of { path: String, cartridge: Cartridge }

func _ready():
    _ensure_library_dir()
    refresh_library()

func set_library_dir(dir: String) -> void:
    if dir.strip_edges() == "":
        return
    library_dir = dir
    _ensure_library_dir()
    refresh_library()

func _ensure_library_dir() -> void:
    var d := DirAccess.open("user://")
    if d == null:
        return
    if not d.dir_exists(library_dir):
        d.make_dir_recursive(library_dir)

func refresh_library() -> void:
    _library_cache.clear()
    var d := DirAccess.open(library_dir)
    if d == null:
        library_updated.emit()
        return
    d.list_dir_begin()
    while true:
        var entry_name := d.get_next()
        if entry_name == "":
            break
        if d.current_is_dir():
            continue
        if not entry_name.to_lower().ends_with(SCRT_EXTENSION):
            continue
        var path := library_dir.rstrip("/") + "/" + entry_name
        var cart := _read_cartridge_manifest(path)
        if cart != null:
            _library_cache.append({"path": path, "cartridge": cart})
    d.list_dir_end()
    library_updated.emit()

func get_library() -> Array:
    return _library_cache.duplicate(true)

func _read_cartridge_manifest(file_path: String) -> Cartridge:
    # Use ZIPReader to read manifest.json without extracting
    var zip := ZIPReader.new()
    var err := zip.open(file_path)
    if err != OK:
        push_warning("Failed to open cartridge: " + file_path + " error=" + str(err))
        return null
    var manifest_path := "manifest.json"
    if not zip.file_exists(manifest_path):
        zip.close()
        push_warning("manifest.json missing in cartridge: " + file_path)
        return null
    var bytes: PackedByteArray = zip.read_file(manifest_path)
    zip.close()
    var text: String = bytes.get_string_from_utf8()
    var parsed := JSON.new()
    var jerr := parsed.parse(text)
    if jerr != OK:
        push_warning("Invalid manifest.json in cartridge: " + file_path)
        return null
    var dict := parsed.data as Dictionary
    if dict == null:
        return null
    var cart := Cartridge.from_manifest_dict(dict)
    # Attempt to populate thumbnails if previews exist
    var thumbs: Dictionary = {}
    for size in [256, 512, 1024]:
        var p := "previews/thumbnail_%d.png" % size
        # We can't check existence without reopening; accept convention
        thumbs["thumbnail_%d.png" % size] = p
    cart.thumbnails = thumbs
    return cart

func import_cartridge(file_path: String) -> String:
    # Returns imported cartridge id (folder name) or ""
    var zip := ZIPReader.new()
    var err := zip.open(file_path)
    if err != OK:
        push_error("Failed to open cartridge for import: " + file_path)
        return ""
    var manifest_bytes: PackedByteArray = zip.read_file("manifest.json") if zip.file_exists("manifest.json") else PackedByteArray()
    var cart_id := ""
    if manifest_bytes.size() > 0:
        var parsed := JSON.new()
        if parsed.parse(manifest_bytes.get_string_from_utf8()) == OK:
            var md := parsed.data as Dictionary
            if md != null:
                cart_id = str(md.get("id", ""))
    if cart_id == "":
        # Fallback to filename sans extension
        cart_id = file_path.get_file().get_basename()

    var base_dest := "res://worlds/" + cart_id
    # Ensure destination directory exists
    var root := DirAccess.open("res://")
    if root == null:
        zip.close()
        push_error("Cannot open res:// for import")
        return ""
    root.make_dir_recursive(base_dest)

    # Extract all files preserving structure
    for internal_path in zip.get_files():
        # Normalize to forward slashes
        var norm := internal_path.replace("\\", "/")
        var out_path := base_dest + "/" + norm
        if norm.ends_with("/"):
            # directory entry; ensure exists
            root.make_dir_recursive(out_path)
            continue
        var parent := out_path.get_base_dir()
        root.make_dir_recursive(parent)
        var bytes := zip.read_file(internal_path)
        var fa := FileAccess.open(out_path, FileAccess.WRITE)
        if fa == null:
            push_warning("Failed to write: " + out_path)
            continue
        fa.store_buffer(bytes)
        fa.close()

    zip.close()
    cartridge_imported.emit(cart_id)
    return cart_id

func build_world_db_from_import(cart_id: String) -> WorldDB:
    var base := "res://worlds/" + cart_id + "/"
    var manifest_path := base + "manifest.json"
    var world_path := base + "world.json"
    var world := WorldDB.new()

    # Manifest
    if FileAccess.file_exists(manifest_path):
        var parsed: Dictionary = _load_json_file(manifest_path) as Dictionary
        if parsed != null:
            var cart := Cartridge.from_manifest_dict(parsed)
            for sid in cart.scenes:
                world.scenes[sid] = base + "scenes/" + sid + ".tres"
            for cid in cart.characters:
                world.characters[cid] = base + "characters/" + cid + ".tres"
            # Initial scene hint
            if cart.initial_scene_id != "":
                world.flags["initial_scene_id"] = cart.initial_scene_id

    # Optional runtime snapshot
    if FileAccess.file_exists(world_path):
        var w: Dictionary = _load_json_file(world_path) as Dictionary
        if w != null:
            if w.has("flags") and w.flags is Dictionary:
                for k in w.flags.keys():
                    world.flags[k] = w.flags[k]
            if w.has("relationships") and w.relationships is Dictionary:
                for a in w.relationships.keys():
                    world.relationships[a] = w.relationships[a]
            if w.has("characters_state") and w.characters_state is Dictionary:
                world.characters_state = w.characters_state

    return world

func _load_json_file(path: String):
    var text: String = FileAccess.get_file_as_string(path)
    if text == "":
        return null
    var j := JSON.new()
    if j.parse(text) != OK:
        return null
    return j.data


