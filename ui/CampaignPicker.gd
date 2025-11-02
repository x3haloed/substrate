extends Window

## Campaign Picker Dialog - Select or create campaigns from editor storage

signal campaign_selected(cart_path: String, world_db: WorldDB)
signal cancelled()

@onready var campaign_list: ItemList = %CampaignList
@onready var new_btn: Button = %NewBtn
@onready var delete_btn: Button = %DeleteBtn
@onready var open_btn: Button = %OpenBtn
@onready var cancel_btn: Button = $VBox/Toolbar/CancelBtn

@onready var name_label: Label = %NameLabel
@onready var version_label: Label = %VersionLabel
@onready var author_label: Label = %AuthorLabel
@onready var desc_label: Label = %DescLabel
@onready var scenes_label: Label = %ScenesLabel
@onready var characters_label: Label = %CharactersLabel

var editor_campaigns: Array[Dictionary] = [] # Array of {path: String, cartridge: Cartridge}
var importer: WorldImporter = null

func _ready():
	# No need for WorldImporter here; we'll use CartridgeManager for editor store
	
	# Connect signals
	campaign_list.item_selected.connect(_on_campaign_selected)
	campaign_list.item_activated.connect(_on_campaign_activated)
	new_btn.pressed.connect(_on_new_pressed)
	delete_btn.pressed.connect(_on_delete_pressed)
	open_btn.pressed.connect(_on_open_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	close_requested.connect(_on_cancel_pressed)
	
	_refresh_campaign_list()

func show_picker():
	_refresh_campaign_list()
	popup_centered()

func _refresh_campaign_list():
	campaign_list.clear()
	editor_campaigns.clear()
	
	# Load campaigns from editor cartridge store
	var paths := _get_editor_cartridge_paths()
	for path in paths:
		var cart := _read_cartridge_manifest(path)
		if cart:
			editor_campaigns.append({"path": path, "cartridge": cart})
			var display_name := cart.name if cart.name != "" else cart.id
			display_name += " v" + cart.version if cart.version != "" else ""
			campaign_list.add_item(display_name)
	
	# Update UI state
	_update_preview(-1)
	delete_btn.disabled = true
	open_btn.disabled = true

func _get_editor_cartridge_paths() -> Array[String]:
	var paths: Array[String] = []
	var lib_dir := CartridgeManager.EDITOR_LIBRARY_DIR
	
	if not DirAccess.dir_exists_absolute(lib_dir):
		DirAccess.make_dir_recursive_absolute(lib_dir)
		return paths
	
	var dir := DirAccess.open(lib_dir)
	if dir:
		dir.list_dir_begin()
		var fn := dir.get_next()
		while fn != "":
			if not dir.current_is_dir() and (fn.ends_with(".zip") or fn.ends_with(".scrt")):
				paths.append(lib_dir.rstrip("/") + "/" + fn)
			fn = dir.get_next()
		dir.list_dir_end()
	
	return paths

func _read_cartridge_manifest(file_path: String) -> Cartridge:
	var zip := ZIPReader.new()
	var err := zip.open(file_path)
	if err != OK:
		return null
	
	if not zip.file_exists("manifest.json"):
		zip.close()
		return null
	
	var bytes: PackedByteArray = zip.read_file("manifest.json")
	zip.close()
	
	var text: String = bytes.get_string_from_utf8()
	var parsed := JSON.new()
	if parsed.parse(text) != OK:
		return null
	
	var dict := parsed.data as Dictionary
	if dict == null:
		return null
	
	return Cartridge.from_manifest_dict(dict)

func _on_campaign_selected(index: int):
	_update_preview(index)
	delete_btn.disabled = false
	open_btn.disabled = false

func _on_campaign_activated(index: int):
	_load_and_emit(index)

func _update_preview(index: int):
	if index < 0 or index >= editor_campaigns.size():
		name_label.text = "Name: -"
		version_label.text = "Version: -"
		author_label.text = "Author: -"
		desc_label.text = "Description: -"
		scenes_label.text = "Scenes: 0"
		characters_label.text = "Characters: 0"
		return
	
	var entry: Dictionary = editor_campaigns[index]
	var cart: Cartridge = entry.cartridge
	
	name_label.text = "Name: " + (cart.name if cart.name != "" else "-")
	version_label.text = "Version: " + (cart.version if cart.version != "" else "-")
	author_label.text = "Author: " + (cart.author if cart.author != "" else "-")
	desc_label.text = "Description: " + (cart.description if cart.description != "" else "-")
	scenes_label.text = "Scenes: " + str(cart.scenes.size())
	characters_label.text = "Characters: " + str(cart.characters.size())

func _on_new_pressed():
	# Create a new empty campaign
	var world_db := WorldDB.new()
	world_db.flags["campaign_name"] = "New Campaign"
	world_db.flags["campaign_id"] = "new_campaign_" + str(Time.get_ticks_msec())
	campaign_selected.emit("", world_db)
	hide()

func _on_delete_pressed():
	var selected_indices := campaign_list.get_selected_items()
	if selected_indices.is_empty():
		return
	
	var index := selected_indices[0]
	if index < 0 or index >= editor_campaigns.size():
		return
	
	var entry: Dictionary = editor_campaigns[index]
	var path: String = entry.path
	
	# Delete file from disk
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(path)
		if err != OK:
			push_error("Failed to delete campaign file: " + path)
			return
	
	# Refresh list
	_refresh_campaign_list()

func _on_open_pressed():
	var selected_indices := campaign_list.get_selected_items()
	if selected_indices.is_empty():
		return
	
	var index := selected_indices[0]
	_load_and_emit(index)

func _load_and_emit(index: int):
	if index < 0 or index >= editor_campaigns.size():
		return
	
	var entry: Dictionary = editor_campaigns[index]
	var path: String = entry.path
	
	# Use CartridgeManager in EDITOR store to import and build world_db under user://editor/worlds/
	var cart_id := CartridgeManagerTool.import_cartridge(path, CartridgeManager.StoreKind.EDITOR)
	if cart_id == "":
		push_error("Failed to import campaign: " + path)
		return
	var world_db: WorldDB = CartridgeManagerTool.build_world_db_from_import(cart_id, CartridgeManager.StoreKind.EDITOR)
	if world_db == null:
		push_error("Failed to build world from imported campaign: " + cart_id)
		return
	
	# Remember the original zip path for Save
	world_db.flags["editor_cartridge_path"] = path
	
	campaign_selected.emit(path, world_db)
	hide()

func _on_cancel_pressed():
	cancelled.emit()
	hide()

