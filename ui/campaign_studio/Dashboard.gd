extends ScrollContainer

@onready var id_field: LineEdit = $"DashboardContent/MetadataSection/MetadataGrid/IdField"
@onready var name_field: LineEdit = $"DashboardContent/MetadataSection/MetadataGrid/NameField"
@onready var version_field: LineEdit = $"DashboardContent/MetadataSection/MetadataGrid/VersionField"
@onready var author_field: LineEdit = $"DashboardContent/MetadataSection/MetadataGrid/AuthorField"
@onready var initial_scene_field: LineEdit = $"DashboardContent/MetadataSection/MetadataGrid/InitialSceneField"
@onready var desc_field: TextEdit = $"DashboardContent/MetadataSection/DescField"
@onready var scenes_count_label: Label = $"DashboardContent/ContentSection/ContentStats/ScenesCount"
@onready var characters_count_label: Label = $"DashboardContent/ContentSection/ContentStats/CharactersCount"
@onready var warnings_list: RichTextLabel = $"DashboardContent/ContentSection/WarningsList"
@onready var export_dialog: FileDialog = $"ExportDialog"

signal playtest_requested(world_db: WorldDB)

var current_world_db: WorldDB = null
var validator: CampaignValidator = CampaignValidator.new()
var exporter: WorldExporter = null

## Refresh the dashboard with current world data
func _refresh_dashboard() -> void:
	if current_world_db == null:
		return
	
	# Populate metadata from flags
	id_field.text = str(current_world_db.flags.get("campaign_id", ""))
	name_field.text = str(current_world_db.flags.get("campaign_name", ""))
	version_field.text = str(current_world_db.flags.get("campaign_version", "1.0.0"))
	author_field.text = str(current_world_db.flags.get("campaign_author", ""))
	initial_scene_field.text = str(current_world_db.flags.get("initial_scene_id", ""))
	desc_field.text = str(current_world_db.flags.get("campaign_description", ""))
	
	# Update content summary
	var scene_count := current_world_db.scenes.size()
	var character_count := current_world_db.characters.size()
	scenes_count_label.text = "Scenes: %d" % scene_count
	characters_count_label.text = "Characters: %d" % character_count
	
	# Run validation and display warnings
	_update_validation_warnings()

## Run validation and update the warnings display
func _update_validation_warnings() -> void:
	if current_world_db == null:
		warnings_list.text = "[color=gray]No world loaded[/color]"
		return
	
	var issues := validator.validate_world(current_world_db)
	
	if issues.is_empty():
		warnings_list.text = "[color=green]✓ No validation issues found[/color]"
		return
	
	var warning_text := ""
	var error_count := 0
	var warning_count := 0
	
	for issue in issues:
		var type_str: String = str(issue.get("type", "unknown"))
		var msg: String = str(issue.get("message", ""))
		var data: Dictionary = issue.get("data", {})
		
		# Classify severity
		var is_error := type_str in ["exit_broken_link", "missing_character", "scene_load_error"]
		if is_error:
			error_count += 1
			warning_text += "[color=red]✗ ERROR: %s[/color]\n" % msg
		else:
			warning_count += 1
			warning_text += "[color=yellow]⚠ WARNING: %s[/color]\n" % msg
		
		# Add data details
		for key in data.keys():
			warning_text += "  [color=gray]%s: %s[/color]\n" % [key, str(data[key])]
		warning_text += "\n"
	
	# Prepend summary
	var summary := "[b]Found %d error(s) and %d warning(s)[/b]\n\n" % [error_count, warning_count]
	warnings_list.text = summary + warning_text

## Save current metadata fields back to world_db flags
func _save_metadata_to_world() -> void:
	if current_world_db == null:
		return
	
	current_world_db.flags["campaign_id"] = id_field.text
	current_world_db.flags["campaign_name"] = name_field.text
	current_world_db.flags["campaign_version"] = version_field.text
	current_world_db.flags["campaign_author"] = author_field.text
	current_world_db.flags["initial_scene_id"] = initial_scene_field.text
	current_world_db.flags["campaign_description"] = desc_field.text

## Button handlers

func _on_validate_pressed() -> void:
	_save_metadata_to_world()
	_update_validation_warnings()

func _on_playtest_pressed() -> void:
	if current_world_db == null:
		push_warning("No world loaded for playtest")
		return
	_save_metadata_to_world()
	playtest_requested.emit(current_world_db)

func _on_export_pressed() -> void:
	if current_world_db == null:
		push_warning("No world loaded for export")
		return
	
	_save_metadata_to_world()
	
	# Run validation first
	var issues := validator.validate_world(current_world_db)
	var has_errors := false
	for issue in issues:
		var type_str: String = str(issue.get("type", ""))
		if type_str in ["exit_broken_link", "missing_character", "scene_load_error"]:
			has_errors = true
			break
	
	if has_errors:
		push_warning("Cannot export: validation errors present")
		_update_validation_warnings()
		return
	
	# Open file dialog
	export_dialog.popup_centered()

func _on_refresh_pressed() -> void:
	_refresh_dashboard()

func _on_export_dialog_dir_selected(dir: String) -> void:
	if current_world_db == null:
		return
	
	# Build metadata from fields
	var meta := {
		"id": id_field.text,
		"name": name_field.text,
		"version": version_field.text,
		"author": author_field.text,
		"description": desc_field.text,
		"initial_scene_id": initial_scene_field.text
	}
	
	# Construct export path
	var cart_id := str(meta.get("id", "campaign"))
	var export_path := dir.rstrip("/") + "/" + cart_id + ".scrt"
	
	# Export options
	var options := {
		"include_world_json": true
	}
	
	var success := exporter.export_world(current_world_db, export_path, meta, options)
	
	if success:
		print("Campaign exported successfully to: " + export_path)
		# Could show a success notification here
	else:
		push_error("Failed to export campaign")
