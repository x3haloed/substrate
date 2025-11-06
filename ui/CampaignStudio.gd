extends Control

@onready var tab_container: TabContainer = $Margin/VBox/Tabs
@onready var dashboard: Node = $Margin/VBox/Tabs/Dashboard
@onready var scenes: Node = $Margin/VBox/Tabs/Scenes
@onready var graph: Node = $Margin/VBox/Tabs/Graph
@onready var lore: Node = $Margin/VBox/Tabs/Lore
@onready var characters: Node = $Margin/VBox/Tabs/Characters
@onready var entities_tab: Node = $Margin/VBox/Tabs/Entities
@onready var save_btn: Button = $Margin/VBox/Header/SaveBtn
@onready var export_btn: Button = $Margin/VBox/Header/ExportBtn

signal closed()
signal playtest_requested(world_db: WorldDB)

var current_world_db: WorldDB = null
var current_cart_path: String = "" # Path to the .zip file in editor storage
var validator: CampaignValidator = CampaignValidator.new()
var exporter: WorldExporter = null
var export_file_dialog: FileDialog = null

func _ready():
	# Instantiate exporter (needs to be a Node for file operations)
	exporter = WorldExporter.new()
	add_child(exporter)
	
	# Setup export file dialog (.scrt only)
	export_file_dialog = FileDialog.new()
	export_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_file_dialog.add_filter("*.scrt ; Substrate Cartridge")
	export_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_file_dialog.file_selected.connect(_on_export_file_selected)
	add_child(export_file_dialog)

	# Connect header buttons
	if save_btn:
		save_btn.pressed.connect(_on_save_pressed)
	if export_btn:
		export_btn.pressed.connect(_on_export_pressed)
	
	# Forward dashboard playtest signal to studio consumers
	if dashboard and dashboard.has_signal("playtest_requested"):
		dashboard.playtest_requested.connect(func(db: WorldDB): playtest_requested.emit(db))

func show_studio():
	visible = true

func hide_studio():
	visible = false
	closed.emit()

## Open the studio with a specific world database
func open_with_world(world_db: WorldDB, cart_path: String = "") -> void:
	current_world_db = world_db
	current_cart_path = cart_path
	
	# Restore cart path from world flags if available
	if current_cart_path == "" and world_db.flags.has("editor_cartridge_path"):
		current_cart_path = str(world_db.flags.get("editor_cartridge_path", ""))
	
	# Propagate world db to child views
	if dashboard:
		dashboard.current_world_db = world_db
	if scenes:
		scenes.current_world_db = world_db
	if graph:
		graph.current_world_db = world_db
	if lore and lore.has_method("set_world_db"):
		lore.set_world_db(world_db)
	if characters:
		characters.current_world_db = world_db
	if entities_tab and entities_tab.has_method("set_world_db"):
		entities_tab.set_world_db(world_db)

	# Share exporter with dashboard for packaging actions
	if dashboard:
		dashboard.exporter = exporter

	# Refresh child views
	if dashboard and dashboard.has_method("_refresh_dashboard"):
		dashboard._refresh_dashboard()
	if scenes and scenes.has_method("_refresh_scenes_list"):
		scenes._refresh_scenes_list()
	if graph and graph.has_method("_load_links_data"):
		graph._load_links_data()
	if graph and graph.has_method("_rebuild_graph"):
		graph._rebuild_graph()
	if lore and lore.has_method("_refresh_entries_list"):
		lore._refresh_entries_list()
	if characters and characters.has_method("refresh_characters_list"):
		characters.refresh_characters_list()
	if entities_tab and entities_tab.has_method("_refresh_list"):
		entities_tab._refresh_list()
	show_studio()

## ========================================
## UTILITIES
## ========================================

func _parse_comma_list(text: String) -> Array[String]:
	var result: Array[String] = []
	var parts := text.split(",")
	for part in parts:
		var trimmed := part.strip_edges()
		if not trimmed.is_empty():
			result.append(trimmed)
	return result

## ========================================
## SAVE/LOAD
## ========================================

func _on_export_pressed():
	# Export dialog (external) - suggest .scrt filename
	if current_world_db:
		var suggested := str(current_world_db.flags.get("campaign_id", "campaign"))
		suggested = suggested.to_lower().replace(" ", "_")
		export_file_dialog.current_file = suggested + ".scrt"
	export_file_dialog.popup_centered_ratio(0.75)

func _on_export_file_selected(path: String):
	var out_path := path
	if not out_path.to_lower().ends_with(".scrt"):
		out_path += ".scrt"
	if _export_to_path(out_path):
		print("Campaign exported to: " + out_path)

func _save_to_path(path: String) -> bool:
	if current_world_db == null:
		push_error("No campaign loaded to save")
		return false
	
	# Persist current UI metadata edits into world flags
	if dashboard and dashboard.has_method("_save_metadata_to_world"):
		dashboard._save_metadata_to_world()

	# Build metadata from world flags
	var meta := {
		"id": current_world_db.flags.get("campaign_id", "campaign"),
		"name": current_world_db.flags.get("campaign_name", "Untitled Campaign"),
		"version": current_world_db.flags.get("campaign_version", "1.0.0"),
		"author": current_world_db.flags.get("campaign_author", ""),
		"description": current_world_db.flags.get("campaign_description", ""),
		"initial_scene_id": current_world_db.flags.get("initial_scene_id", "")
	}
	
	# Export with world.json included for editor
	var options := {
		"include_world_json": true
	}
	
	var success := exporter.export_world(current_world_db, path, meta, options)
	if success:
		# Store path in world flags for future saves
		current_world_db.flags["editor_cartridge_path"] = path
	
	return success

func _export_to_path(path: String) -> bool:
	if current_world_db == null:
		push_error("No campaign loaded to export")
		return false
	# Persist current UI metadata edits into world flags
	if dashboard and dashboard.has_method("_save_metadata_to_world"):
		dashboard._save_metadata_to_world()
	# Build metadata from world flags
	var meta := {
		"id": current_world_db.flags.get("campaign_id", "campaign"),
		"name": current_world_db.flags.get("campaign_name", "Untitled Campaign"),
		"version": current_world_db.flags.get("campaign_version", "1.0.0"),
		"author": current_world_db.flags.get("campaign_author", ""),
		"description": current_world_db.flags.get("campaign_description", ""),
		"initial_scene_id": current_world_db.flags.get("initial_scene_id", "")
	}
	var options := { "include_world_json": true }
	return exporter.export_world(current_world_db, path, meta, options)

func _ensure_editor_dir(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

func _compute_editor_path() -> String:
	var base_dir := CartridgeManager.EDITOR_LIBRARY_DIR.rstrip("/")
	_ensure_editor_dir(base_dir)
	var suggested := str(current_world_db.flags.get("campaign_id", "campaign"))
	suggested = suggested.to_lower().replace(" ", "_")
	var path := base_dir + "/" + suggested + ".zip"
	return path

func _on_save_pressed():
	# Overwrite if existing editor path known; else create new in editor storage
	var target := ""
	var editor_dir := CartridgeManager.EDITOR_LIBRARY_DIR.rstrip("/")
	if current_cart_path != "" and current_cart_path.begins_with(editor_dir):
		target = current_cart_path
		if not target.to_lower().ends_with(".zip"):
			# Normalize to .zip inside editor storage
			var stem := target.get_basename()
			target = stem + ".zip"
	else:
		target = _compute_editor_path()
	if _save_to_path(target):
		current_cart_path = target
		print("Campaign saved to: " + target)
