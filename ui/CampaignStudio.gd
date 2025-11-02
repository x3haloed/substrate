extends Control

@onready var tab_container: TabContainer = $Margin/VBox/Tabs

# Dashboard references
@onready var id_field: LineEdit = $"Margin/VBox/Tabs/Dashboard/DashboardContent/MetadataSection/MetadataGrid/IdField"
@onready var name_field: LineEdit = $"Margin/VBox/Tabs/Dashboard/DashboardContent/MetadataSection/MetadataGrid/NameField"
@onready var version_field: LineEdit = $"Margin/VBox/Tabs/Dashboard/DashboardContent/MetadataSection/MetadataGrid/VersionField"
@onready var author_field: LineEdit = $"Margin/VBox/Tabs/Dashboard/DashboardContent/MetadataSection/MetadataGrid/AuthorField"
@onready var initial_scene_field: LineEdit = $"Margin/VBox/Tabs/Dashboard/DashboardContent/MetadataSection/MetadataGrid/InitialSceneField"
@onready var desc_field: TextEdit = $"Margin/VBox/Tabs/Dashboard/DashboardContent/MetadataSection/DescField"
@onready var scenes_count_label: Label = $"Margin/VBox/Tabs/Dashboard/DashboardContent/ContentSection/ContentStats/ScenesCount"
@onready var characters_count_label: Label = $"Margin/VBox/Tabs/Dashboard/DashboardContent/ContentSection/ContentStats/CharactersCount"
@onready var warnings_list: RichTextLabel = $"Margin/VBox/Tabs/Dashboard/DashboardContent/ContentSection/WarningsList"
@onready var export_dialog: FileDialog = $"Margin/VBox/Tabs/Dashboard/ExportDialog"

# Scenes workspace references
@onready var search_box: LineEdit = $"Margin/VBox/Tabs/Scenes/SceneList/SearchBox"
@onready var scene_item_list: ItemList = $"Margin/VBox/Tabs/Scenes/SceneList/SceneItemList"
@onready var no_selection_label: Label = $"Margin/VBox/Tabs/Scenes/SceneEditor/EditorContent/NoSelectionLabel"
@onready var editor_panel: VBoxContainer = $"Margin/VBox/Tabs/Scenes/SceneEditor/EditorContent/EditorPanel"
@onready var scene_id_field: LineEdit = $"Margin/VBox/Tabs/Scenes/SceneEditor/EditorContent/EditorPanel/SceneIdSection/SceneIdField"
@onready var scene_desc_field: TextEdit = $"Margin/VBox/Tabs/Scenes/SceneEditor/EditorContent/EditorPanel/DescSection/DescField"
@onready var rules_field: TextEdit = $"Margin/VBox/Tabs/Scenes/SceneEditor/EditorContent/EditorPanel/RulesSection/RulesField"
@onready var entities_list: VBoxContainer = $"Margin/VBox/Tabs/Scenes/SceneEditor/EditorContent/EditorPanel/EntitiesSection/EntitiesList"
@onready var status_label: Label = $"Margin/VBox/Tabs/Scenes/SceneEditor/EditorContent/EditorPanel/SaveSection/StatusLabel"

# Entity editor dialog references
@onready var entity_editor_dialog: Window = $"Margin/VBox/Tabs/Scenes/EntityEditorDialog"
@onready var entity_id_field: LineEdit = $"Margin/VBox/Tabs/Scenes/EntityEditorDialog/EntityEditorContent/VBox/EntityIdSection/EntityIdField"
@onready var entity_type_field: LineEdit = $"Margin/VBox/Tabs/Scenes/EntityEditorDialog/EntityEditorContent/VBox/TypeSection/TypeField"
@onready var entity_verbs_field: LineEdit = $"Margin/VBox/Tabs/Scenes/EntityEditorDialog/EntityEditorContent/VBox/VerbsSection/VerbsField"
@onready var entity_tags_field: LineEdit = $"Margin/VBox/Tabs/Scenes/EntityEditorDialog/EntityEditorContent/VBox/TagsSection/TagsField"
@onready var entity_props_field: TextEdit = $"Margin/VBox/Tabs/Scenes/EntityEditorDialog/EntityEditorContent/VBox/PropsSection/PropsField"

