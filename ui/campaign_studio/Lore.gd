extends Control

## Lore Tab — Manage global lore entries for the campaign

var _current_world_db: WorldDB = null
var current_world_db: WorldDB = null: set = set_world_db, get = get_world_db
var selected_entry_id: String = ""

@onready var entry_list: ItemList = $Margin/HBox/LeftPanel/EntryList
@onready var add_button: Button = $Margin/HBox/LeftPanel/Header/AddButton
@onready var delete_button: Button = $Margin/HBox/LeftPanel/Header/DeleteButton
@onready var no_selection_label: Label = $Margin/HBox/RightPanel/NoSelection
@onready var scroll_container: ScrollContainer = $Margin/HBox/RightPanel/Scroll
@onready var form: VBoxContainer = $Margin/HBox/RightPanel/Scroll/Form
@onready var entry_id_edit: LineEdit = $Margin/HBox/RightPanel/Scroll/Form/EntryIdRow/EntryIdEdit
@onready var title_edit: LineEdit = $Margin/HBox/RightPanel/Scroll/Form/TitleRow/TitleEdit
@onready var category_edit: LineEdit = $Margin/HBox/RightPanel/Scroll/Form/CategoryRow/CategoryEdit
@onready var visibility_option: OptionButton = $Margin/HBox/RightPanel/Scroll/Form/VisibilityRow/VisibilityOption
@onready var related_list: ItemList = $Margin/HBox/RightPanel/Scroll/Form/RelatedEntities
@onready var entity_picker: OptionButton = $Margin/HBox/RightPanel/Scroll/Form/RelatedButtons/EntityPicker
@onready var add_related_button: Button = $Margin/HBox/RightPanel/Scroll/Form/RelatedButtons/AddRelatedButton
@onready var remove_related_button: Button = $Margin/HBox/RightPanel/Scroll/Form/RelatedButtons/RemoveRelatedButton
@onready var assign_global_button: Button = $Margin/HBox/RightPanel/Scroll/Form/RelatedButtons/AssignGlobalButton
@onready var summary_edit: TextEdit = $Margin/HBox/RightPanel/Scroll/Form/SummaryEdit
@onready var article_edit: TextEdit = $Margin/HBox/RightPanel/Scroll/Form/ArticleEdit
@onready var unlock_edit: TextEdit = $Margin/HBox/RightPanel/Scroll/Form/UnlockEdit
@onready var tags_edit: LineEdit = $Margin/HBox/RightPanel/Scroll/Form/TagsRow/TagsEdit
@onready var notes_edit: TextEdit = $Margin/HBox/RightPanel/Scroll/Form/NotesEdit
@onready var save_button: Button = $Margin/HBox/RightPanel/Scroll/Form/SaveButton

@onready var sections_list: ItemList = $Margin/HBox/RightPanel/Scroll/Form/SectionsRow/SectionsListPanel/SectionsList
@onready var add_section_button: Button = $Margin/HBox/RightPanel/Scroll/Form/SectionsRow/SectionsListPanel/SectionsButtons/AddSectionButton
@onready var remove_section_button: Button = $Margin/HBox/RightPanel/Scroll/Form/SectionsRow/SectionsListPanel/SectionsButtons/RemoveSectionButton
@onready var section_id_edit: LineEdit = $Margin/HBox/RightPanel/Scroll/Form/SectionsRow/SectionEditor/SectionIdRow/SectionIdEdit
@onready var section_title_edit: LineEdit = $Margin/HBox/RightPanel/Scroll/Form/SectionsRow/SectionEditor/SectionTitleRow/SectionTitleEdit
@onready var section_unlock_edit: TextEdit = $Margin/HBox/RightPanel/Scroll/Form/SectionsRow/SectionEditor/SectionUnlockEdit
@onready var section_body_edit: TextEdit = $Margin/HBox/RightPanel/Scroll/Form/SectionsRow/SectionEditor/SectionBodyEdit

