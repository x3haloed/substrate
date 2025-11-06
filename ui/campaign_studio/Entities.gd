extends Control

## Entities Tab — Manage world-level entity definitions (world.entities)

var _current_world_db: WorldDB = null
var current_world_db: WorldDB = null: set = set_world_db, get = get_world_db
var selected_entity_id: String = ""

@onready var list: ItemList = $Margin/HBox/LeftPanel/EntityList
@onready var add_button: Button = $Margin/HBox/LeftPanel/Header/AddButton
@onready var delete_button: Button = $Margin/HBox/LeftPanel/Header/DeleteButton
@onready var form: VBoxContainer = $Margin/HBox/RightPanel/Form
@onready var no_selection_label: Label = $Margin/HBox/RightPanel/NoSelection
@onready var id_edit: LineEdit = $Margin/HBox/RightPanel/Form/IdRow/IdEdit
@onready var type_edit: LineEdit = $Margin/HBox/RightPanel/Form/TypeRow/TypeEdit
@onready var verbs_edit: LineEdit = $Margin/HBox/RightPanel/Form/VerbsRow/VerbsEdit
@onready var tags_edit: LineEdit = $Margin/HBox/RightPanel/Form/TagsRow/TagsEdit
@onready var props_edit: TextEdit = $Margin/HBox/RightPanel/Form/PropsEdit
@onready var save_button: Button = $Margin/HBox/RightPanel/Form/SaveButton

func _ready() -> void:
	list.item_selected.connect(_on_item_selected)
	list.item_clicked.connect(_on_item_clicked)
	add_button.pressed.connect(_on_add_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	save_button.pressed.connect(_on_save_pressed)
	_clear_form()

func set_world_db(world_db: WorldDB) -> void:
	_current_world_db = world_db
	selected_entity_id = ""
	_refresh_list()
	_clear_form()

func get_world_db() -> WorldDB:
	return _current_world_db

func _refresh_list() -> void:
	list.clear()
	delete_button.disabled = true
	if current_world_db == null:
		return
	var ids: Array[String] = []
	for k in current_world_db.entities.keys():
		ids.append(str(k))
	ids.sort()
	for id in ids:
		list.add_item(id)
		list.set_item_metadata(list.item_count - 1, id)
	if selected_entity_id != "":
		for i in range(list.item_count):
			if str(list.get_item_metadata(i)) == selected_entity_id:
				list.select(i)
				_on_item_selected(i)
				break

func _on_item_selected(index: int) -> void:
	if index < 0 or index >= list.item_count:
		return
	var id := str(list.get_item_metadata(index))
	_show_entity(id)

func _on_item_clicked(index: int, _at_position: Vector2, _button: int) -> void:
	_on_item_selected(index)

func _show_entity(entity_id: String) -> void:
	if current_world_db == null:
		return
	var data: Variant = current_world_db.entities.get(entity_id, null)
	selected_entity_id = entity_id
	delete_button.disabled = false
	no_selection_label.visible = false
	form.visible = true
	id_edit.text = entity_id
	var type_name := ""
	var verbs: Array[String] = []
	var tags: Array[String] = []
	var props: Dictionary = {}
	if data is Dictionary:
		type_name = str(data.get("type_name", data.get("type", "")))
		var raw_verbs = data.get("verbs", [])
		if raw_verbs is Array:
			for v in raw_verbs:
				verbs.append(str(v))
		var raw_tags = data.get("tags", [])
		if raw_tags is Array:
			for t in raw_tags:
				tags.append(str(t))
		props = data.get("props", {})
	type_edit.text = type_name
	verbs_edit.text = ", ".join(verbs)
	tags_edit.text = ", ".join(tags)
	props_edit.text = JSON.stringify(props, "  ")

func _on_add_pressed() -> void:
	if current_world_db == null:
		return
	var base := "entity"
	var i := list.item_count + 1
	var id := "%s_%02d" % [base, i]
	while current_world_db.entities.has(id):
		i += 1
		id = "%s_%02d" % [base, i]
	current_world_db.entities[id] = {"type_name": "item", "verbs": ["examine"], "tags": [], "props": {"description": ""}}
	selected_entity_id = id
	_refresh_list()
	_show_entity(id)
	id_edit.grab_focus()

func _on_delete_pressed() -> void:
	if current_world_db == null or selected_entity_id == "":
		return
	current_world_db.entities.erase(selected_entity_id)
	selected_entity_id = ""
	_refresh_list()
	_clear_form()

func _on_save_pressed() -> void:
	if current_world_db == null or selected_entity_id == "":
		return
	var new_id := IdUtil.normalize_id(id_edit.text.strip_edges())
	if new_id == "":
		push_warning("ID cannot be empty.")
		return
	# Avoid collisions
	if new_id != selected_entity_id and current_world_db.entities.has(new_id):
		push_warning("Another entity already uses id '%s'." % new_id)
		return
	var type_name := type_edit.text.strip_edges()
	var verbs_arr: Array[String] = []
	for v in verbs_edit.text.split(","):
		var vv := str(v).strip_edges()
		if vv != "":
			verbs_arr.append(vv)
	var tags_arr: Array[String] = []
	for t in tags_edit.text.split(","):
		var tt := str(t).strip_edges()
		if tt != "":
			tags_arr.append(tt)
	var props_dict: Dictionary = {}
	var j := JSON.new()
	if j.parse(props_edit.text) == OK and j.data is Dictionary:
		props_dict = j.data
	# Move if id changed
	if new_id != selected_entity_id:
		current_world_db.entities.erase(selected_entity_id)
		selected_entity_id = new_id
	current_world_db.entities[new_id] = {
		"id": new_id,
		"type_name": type_name,
		"verbs": verbs_arr,
		"tags": tags_arr,
		"props": props_dict
	}
	_refresh_list()

func _clear_form() -> void:
	delete_button.disabled = true
	no_selection_label.visible = true
	form.visible = false
	id_edit.text = ""
	type_edit.text = ""
	verbs_edit.text = ""
	tags_edit.text = ""
	props_edit.text = ""