# Exit wizard dialog references
@onready var exit_wizard_dialog: Window = $"Margin/VBox/Tabs/Scenes/ExitWizardDialog"
@onready var exit_id_field: LineEdit = $"Margin/VBox/Tabs/Scenes/ExitWizardDialog/WizardContent/VBox/ExitIdSection/ExitIdField"
@onready var exit_label_field: LineEdit = $"Margin/VBox/Tabs/Scenes/ExitWizardDialog/WizardContent/VBox/LabelSection/LabelField"
@onready var exit_desc_field: TextEdit = $"Margin/VBox/Tabs/Scenes/ExitWizardDialog/WizardContent/VBox/DescSection/DescField"
@onready var exit_leads_to_field: LineEdit = $"Margin/VBox/Tabs/Scenes/ExitWizardDialog/WizardContent/VBox/LeadsToSection/LeadsToField"

# Graph view references
@onready var graph_edit: GraphEdit = $"Margin/VBox/Tabs/Graph/GraphEdit"
@onready var open_area_dialog: Window = $"Margin/VBox/Tabs/Graph/OpenAreaDialog"
@onready var area_node_id_field: LineEdit = $"Margin/VBox/Tabs/Graph/OpenAreaDialog/OpenAreaContent/VBox/NodeIdSection/NodeIdField"
@onready var area_label_field: LineEdit = $"Margin/VBox/Tabs/Graph/OpenAreaDialog/OpenAreaContent/VBox/LabelSection/LabelField"
@onready var area_entry_scene_field: LineEdit = $"Margin/VBox/Tabs/Graph/OpenAreaDialog/OpenAreaContent/VBox/EntrySceneSection/EntrySceneField"
@onready var area_objective_kind: OptionButton = $"Margin/VBox/Tabs/Graph/OpenAreaDialog/OpenAreaContent/VBox/ObjectiveSection/ObjectiveKindSection/ObjectiveKindOption"
@onready var area_objective_entity_field: LineEdit = $"Margin/VBox/Tabs/Graph/OpenAreaDialog/OpenAreaContent/VBox/ObjectiveSection/ObjectiveEntitySection/ObjectiveEntityField"
@onready var area_objective_flag_field: LineEdit = $"Margin/VBox/Tabs/Graph/OpenAreaDialog/OpenAreaContent/VBox/ObjectiveSection/ObjectiveFlagSection/ObjectiveFlagField"
@onready var area_completion_scene_field: LineEdit = $"Margin/VBox/Tabs/Graph/OpenAreaDialog/OpenAreaContent/VBox/CompletionSection/CompletionSceneField"

signal closed()
signal playtest_requested(world_db: WorldDB)

var current_world_db: WorldDB = null
var validator: CampaignValidator = CampaignValidator.new()
var exporter: WorldExporter = null

# Scenes workspace state
var all_scene_ids: Array[String] = []
var filtered_scene_ids: Array[String] = []
var current_scene_id: String = ""
var current_scene: SceneGraph = null
var scene_dirty: bool = false

# Entity editor state
var editing_entity: Entity = null
var editing_entity_index: int = -1

# Graph view state
var links_data: Dictionary = {"nodes": [], "edges": []}
var editing_open_area_node: Dictionary = {}
var editing_open_area_index: int = -1

func _ready():
    # Instantiate exporter (needs to be a Node for file operations)
    exporter = WorldExporter.new()
    add_child(exporter)
    
    # Initialize objective kind dropdown
    area_objective_kind.clear()
    area_objective_kind.add_item("discover_entity", 0)
    area_objective_kind.add_item("interact_entity", 1)
    area_objective_kind.add_item("flag_equals", 2)

func show_studio():
    visible = true

func hide_studio():
    visible = false
    closed.emit()

## Open the studio with a specific world database
func open_with_world(world_db: WorldDB) -> void:
    current_world_db = world_db
    _refresh_dashboard()
    _refresh_scenes_list()
    _load_links_data()
    _rebuild_graph()
    show_studio()

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

## ========================================
## SCENES WORKSPACE
## ========================================

## Refresh the scenes list from current world
func _refresh_scenes_list() -> void:
    if current_world_db == null:
        all_scene_ids = []
        filtered_scene_ids = []
        _update_scene_list_display()
        return
    
    # Gather all scene IDs
    all_scene_ids.clear()
    for scene_id in current_world_db.scenes.keys():
        all_scene_ids.append(scene_id)
    all_scene_ids.sort()
    
    # Apply current search filter
    _apply_scene_search_filter()

