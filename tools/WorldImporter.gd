extends Node
class_name WorldImporter

## Import a .scrt cartridge by extracting it under res://worlds/<id>/ and building a WorldDB

func import_cartridge(scrt_path: String) -> WorldDB:
    var zip := ZIPReader.new()
    var err := zip.open(scrt_path)
    if err != OK:
        push_error("WorldImporter: cannot open zip: " + scrt_path)
        return null

    # Read manifest
    if not zip.file_exists("manifest.json"):
        zip.close()
        push_error("WorldImporter: manifest.json missing")
        return null
    var manifest_txt := zip.read_file("manifest.json").get_string_from_utf8()
    var j := JSON.new()
    if j.parse(manifest_txt) != OK or not (j.data is Dictionary):
        zip.close()
        push_error("WorldImporter: invalid manifest.json")
        return null
    var manifest: Dictionary = j.data
    var cart := Cartridge.from_manifest_dict(manifest)
    var cart_id := cart.id if cart.id != "" else scrt_path.get_file().get_basename()

    # Extract to res://worlds/<id>/
    var base := "res://worlds/" + cart_id
    DirAccess.make_dir_recursive_absolute(base)
    for fp in zip.get_files():
        var norm := fp.replace("\\", "/")
        if norm.ends_with("/"):
            DirAccess.make_dir_recursive_absolute(base + "/" + norm)
            continue
        var out := base + "/" + norm
        DirAccess.make_dir_recursive_absolute(out.get_base_dir())
        var bytes := zip.read_file(fp)
        var fa := FileAccess.open(out, FileAccess.WRITE)
        if fa:
            fa.store_buffer(bytes)
            fa.close()
    zip.close()

    # Validate basic schema
    if cart.initial_scene_id == "":
        push_warning("WorldImporter: initial_scene_id missing in manifest")

    # Verify integrity if present
    if manifest.has("integrity") and manifest.integrity is Dictionary:
        for rel_path in manifest.integrity.keys():
            var expected := str(manifest.integrity[rel_path])
            var absolute: String = base + "/" + rel_path
            if not FileAccess.file_exists(absolute):
                push_warning("Missing file for integrity: " + rel_path)
                continue
            var actual := _sha256(FileAccess.get_file_as_bytes(absolute))
            if actual != expected:
                push_warning("Integrity mismatch: " + rel_path)

    # Build WorldDB
    var world := WorldDB.new()
    for sid in cart.scenes:
        world.scenes[sid] = base + "/scenes/" + sid + ".tres"
    for cid in cart.characters:
        world.characters[cid] = base + "/characters/" + cid + ".tres"
    var lore_db_path := base + "/lore/lore_db.tres"
    if FileAccess.file_exists(lore_db_path):
        var imported_lore := load(lore_db_path) as LoreDB
        if imported_lore:
            var resolved := LoreDB.new()
            for entry_id in imported_lore.entries.keys():
                var value = imported_lore.entries[entry_id]
                if value is String:
                    var path := str(value)
                    if path.begins_with("res://") or path.begins_with("uid://") or path.begins_with("user://"):
                        resolved.entries[entry_id] = path
                    else:
                        resolved.entries[entry_id] = base + "/" + path
                else:
                    resolved.entries[entry_id] = value
            world.lore_db = resolved

    var world_json := base + "/world.json"
    if FileAccess.file_exists(world_json):
        var w: Dictionary = _load_json_file(world_json) as Dictionary
        if w != null:
            if w.has("flags") and w.flags is Dictionary:
                for k in w.flags.keys():
                    world.flags[k] = w.flags[k]
            if w.has("relationships") and w.relationships is Dictionary:
                for a in w.relationships.keys():
                    world.relationships[a] = w.relationships[a]
            if w.has("characters_state") and w.characters_state is Dictionary:
                world.characters_state = w.characters_state

    world.flags["initial_scene_id"] = cart.initial_scene_id
    world.flags["cartridge_id"] = cart_id
    world.flags["cartridge_base_path"] = base
    return world

func _sha256(bytes: PackedByteArray) -> String:
    var ctx := HashingContext.new()
    ctx.start(HashingContext.HASH_SHA256)
    ctx.update(bytes)
    var h: PackedByteArray = ctx.finish()
    return h.hex_encode()

func _load_json_file(path: String):
    var txt := FileAccess.get_file_as_string(path)
    if txt == "":
        return null
    var j := JSON.new()
    if j.parse(txt) != OK:
        return null
    return j.data
