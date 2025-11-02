extends Control

signal start_new_game(cartridge: Cartridge, file_path: String)
signal load_slot_requested(cartridge: Cartridge, slot_name: String, file_path: String)

@onready var title_label: Label = $Margin/VBox/Header/Title
@onready var meta_label: Label = $Margin/VBox/Header/Meta
@onready var desc_label: Label = $Margin/VBox/Desc
@onready var slot_list: ItemList = $Margin/VBox/Slots/SlotList

var cartridge: Cartridge
var file_path: String = ""

func set_cartridge(c: Cartridge, path: String) -> void:
    cartridge = c
    file_path = path
    _refresh_meta()
    _refresh_slots()

func _refresh_meta() -> void:
    if cartridge == null:
        title_label.text = ""
        meta_label.text = ""
        desc_label.text = ""
        return
    title_label.text = cartridge.name
    var parts: Array[String] = []
    if cartridge.author != "":
        parts.append(cartridge.author)
    parts.append("v" + cartridge.version)
    meta_label.text = "  ·  ".join(parts)
    desc_label.text = cartridge.description

func _refresh_slots() -> void:
    slot_list.clear()
    if cartridge == null:
        return
    var dir_path := _slot_dir()
    var d := DirAccess.open("user://")
    if d == null:
        return
    if not d.dir_exists(dir_path):
        d.make_dir_recursive(dir_path)
    var ld := DirAccess.open(dir_path)
    if ld == null:
        return
    ld.list_dir_begin()
    var entries := []
    while true:
        var entry_name := ld.get_next()
        if entry_name == "":
            break
        if ld.current_is_dir():
            continue
        if entry_name.to_lower().ends_with(".tres"):
            var slot := entry_name.get_basename()
            var meta := _read_slot_meta(dir_path + "/" + slot + ".json")
            var label := _format_slot_label(slot, meta)
            var idx := slot_list.add_item(label)
            slot_list.set_item_metadata(idx, slot)
    ld.list_dir_end()

func _format_slot_label(slot: String, meta: Dictionary) -> String:
    var scene := str(meta.get("scene", ""))
    var ts := str(meta.get("timestamp", ""))
    if scene != "":
        return "%s — %s" % [slot, scene]
    return slot

func _read_slot_meta(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var txt := FileAccess.get_file_as_string(path)
    if txt == "":
        return {}
    var j := JSON.new()
    if j.parse(txt) != OK:
        return {}
    if j.data is Dictionary:
        return j.data
    return {}

func _slot_dir() -> String:
    return "user://saves/%s" % cartridge.id

func _on_new_game_pressed():
    if cartridge != null:
        start_new_game.emit(cartridge, file_path)

func _on_load_pressed():
    var idx := slot_list.get_selected_items()
    if idx.size() == 0:
        return
    var slot := str(slot_list.get_item_metadata(idx[0]))
    load_slot_requested.emit(cartridge, slot, file_path)

func _on_delete_pressed():
    var idx := slot_list.get_selected_items()
    if idx.size() == 0:
        return
    var slot := str(slot_list.get_item_metadata(idx[0]))
    var dir := _slot_dir()
    var save_path := dir + "/" + slot + ".tres"
    var meta_path := dir + "/" + slot + ".json"
    if FileAccess.file_exists(save_path):
        DirAccess.remove_absolute(save_path)
    if FileAccess.file_exists(meta_path):
        DirAccess.remove_absolute(meta_path)
    _refresh_slots()