## Apply search filter to scenes
func _apply_scene_search_filter() -> void:
    var search_text := search_box.text.strip_edges().to_lower()
    filtered_scene_ids.clear()
    
    if search_text.is_empty():
        filtered_scene_ids = all_scene_ids.duplicate()
    else:
        for scene_id in all_scene_ids:
            if scene_id.to_lower().contains(search_text):
                filtered_scene_ids.append(scene_id)
    
    _update_scene_list_display()

## Update the ItemList display with filtered scenes
func _update_scene_list_display() -> void:
    scene_item_list.clear()
    for scene_id in filtered_scene_ids:
        scene_item_list.add_item(scene_id)

## Scene list event handlers

func _on_search_scenes(_new_text: String) -> void:
    _apply_scene_search_filter()

func _on_add_scene_pressed() -> void:
    if current_world_db == null:
        return
    
    # Create a new scene with a unique ID
    var base_id := "new_scene"
    var scene_id := base_id
    var counter := 1
    while current_world_db.scenes.has(scene_id):
        scene_id = base_id + "_" + str(counter)
        counter += 1
    
    # Create new scene
    var new_scene := SceneGraph.new()
    new_scene.scene_id = scene_id
    new_scene.description = "A new scene."
    new_scene.entities = []
    new_scene.rules = {}
    
    # Add to world
    current_world_db.scenes[scene_id] = new_scene
    
    # Refresh list and select new scene
    _refresh_scenes_list()
    var idx := filtered_scene_ids.find(scene_id)
    if idx >= 0:
        scene_item_list.select(idx)
        _on_scene_selected(idx)

func _on_scene_selected(index: int) -> void:
    if index < 0 or index >= filtered_scene_ids.size():
        return
    
    # Check if current scene has unsaved changes
    if scene_dirty:
        # TODO: Could show a dialog asking to save changes
        pass
    
    # Load selected scene
    current_scene_id = filtered_scene_ids[index]
    _load_scene_into_editor(current_scene_id)

func _on_delete_scene_pressed() -> void:
    if current_world_db == null or current_scene_id.is_empty():
        return
    
    # TODO: Could show a confirmation dialog
    
    # Remove from world
    current_world_db.scenes.erase(current_scene_id)
    
    # Clear editor
    current_scene_id = ""
    current_scene = null
    scene_dirty = false
    no_selection_label.visible = true
    editor_panel.visible = false
    
    # Refresh list
    _refresh_scenes_list()

## Scene editor

func _load_scene_into_editor(scene_id: String) -> void:
    if current_world_db == null or not current_world_db.scenes.has(scene_id):
        return
    
    # Get scene - could be a SceneGraph object or a path string
    var scene_data = current_world_db.scenes[scene_id]
    if scene_data is String:
        # Load from path
        current_scene = load(scene_data) as SceneGraph
    elif scene_data is SceneGraph:
        current_scene = scene_data
    else:
        push_error("Invalid scene data for scene_id: " + scene_id)
        return
    
    if current_scene == null:
        push_error("Failed to load scene: " + scene_id)
        return
    
    current_scene_id = scene_id
    scene_dirty = false
    
    # Show editor, hide no-selection label
    no_selection_label.visible = false
    editor_panel.visible = true
    
    # Populate fields
    scene_id_field.text = current_scene.scene_id
    scene_desc_field.text = current_scene.description
    rules_field.text = JSON.stringify(current_scene.rules, "  ")
    
    # Populate entities list
    _refresh_entities_list()
    
    # Clear status
    status_label.text = ""

func _refresh_entities_list() -> void:
    # Clear existing entity cards
    for child in entities_list.get_children():
        child.queue_free()
    
    if current_scene == null:
        return
    
    # Create a card for each entity
    for i in range(current_scene.entities.size()):
        var entity: Entity = current_scene.entities[i]
        var card := _create_entity_card(entity, i)
        entities_list.add_child(card)