var _visibility_map := {
	LoreEntry.VISIBILITY_ALWAYS: "Always Visible",
	LoreEntry.VISIBILITY_DISCOVERED: "Unlock on Discovery",
	LoreEntry.VISIBILITY_HIDDEN: "Hidden"
}

func _ready() -> void:
	entry_list.item_selected.connect(_on_entry_selected)
	if entry_list.has_signal("item_clicked"):	# workaround ?
		entry_list.item_clicked.connect(_on_entry_clicked)
	add_button.pressed.connect(_on_add_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	add_related_button.pressed.connect(_on_add_related_pressed)
	remove_related_button.pressed.connect(_on_remove_related_pressed)
	assign_global_button.pressed.connect(_on_assign_global_pressed)
	save_button.pressed.connect(_on_save_pressed)
	sections_list.item_selected.connect(_on_section_selected)
	if sections_list.has_signal("item_clicked"):
		sections_list.item_clicked.connect(_on_section_clicked)
	add_section_button.pressed.connect(_on_add_section_pressed)
	remove_section_button.pressed.connect(_on_remove_section_pressed)
	visibility_option.clear()
	for key in _visibility_map.keys():
		visibility_option.add_item(_visibility_map[key])
		visibility_option.set_item_metadata(visibility_option.item_count - 1, key)
	_clear_form()

func set_world_db(world_db: WorldDB) -> void:
	_current_world_db = world_db
	selected_entry_id = ""
	ensure_world_lore_db()
	_refresh_entries_list()
	_populate_entity_picker()
	_clear_form()

func get_world_db() -> WorldDB:
	return _current_world_db

func ensure_world_lore_db() -> LoreDB:
	if current_world_db == null:
		return null
	return current_world_db.ensure_lore_database()

func _refresh_entries_list() -> void:
	entry_list.clear()
	delete_button.disabled = true
	if current_world_db == null or current_world_db.lore_db == null:
		return
	var entries := current_world_db.lore_db.list_entries()
	entries.sort_custom(func(a, b):
		var title_a: String = a.title if a.title != "" else a.entry_id
		var title_b: String = b.title if b.title != "" else b.entry_id
		return title_a.to_lower() < title_b.to_lower()
	)
	for entry in entries:
		var label := entry.title if entry.title != "" else entry.entry_id
		entry_list.add_item(label)
		entry_list.set_item_metadata(entry_list.item_count - 1, entry.entry_id)
	if selected_entry_id != "":
		for i in range(entry_list.item_count):
			if str(entry_list.get_item_metadata(i)) == selected_entry_id:
				entry_list.select(i)
				_on_entry_selected(i)
				break

func _populate_entity_picker() -> void:
	entity_picker.clear()
	entity_picker.add_item("Select entity…", 0)
	if current_world_db == null:
		return
	var ids: Array[String] = []
	# Collect scene entities
	for scene_id in current_world_db.scenes.keys():
		var scene: SceneGraph = current_world_db.get_scene(scene_id)
		if scene:
			for entity in scene.entities:
				if entity.id != "" and not (entity.id in ids):
					ids.append(entity.id)
	# Include global entities map
	for eid in current_world_db.entities.keys():
		if not (eid in ids):
			ids.append(eid)
	ids.sort()
	for id in ids:
		entity_picker.add_item(id)

func _on_entry_selected(index: int) -> void:
	if index < 0 or index >= entry_list.item_count:
		return
	var entry_id := str(entry_list.get_item_metadata(index))
	_show_entry(entry_id)

# workaround ?
func _on_entry_clicked(index: int, _at_position: Vector2, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT:
		entry_list.select(index)
		_on_entry_selected(index)

func _show_entry(entry_id: String) -> void:
	if current_world_db == null or current_world_db.lore_db == null:
		return
	var entry := current_world_db.lore_db.get_entry(entry_id)
	if entry == null:
		_clear_form()
		return
	selected_entry_id = entry_id
	delete_button.disabled = false
	no_selection_label.visible = false
	scroll_container.visible = true
	entry_id_edit.text = entry.entry_id
	title_edit.text = entry.title
	category_edit.text = entry.category
	_set_visibility(entry.default_visibility)
	related_list.clear()
	for rel in entry.related_entity_ids:
		related_list.add_item(str(rel))
	summary_edit.text = entry.summary
	article_edit.text = entry.article
	unlock_edit.text = "\n".join(entry.unlock_conditions)
	tags_edit.text = ", ".join(entry.tags)
	notes_edit.text = "\n".join(entry.notes)
	_populate_sections(entry)

func _set_visibility(value: String) -> void:
	var normalized := value if value != "" else LoreEntry.VISIBILITY_DISCOVERED
	for i in range(visibility_option.item_count):
		if str(visibility_option.get_item_metadata(i)) == normalized:
			visibility_option.select(i)
			return
	visibility_option.select(0)

func _on_add_pressed() -> void:
	if current_world_db == null:
		return
	var lore_db := ensure_world_lore_db()
	if lore_db == null:
		return
	var new_entry := LoreEntry.new()
	new_entry.entry_id = _generate_entry_id()
	new_entry.title = "New Entry"
	new_entry.summary = ""
	new_entry.article = ""
	lore_db.register_entry(new_entry)
	selected_entry_id = new_entry.entry_id
	_refresh_entries_list()
	_show_entry(selected_entry_id)
	entry_id_edit.grab_focus()

func _on_delete_pressed() -> void:
	if current_world_db == null or current_world_db.lore_db == null:
		return
	if selected_entry_id == "":
		return
	current_world_db.lore_db.entries.erase(selected_entry_id)
	current_world_db.unlocked_lore_entries.erase(selected_entry_id)
	selected_entry_id = ""
	_refresh_entries_list()
	_clear_form()

func _on_add_related_pressed() -> void:
	if entity_picker.item_count == 0:
		return
	var idx := entity_picker.get_selected()
	if idx <= 0:
		return
	var entity_id := entity_picker.get_item_text(idx)
	for i in range(related_list.item_count):
		if related_list.get_item_text(i) == entity_id:
			return
	related_list.add_item(entity_id)

func _on_remove_related_pressed() -> void:
	var selected := related_list.get_selected_items()
	if selected.is_empty():
		return
	for index in selected:
		if index >= 0 and index < related_list.item_count:
			related_list.remove_item(index)

func _on_assign_global_pressed() -> void:
	if current_world_db == null or selected_entry_id == "":
		return
	var idx := entity_picker.get_selected()
	if idx <= 0:
		return
	var entity_id := entity_picker.get_item_text(idx)
	var entry_id := selected_entry_id
	if not current_world_db.entities.has(entity_id) or not (current_world_db.entities[entity_id] is Dictionary):
		current_world_db.entities[entity_id] = {}
	var data: Dictionary = current_world_db.entities[entity_id]
	data["lore_entry_id"] = entry_id
	current_world_db.entities[entity_id] = data
	# Ensure related list contains entity for context
	var already := false
	for i in range(related_list.item_count):
		if related_list.get_item_text(i) == entity_id:
			already = true
			break
	if not already:
		related_list.add_item(entity_id)

func _on_save_pressed() -> void:
	if current_world_db == null or current_world_db.lore_db == null:
		return
	if selected_entry_id == "":
		return
	var entry := current_world_db.lore_db.get_entry(selected_entry_id)
	if entry == null:
		return
	var new_id := entry_id_edit.text.strip_edges()
	if new_id == "":
		push_warning("Entry ID cannot be empty.")
		entry_id_edit.grab_focus()
		return
	# Normalize entry id for consistency
	new_id = IdUtil.normalize_id(new_id)
	var new_title := title_edit.text.strip_edges()
	var new_category := category_edit.text.strip_edges()
	var new_visibility := _get_selected_visibility()
	var new_related := _collect_related_entities()
	# Normalize related entity ids
	for i in range(new_related.size()):
		new_related[i] = IdUtil.normalize_id(str(new_related[i]))
	var new_summary := summary_edit.text.strip_edges()
	var new_article := article_edit.text.strip_edges()
	var new_unlock := _collect_lines(unlock_edit.text)
	# Normalize reference tokens (discover:, lore:, or bare ids)
	for i in range(new_unlock.size()):
		new_unlock[i] = IdUtil.normalize_ref_token(str(new_unlock[i]))
	var new_tags := _parse_csv(tags_edit.text)
	var new_notes := _collect_lines(notes_edit.text)

	var id_changed := new_id != entry.entry_id

	if id_changed:
		# Avoid collisions
		if current_world_db.lore_db.entries.has(new_id) and new_id != selected_entry_id:
			push_warning("Another lore entry already uses id '%s'." % new_id)
			return
		current_world_db.lore_db.entries.erase(entry.entry_id)
		entry.entry_id = new_id

	entry.title = new_title
	entry.category = new_category
	entry.default_visibility = new_visibility
	entry.related_entity_ids = new_related
	entry.summary = new_summary
	entry.article = new_article
	entry.unlock_conditions = new_unlock
	entry.tags = new_tags
	entry.notes = new_notes
	# Save sections (apply editor changes to selected first)
	_apply_section_editor_to_metadata()
	var new_sections: Array[LoreSection] = []
	for i in range(sections_list.item_count):
		var meta: Variant = sections_list.get_item_metadata(i)
		if meta is LoreSection:
			new_sections.append(meta)
	entry.sections = new_sections

	# Re-register to ensure cache updates and id mapping stored
	current_world_db.lore_db.register_entry(entry)
	if id_changed:
		# Update unlocked tracking map keys
		if current_world_db.unlocked_lore_entries.has(selected_entry_id):
			var was_unlocked: bool = current_world_db.unlocked_lore_entries[selected_entry_id]
			current_world_db.unlocked_lore_entries.erase(selected_entry_id)
			current_world_db.unlocked_lore_entries[new_id] = was_unlocked
		selected_entry_id = new_id
	_update_related_entity_bindings(entry.entry_id, new_related)
	_refresh_entries_list()

func _update_related_entity_bindings(entry_id: String, related: Array[String]) -> void:
	if current_world_db == null:
		return
	for entity_id in related:
		var data: Variant = current_world_db.entities.get(entity_id, null)
		if data is Dictionary and data.get("lore_entry_id", "") == "":
			data["lore_entry_id"] = entry_id
			current_world_db.entities[entity_id] = data

func _collect_related_entities() -> Array[String]:
	var list: Array[String] = []
	for i in range(related_list.item_count):
		list.append(related_list.get_item_text(i))
	return list

func _collect_lines(text: String) -> Array[String]:
	var lines: Array[String] = []
	for raw in text.split("\n"):
		var trimmed := raw.strip_edges()
		if trimmed != "":
			lines.append(trimmed)
	return lines

func _parse_csv(text: String) -> Array[String]:
	var tokens: Array[String] = []
	for raw in text.split(","):
		var trimmed := raw.strip_edges()
		if trimmed != "":
			tokens.append(trimmed)
	return tokens

func _get_selected_visibility() -> String:
	var idx := visibility_option.get_selected()
	if idx < 0 or idx >= visibility_option.item_count:
		return LoreEntry.VISIBILITY_DISCOVERED
	return str(visibility_option.get_item_metadata(idx))

func _generate_entry_id() -> String:
	var prefix := "lore_entry"
	var counter := entry_list.item_count + 1
	while true:
		var candidate := "%s_%02d" % [prefix, counter]
		if current_world_db == null or current_world_db.lore_db == null:
			return candidate
		if not current_world_db.lore_db.entries.has(candidate):
			return candidate
		counter += 1
	# Fallback to satisfy static analysis; loop should always return above
	return "%s_%02d" % [prefix, counter]

func _clear_form() -> void:
	delete_button.disabled = true
	no_selection_label.visible = true
	scroll_container.visible = false
	entry_id_edit.text = ""
	title_edit.text = ""
	category_edit.text = ""
	visibility_option.select(0)
	related_list.clear()
	summary_edit.text = ""
	article_edit.text = ""
	unlock_edit.text = ""
	tags_edit.text = ""
	notes_edit.text = ""
	sections_list.clear()
	_section_clear_editor()

func _populate_sections(entry: LoreEntry) -> void:
	sections_list.clear()
	_section_clear_editor()
	if entry == null:
		return
	for s in entry.sections:
		var label := s.title if s.title != "" else (s.section_id if s.section_id != "" else "(untitled)")
		sections_list.add_item(label)
		sections_list.set_item_metadata(sections_list.item_count - 1, s)
	if sections_list.item_count > 0:
		sections_list.select(0)
		_on_section_selected(0)

func _on_add_section_pressed() -> void:
	var s := LoreSection.new()
	s.section_id = _generate_section_id()
	s.title = "New Section"
	s.body = ""
	sections_list.add_item(s.title)
	sections_list.set_item_metadata(sections_list.item_count - 1, s)
	sections_list.select(sections_list.item_count - 1)
	_load_section_into_editor(s)

func _on_remove_section_pressed() -> void:
	var selected := sections_list.get_selected_items()
	if selected.is_empty():
		return
	for idx in selected:
		if idx >= 0 and idx < sections_list.item_count:
			sections_list.remove_item(idx)
	_section_clear_editor()

func _on_section_selected(index: int) -> void:
	if index < 0 or index >= sections_list.item_count:
		return
	var s: Variant = sections_list.get_item_metadata(index)
	if s is LoreSection:
		_load_section_into_editor(s)

func _on_section_clicked(index: int, _at_position: Vector2, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT:
		sections_list.select(index)
		_on_section_selected(index)

func _load_section_into_editor(s: LoreSection) -> void:
	section_id_edit.text = s.section_id
	section_title_edit.text = s.title
	section_unlock_edit.text = "\n".join(s.unlock_conditions)
	section_body_edit.text = s.body

func _apply_section_editor_to_metadata() -> void:
	var selected := sections_list.get_selected_items()
	if selected.is_empty():
		return
	var idx: int = selected[0]
	if idx < 0 or idx >= sections_list.item_count:
		return
	var s: Variant = sections_list.get_item_metadata(idx)
	if not (s is LoreSection):
		return
	var new_id := section_id_edit.text.strip_edges()
	var new_title := section_title_edit.text.strip_edges()
	var new_unlock := _collect_lines(section_unlock_edit.text)
	var new_body := section_body_edit.text.strip_edges()
	s.section_id = new_id if new_id != "" else s.section_id
	s.title = new_title
	s.unlock_conditions = new_unlock
	s.body = new_body
	# Update list item label
	var label: String = ""
	if s.title != "":
		label = s.title
	elif s.section_id != "":
		label = s.section_id
	else:
		label = "(untitled)"
	sections_list.set_item_text(idx, label)

func _section_clear_editor() -> void:
	section_id_edit.text = ""
	section_title_edit.text = ""
	section_unlock_edit.text = ""
	section_body_edit.text = ""

func _generate_section_id() -> String:
	var base := "section_%02d"
	var i := sections_list.item_count + 1
	while true:
		var candidate := base % i
		var exists := false
		for idx in range(sections_list.item_count):
			var s: Variant = sections_list.get_item_metadata(idx)
			if s is LoreSection and s.section_id == candidate:
				exists = true
				break
		if not exists:
			return candidate
		i += 1
	# Fallback to satisfy static analysis; loop should always return above
	return base % i
