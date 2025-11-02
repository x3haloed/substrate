extends Node
class_name WorldExporter

## Export a WorldDB into a .scrt (ZIP-backed) cartridge

func export_world(world: WorldDB, export_path: String, meta: Dictionary = {}, options: Dictionary = {}) -> bool:
    # meta: { id, name, version, author, description, initial_scene_id }
    # options: { include_world_json: bool, thumbnails: Dictionary(size->Image or bytes) }
    if world == null:
        push_error("WorldExporter: world is null")
        return false

    var cart_id: String = str(meta.get("id", "world"))
    var stage_dir := _create_staging_dir(cart_id)
    if stage_dir == "":
        return false

    # 1) Stage scenes and characters
    var scene_ids: Array[String] = []
    for sid in world.scenes.keys():
        var src := str(world.scenes[sid])
        if _copy_file(src, stage_dir + "/scenes/" + sid + ".tres"):
            scene_ids.append(sid)

    var character_ids: Array[String] = []
    for cid in world.characters.keys():
        var csrc := str(world.characters[cid])
        if _copy_file(csrc, stage_dir + "/characters/" + cid + ".tres"):
            character_ids.append(cid)

    # 2) manifest.json
    var cart := Cartridge.new()
    cart.id = cart_id
    cart.name = str(meta.get("name", cart_id))
    cart.version = str(meta.get("version", "1.0.0"))
    cart.author = str(meta.get("author", ""))
    cart.description = str(meta.get("description", ""))
    cart.initial_scene_id = str(meta.get("initial_scene_id", world.flags.get("current_scene", world.flags.get("initial_scene_id", ""))))
    cart.scenes = scene_ids
    cart.characters = character_ids

    var manifest_path := stage_dir + "/manifest.json"
    var j := JSON.stringify(cart.to_manifest_dict(), "  ")
    var ok := _write_text_file(manifest_path, j)
    if not ok:
        return false

    # 3) world.json (optional)
    if bool(options.get("include_world_json", false)):
        var w := {
            "flags": world.flags,
            "relationships": world.relationships,
            "characters_state": world.characters_state
        }
        _write_text_file(stage_dir + "/world.json", JSON.stringify(w, "  "))

    # 4) thumbnails (optional)
    var thumbs: Dictionary = options.get("thumbnails", {})
    if thumbs is Dictionary and not thumbs.is_empty():
        var prev_dir := stage_dir + "/previews"
        DirAccess.make_dir_recursive_absolute(prev_dir)
        for k in thumbs.keys():
            var img: Variant = thumbs[k]
            if img is Image:
                var bytes: PackedByteArray = img.save_png_to_buffer()
                var out := prev_dir + "/thumbnail_%s.png" % str(k)
                var fa := FileAccess.open(out, FileAccess.WRITE)
                if fa:
                    fa.store_buffer(bytes)
                    fa.close()

    # 5) Zip the staging directory
    return _zip_dir(stage_dir, export_path)

func _create_staging_dir(cart_id: String) -> String:
    var ts := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
    var base := "user://export/%s_%s" % [cart_id, ts]
    DirAccess.make_dir_recursive_absolute(base + "/scenes")
    DirAccess.make_dir_recursive_absolute(base + "/characters")
    return base

func _copy_file(src: String, dst: String) -> bool:
    if not FileAccess.file_exists(src):
        push_warning("Missing source file: " + src)
        return false
    DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
    var bytes := FileAccess.get_file_as_bytes(src)
    var f := FileAccess.open(dst, FileAccess.WRITE)
    if f == null:
        push_warning("Failed to open for write: " + dst)
        return false
    f.store_buffer(bytes)
    f.close()
    return true

func _write_text_file(path: String, text: String) -> bool:
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(text)
    f.close()
    return true

func _zip_dir(dir_path: String, out_zip_path: String) -> bool:
    # Ensure .scrt extension if not provided
    var out_path := out_zip_path
    if not out_path.to_lower().ends_with(".scrt"):
        out_path += ".scrt"
    # Create packer
    var zp := ZIPPacker.new()
    var err := zp.open(out_path)
    if err != OK:
        push_error("Failed to create zip: " + out_path)
        return false
    _zip_dir_recursive(zp, dir_path, "")
    zp.close()
    return true

func _zip_dir_recursive(zp: ZIPPacker, base_dir: String, rel: String) -> void:
    var abs_path := base_dir.rstrip("/") + ("/" + rel if rel != "" else "")
    var d := DirAccess.open(abs_path)
    if d == null:
        return
    d.list_dir_begin()
    while true:
        var entry_name := d.get_next()
        if entry_name == "":
            break
        if entry_name == "." or entry_name == "..":
            continue
        var sub_rel := (rel + "/" if rel != "" else "") + entry_name
        var sub_abs := abs_path + "/" + entry_name
        if d.current_is_dir():
            _zip_dir_recursive(zp, base_dir, sub_rel)
        else:
            var bytes := FileAccess.get_file_as_bytes(sub_abs)
            zp.start_file(sub_rel)
            zp.write_file(bytes)
            zp.close_file()
    d.list_dir_end()