func _create_entity_card(entity: Entity, index: int) -> Control:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(0, 60)
    
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 8)
    margin.add_theme_constant_override("margin_right", 8)
    margin.add_theme_constant_override("margin_top", 8)
    margin.add_theme_constant_override("margin_bottom", 8)
    card.add_child(margin)
    
    var hbox := HBoxContainer.new()
    margin.add_child(hbox)
    
    # Entity info
    var vbox := VBoxContainer.new()
    vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hbox.add_child(vbox)
    
    var id_label := Label.new()
    id_label.text = entity.id + " [" + entity.type_name + "]"
    id_label.add_theme_font_size_override("font_size", 14)
    vbox.add_child(id_label)
    
    var desc_label := Label.new()
    var desc_text := str(entity.props.get("description", ""))
    if desc_text.length() > 60:
        desc_text = desc_text.substr(0, 60) + "..."
    desc_label.text = desc_text
    desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
    vbox.add_child(desc_label)
    
    # Buttons
    var edit_btn := Button.new()
    edit_btn.text = "Edit"
    edit_btn.pressed.connect(_on_edit_entity_pressed.bind(index))
    hbox.add_child(edit_btn)
    
    var delete_btn := Button.new()
    delete_btn.text = "Delete"
    delete_btn.pressed.connect(_on_delete_entity_pressed.bind(index))
    hbox.add_child(delete_btn)
    
    return card

func _on_edit_entity_pressed(index: int) -> void:
    if current_scene == null or index < 0 or index >= current_scene.entities.size():
        return
    
    editing_entity = current_scene.entities[index]
    editing_entity_index = index
    _open_entity_editor(editing_entity)

func _on_delete_entity_pressed(index: int) -> void:
    if current_scene == null or index < 0 or index >= current_scene.entities.size():
        return
    
    current_scene.entities.remove_at(index)
    _refresh_entities_list()
    _mark_scene_dirty()

func _on_add_entity_pressed() -> void:
    if current_scene == null:
        return
    
    # Create a new entity
    editing_entity = Entity.new()
    editing_entity.id = "new_entity"
    editing_entity.type_name = "item"
    editing_entity.verbs = ["examine"]
    editing_entity.props = {"description": "A new entity."}
    editing_entity_index = -1  # -1 means new entity
    
    _open_entity_editor(editing_entity)

func _on_exit_wizard_pressed() -> void:
    if current_scene == null:
        return
    
    # Clear wizard fields
    exit_id_field.text = "door_"
    exit_label_field.text = ""
    exit_desc_field.text = ""
    exit_leads_to_field.text = ""
    
    # Show wizard dialog
    exit_wizard_dialog.popup_centered()

func _on_save_scene_pressed() -> void:
    if current_scene == null or current_world_db == null:
        return
    
    # Read fields back into scene
    var old_scene_id := current_scene.scene_id
    var new_scene_id := scene_id_field.text.strip_edges()
    
    # Validate scene ID
    if new_scene_id.is_empty():
        status_label.text = "❌ Scene ID cannot be empty"
        return
    
    # Check for duplicate ID
    if new_scene_id != old_scene_id and current_world_db.scenes.has(new_scene_id):
        status_label.text = "❌ Scene ID already exists"
        return
    
    # Parse rules JSON
    var rules_json := JSON.new()
    var rules_error := rules_json.parse(rules_field.text)
    if rules_error != OK:
        status_label.text = "❌ Invalid JSON in rules"
        return
    
    # Update scene
    current_scene.scene_id = new_scene_id
    current_scene.description = scene_desc_field.text.strip_edges()
    current_scene.rules = rules_json.data if typeof(rules_json.data) == TYPE_DICTIONARY else {}
    
    # Handle scene ID change
    if new_scene_id != old_scene_id:
        current_world_db.scenes.erase(old_scene_id)
        current_world_db.scenes[new_scene_id] = current_scene
        current_scene_id = new_scene_id
        _refresh_scenes_list()
    else:
        # Update the scene in the world DB (in case it was loaded from a path)
        current_world_db.scenes[new_scene_id] = current_scene
    
    scene_dirty = false
    status_label.text = "✓ Saved"
    
    # Auto-clear status after 2 seconds
    await get_tree().create_timer(2.0).timeout
    if status_label.text == "✓ Saved":
        status_label.text = ""

func _on_revert_scene_pressed() -> void:
    if current_scene_id.is_empty():
        return
    
    # Reload scene from world
    _load_scene_into_editor(current_scene_id)

