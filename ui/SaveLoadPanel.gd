extends Control

signal save_requested(slot_name: String)
signal load_requested(slot_name: String)

@onready var slot_list: ItemList = $Margin/VBox/Slots/SlotList
@onready var slot_name_edit: LineEdit = $Margin/VBox/Actions/SlotName

var cartridge_id: String = "default"

func set_context(p_cartridge_id: String) -> void:
    cartridge_id = p_cartridge_id
    refresh_slots()

func _ready():
    refresh_slots()

func refresh_slots():
    if not is_instance_valid(slot_list):
        return
    slot_list.clear()
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
    while true:
        var entry_name := ld.get_next()
        if entry_name == "":
            break
        if ld.current_is_dir():
            continue
        if not entry_name.to_lower().ends_with(".tres"):
            continue
        var slot := entry_name.get_basename()
        var label := _format_slot_label(slot, dir_path + "/" + slot + ".json")
        var idx := slot_list.add_item(label)
        slot_list.set_item_metadata(idx, slot)
    ld.list_dir_end()

func _format_slot_label(slot: String, meta_path: String) -> String:
    var scene := ""
    if FileAccess.file_exists(meta_path):
        var txt := FileAccess.get_file_as_string(meta_path)
        var j := JSON.new()
        if txt != "" and j.parse(txt) == OK and j.data is Dictionary:
            scene = str(j.data.get("scene", ""))
    if scene != "":
        return "%s — %s" % [slot, scene]
    return slot

func _slot_dir() -> String:
    return "user://saves/%s" % cartridge_id

func _on_save_pressed():
    var slot := slot_name_edit.text.strip_edges()
    if slot == "":
        return
    save_requested.emit(slot)

func _on_load_pressed():
    var idxs := slot_list.get_selected_items()
    if idxs.is_empty():
        return
    var slot := str(slot_list.get_item_metadata(idxs[0]))
    load_requested.emit(slot)

func _on_delete_pressed():
    var idxs := slot_list.get_selected_items()
    if idxs.is_empty():
        return
    var slot := str(slot_list.get_item_metadata(idxs[0]))
    var dir := _slot_dir()
    var save_path := dir + "/" + slot + ".tres"
    var meta_path := dir + "/" + slot + ".json"
    if FileAccess.file_exists(save_path):
        DirAccess.remove_absolute(save_path)
    if FileAccess.file_exists(meta_path):
        DirAccess.remove_absolute(meta_path)
    refresh_slots()