func _mark_scene_dirty() -> void:
    scene_dirty = true
    status_label.text = "● Unsaved changes"

## ========================================
## ENTITY EDITOR DIALOG
## ========================================

func _open_entity_editor(entity: Entity) -> void:
    # Populate fields
    entity_id_field.text = entity.id
    entity_type_field.text = entity.type_name
    entity_verbs_field.text = ", ".join(entity.verbs)
    entity_tags_field.text = ", ".join(entity.tags)
    entity_props_field.text = JSON.stringify(entity.props, "  ")
    
    # Show dialog
    entity_editor_dialog.popup_centered()

func _on_entity_editor_close() -> void:
    entity_editor_dialog.hide()
    editing_entity = null
    editing_entity_index = -1

func _on_entity_save_pressed() -> void:
    if editing_entity == null or current_scene == null:
        return
    
    # Read fields
    var entity_id := entity_id_field.text.strip_edges()
    if entity_id.is_empty():
        push_warning("Entity ID cannot be empty")
        return
    
    # Check for duplicate ID (only if new or changed)
    if editing_entity_index < 0 or editing_entity.id != entity_id:
        for i in range(current_scene.entities.size()):
            if i != editing_entity_index and current_scene.entities[i].id == entity_id:
                push_warning("Entity ID already exists in this scene")
                return
    
    # Parse props JSON
    var props_json := JSON.new()
    var props_error := props_json.parse(entity_props_field.text)
    if props_error != OK:
        push_warning("Invalid JSON in properties")
        return
    
    # Update entity
    editing_entity.id = entity_id
    editing_entity.type_name = entity_type_field.text.strip_edges()
    editing_entity.verbs = _parse_comma_list(entity_verbs_field.text)
    editing_entity.tags = _parse_comma_list(entity_tags_field.text)
    editing_entity.props = props_json.data if typeof(props_json.data) == TYPE_DICTIONARY else {}
    
    # Add to scene if new
    if editing_entity_index < 0:
        current_scene.entities.append(editing_entity)
    
    # Refresh and close
    _refresh_entities_list()
    _mark_scene_dirty()
    _on_entity_editor_close()

## ========================================
## EXIT WIZARD DIALOG
## ========================================

func _on_exit_wizard_close() -> void:
    exit_wizard_dialog.hide()

func _on_exit_wizard_create() -> void:
    if current_scene == null:
        return
    
    var exit_id := exit_id_field.text.strip_edges()
    if exit_id.is_empty():
        push_warning("Exit ID cannot be empty")
        return
    
    var leads_to := exit_leads_to_field.text.strip_edges()
    if leads_to.is_empty():
        push_warning("Exit must lead to a scene")
        return
    
    # Check for duplicate ID
    for entity in current_scene.entities:
        if entity.id == exit_id:
            push_warning("Entity ID already exists in this scene")
            return
    
    # Create exit entity
    var exit_entity := Entity.new()
    exit_entity.id = exit_id
    exit_entity.type_name = "exit"
    exit_entity.verbs = ["move"]
    exit_entity.props = {
        "description": exit_desc_field.text.strip_edges(),
        "leads": leads_to
    }
    
    # Add label if provided
    var label_text := exit_label_field.text.strip_edges()
    if not label_text.is_empty():
        exit_entity.props["label"] = label_text
    
    # Add to scene
    current_scene.entities.append(exit_entity)
    
    # Refresh and close
    _refresh_entities_list()
    _mark_scene_dirty()
    _on_exit_wizard_close()

## ========================================
## LINK GRAPH VIEW
## ========================================

## Load links.json from world flags or create empty structure
func _load_links_data() -> void:
    if current_world_db == null:
        links_data = {"nodes": [], "edges": []}
        return
    
    # Check if links data is stored in world flags
    var links_json: String = str(current_world_db.flags.get("links_json", ""))
    if not links_json.is_empty():
        var parser := JSON.new()
        var error := parser.parse(links_json)
        if error == OK and parser.data is Dictionary:
            links_data = parser.data
            if not links_data.has("nodes"):
                links_data["nodes"] = []
            if not links_data.has("edges"):
                links_data["edges"] = []
            return
    
    # No links data yet, create empty
    links_data = {"nodes": [], "edges": []}

## Save links data back to world flags
func _save_links_data() -> void:
    if current_world_db == null:
        return
    
    current_world_db.flags["links_json"] = JSON.stringify(links_data, "  ")

## Rebuild the entire graph from scenes and links data
func _rebuild_graph() -> void:
    # Clear existing graph
    graph_edit.clear_connections()
    for child in graph_edit.get_children():
        if child is GraphNode:
            child.queue_free()
    
    if current_world_db == null:
        return
    
    # Build nodes from links_data AND from scenes
    var node_ids_in_links: Dictionary = {}
    
    # First, add nodes from links.json
    for node_def in links_data.get("nodes", []):
        if node_def is Dictionary:
            var node_id: String = str(node_def.get("id", ""))
            if not node_id.is_empty():
                node_ids_in_links[node_id] = true
                _create_graph_node(node_def)
    
    # Then, add scene nodes that aren't in links.json
    for scene_id in current_world_db.scenes.keys():
        if not node_ids_in_links.has(scene_id):
            # Auto-create a scene node
            var node_def := {
                "id": scene_id,
                "type": "scene",
                "scene_id": scene_id
            }
            _create_graph_node(node_def)
    
    # Build edges from links_data
    for edge_def in links_data.get("edges", []):
        if edge_def is Dictionary:
            var from_node: String = str(edge_def.get("from", ""))
            var to_node: String = str(edge_def.get("to", ""))
            if not from_node.is_empty() and not to_node.is_empty():
                # Find ports (for now use port 0)
                graph_edit.connect_node(from_node, 0, to_node, 0)
    
    # Also detect edges from exit entities
    _add_exit_edges_to_graph()

## Add edges derived from exit entities in scenes
func _add_exit_edges_to_graph() -> void:
    if current_world_db == null:
        return
    
    for scene_id in current_world_db.scenes.keys():
        var scene_data = current_world_db.scenes[scene_id]
        var scene: SceneGraph = null
        
        if scene_data is String:
            scene = load(scene_data) as SceneGraph
        elif scene_data is SceneGraph:
            scene = scene_data
        
        if scene == null:
            continue
        
        # Find exit entities
        for entity in scene.entities:
            if entity.type_name == "exit":
                var leads_to: String = str(entity.props.get("leads", ""))
                if not leads_to.is_empty():
                    # Check if this edge already exists in links_data
                    var edge_exists := false
                    for edge_def in links_data.get("edges", []):
                        if edge_def is Dictionary:
                            if str(edge_def.get("from", "")) == scene_id and str(edge_def.get("to", "")) == leads_to:
                                edge_exists = true
                                break
                    
                    # Add edge if both nodes exist and edge doesn't exist
                    if not edge_exists and graph_edit.has_node(scene_id) and graph_edit.has_node(leads_to):
                        graph_edit.connect_node(scene_id, 0, leads_to, 0)

## Create a GraphNode from a node definition
func _create_graph_node(node_def: Dictionary) -> GraphNode:
    var node_id: String = str(node_def.get("id", ""))
    var node_type: String = str(node_def.get("type", "scene"))
    
    var graph_node := GraphNode.new()
    graph_node.name = node_id
    graph_node.title = node_id
    graph_node.draggable = true
    graph_node.selectable = true
    graph_node.resizable = false
    
    # Set slots for connections
    graph_node.set_slot(0, true, 0, Color.WHITE, true, 0, Color.WHITE)
    
    # Style based on type
    if node_type == "open_area":
        graph_node.title = str(node_def.get("label", node_id))
        # Add visual indicator for open area
        var label := Label.new()
        label.text = "🗺 Open Area"
        label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
        graph_node.add_child(label)
    else:
        # Regular scene node
        var label := Label.new()
        label.text = "📍 Scene"
        graph_node.add_child(label)
    
    # Add to graph
    graph_edit.add_child(graph_node)
    
    # Position (try to load from node_def or use auto-layout later)
    if node_def.has("position") and node_def.position is Vector2:
        graph_node.position_offset = node_def.position
    else:
        # Random initial position
        graph_node.position_offset = Vector2(randf() * 400, randf() * 300)
    
    return graph_node

## Graph event handlers

func _on_refresh_graph_pressed() -> void:
    _rebuild_graph()

func _on_add_scene_node_pressed() -> void:
    if current_world_db == null:
        return
    
    # Generate unique ID
    var base_id := "node"
    var node_id := base_id
    var counter := 1
    while _node_exists_in_links(node_id):
        node_id = base_id + "_" + str(counter)
        counter += 1
    
    # Create node def
    var node_def := {
        "id": node_id,
        "type": "scene",
        "scene_id": ""
    }
    
    # Add to links
    if not links_data.has("nodes"):
        links_data["nodes"] = []
    links_data["nodes"].append(node_def)
    _save_links_data()
    
    # Rebuild graph
    _rebuild_graph()

func _on_add_open_area_pressed() -> void:
    if current_world_db == null:
        return
    
    # Create new open area with defaults
    editing_open_area_node = {
        "id": "open_area_" + str(randi() % 10000),
        "type": "open_area",
        "label": "New Area",
        "entry_template": {"scene": ""},
        "objective": {"kind": "discover_entity", "entity_id": ""},
        "on_complete": {"goto_scene_id": ""}
    }
    editing_open_area_index = -1
    
    _open_open_area_editor(editing_open_area_node)

func _on_auto_layout_pressed() -> void:
    # Simple force-directed layout
    var nodes := graph_edit.get_children().filter(func(n): return n is GraphNode)
    
    if nodes.size() == 0:
        return
    
    # Arrange in a grid for simplicity
    var cols := int(ceil(sqrt(nodes.size())))
    var spacing := Vector2(250, 200)
    var start_pos := Vector2(50, 50)
    
    for i in range(nodes.size()):
        var node: GraphNode = nodes[i]
        @warning_ignore("integer_division")
        var row := i / cols
        var col := i % cols
        node.position_offset = start_pos + Vector2(col * spacing.x, row * spacing.y)
        
        # Save position to links_data
        _save_node_position(node.name, node.position_offset)
    
    _save_links_data()

func _on_graph_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
    # Create edge
    graph_edit.connect_node(from_node, from_port, to_node, to_port)
    
    # Add to links_data
    var edge_def := {
        "from": str(from_node),
        "to": str(to_node),
        "label": ""
    }
    
    if not links_data.has("edges"):
        links_data["edges"] = []
    links_data["edges"].append(edge_def)
    _save_links_data()

func _on_graph_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
    # Remove edge
    graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
    
    # Remove from links_data
    var edges: Array = links_data.get("edges", [])
    for i in range(edges.size() - 1, -1, -1):
        var edge_def = edges[i]
        if edge_def is Dictionary:
            if str(edge_def.get("from", "")) == str(from_node) and str(edge_def.get("to", "")) == str(to_node):
                edges.remove_at(i)
                break
    
    _save_links_data()

func _on_graph_node_selected(node: Node) -> void:
    if not (node is GraphNode):
        return
    
    var node_id: String = node.name
    
    # Find node in links_data
    var node_def: Dictionary = _find_node_in_links(node_id)
    
    if node_def.is_empty():
        # Not in links, might be auto-generated scene node
        # Open scene editor if scene exists
        if current_world_db.scenes.has(node_id):
            # Switch to Scenes tab and load this scene
            tab_container.current_tab = 1  # Scenes tab
            var idx := filtered_scene_ids.find(node_id)
            if idx >= 0:
                scene_item_list.select(idx)
                _on_scene_selected(idx)
        return
    
    # Check type
    var node_type: String = str(node_def.get("type", "scene"))
    if node_type == "open_area":
        # Open open area editor
        editing_open_area_node = node_def
        editing_open_area_index = links_data["nodes"].find(node_def)
        _open_open_area_editor(node_def)
    else:
        # Open scene editor
        var scene_id: String = str(node_def.get("scene_id", node_id))
        if current_world_db.scenes.has(scene_id):
            tab_container.current_tab = 1  # Scenes tab
            var idx := filtered_scene_ids.find(scene_id)
            if idx >= 0:
                scene_item_list.select(idx)
                _on_scene_selected(idx)

## ========================================
## OPEN AREA EDITOR DIALOG
## ========================================

func _open_open_area_editor(node_def: Dictionary) -> void:
    # Populate fields
    area_node_id_field.text = str(node_def.get("id", ""))
    area_label_field.text = str(node_def.get("label", ""))
    
    var entry_template: Dictionary = node_def.get("entry_template", {})
    area_entry_scene_field.text = str(entry_template.get("scene", ""))
    
    var objective: Dictionary = node_def.get("objective", {})
    var obj_kind: String = str(objective.get("kind", "discover_entity"))
    
    # Set objective kind dropdown
    var kind_idx := 0
    if obj_kind == "interact_entity":
        kind_idx = 1
    elif obj_kind == "flag_equals":
        kind_idx = 2
    area_objective_kind.selected = kind_idx
    
    area_objective_entity_field.text = str(objective.get("entity_id", ""))
    
    # For flag_equals, format as "flag=value"
    if obj_kind == "flag_equals":
        var flag_key: String = str(objective.get("flag", ""))
        var flag_value: String = str(objective.get("value", ""))
        area_objective_flag_field.text = flag_key + "=" + flag_value
    else:
        area_objective_flag_field.text = ""
    
    var on_complete: Dictionary = node_def.get("on_complete", {})
    area_completion_scene_field.text = str(on_complete.get("goto_scene_id", ""))
    
    # Show dialog
    open_area_dialog.popup_centered()

func _on_open_area_dialog_close() -> void:
    open_area_dialog.hide()
    editing_open_area_node = {}
    editing_open_area_index = -1

func _on_open_area_save_pressed() -> void:
    if editing_open_area_node.is_empty():
        return
    
    # Read fields
    var node_id := area_node_id_field.text.strip_edges()
    if node_id.is_empty():
        push_warning("Node ID cannot be empty")
        return
    
    # Update node_def
    var old_id: String = str(editing_open_area_node.get("id", ""))
    editing_open_area_node["id"] = node_id
    editing_open_area_node["type"] = "open_area"
    editing_open_area_node["label"] = area_label_field.text.strip_edges()
    
    editing_open_area_node["entry_template"] = {
        "scene": area_entry_scene_field.text.strip_edges()
    }
    
    # Build objective
    var obj_kind_idx := area_objective_kind.selected
    var obj_kind := "discover_entity"
    if obj_kind_idx == 1:
        obj_kind = "interact_entity"
    elif obj_kind_idx == 2:
        obj_kind = "flag_equals"
    
    var objective := {
        "kind": obj_kind
    }
    
    if obj_kind in ["discover_entity", "interact_entity"]:
        objective["entity_id"] = area_objective_entity_field.text.strip_edges()
    elif obj_kind == "flag_equals":
        # Parse "flag=value"
        var flag_text := area_objective_flag_field.text.strip_edges()
        var parts := flag_text.split("=", false, 1)
        if parts.size() == 2:
            objective["flag"] = parts[0].strip_edges()
            objective["value"] = parts[1].strip_edges()
    
    editing_open_area_node["objective"] = objective
    
    editing_open_area_node["on_complete"] = {
        "goto_scene_id": area_completion_scene_field.text.strip_edges()
    }
    
    # Add to or update links_data
    if editing_open_area_index < 0:
        # New node
        if not links_data.has("nodes"):
            links_data["nodes"] = []
        links_data["nodes"].append(editing_open_area_node)
    else:
        # Update existing
        links_data["nodes"][editing_open_area_index] = editing_open_area_node
        
        # If ID changed, update edges
        if old_id != node_id:
            for edge_def in links_data.get("edges", []):
                if edge_def is Dictionary:
                    if str(edge_def.get("from", "")) == old_id:
                        edge_def["from"] = node_id
                    if str(edge_def.get("to", "")) == old_id:
                        edge_def["to"] = node_id
    
    _save_links_data()
    _rebuild_graph()
    _on_open_area_dialog_close()

## ========================================
## GRAPH UTILITIES
## ========================================

func _node_exists_in_links(node_id: String) -> bool:
    for node_def in links_data.get("nodes", []):
        if node_def is Dictionary:
            if str(node_def.get("id", "")) == node_id:
                return true
    return false

func _find_node_in_links(node_id: String) -> Dictionary:
    for node_def in links_data.get("nodes", []):
        if node_def is Dictionary:
            if str(node_def.get("id", "")) == node_id:
                return node_def
    return {}

func _save_node_position(node_id: String, pos: Vector2) -> void:
    for node_def in links_data.get("nodes", []):
        if node_def is Dictionary:
            if str(node_def.get("id", "")) == node_id:
                node_def["position"] = pos
                return

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


