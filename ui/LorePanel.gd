extends Control
class_name LorePanel

## Redesigned lore codex with browsable list, search, and linked navigation

signal closed()

@onready var close_button: Button = $MainVBox/Header/CloseButton
@onready var search_box: LineEdit = $MainVBox/HSplitContainer/Sidebar/SearchBox
@onready var category_filter: OptionButton = $MainVBox/HSplitContainer/Sidebar/CategoryFilter
@onready var entry_list: ItemList = $MainVBox/HSplitContainer/Sidebar/EntryList
@onready var entry_title: Label = $MainVBox/HSplitContainer/DetailView/EntryHeader/EntryTitle
@onready var category_label: Label = $MainVBox/HSplitContainer/DetailView/EntryHeader/CategoryLabel
@onready var tab_container: TabContainer = $MainVBox/HSplitContainer/DetailView/TabContainer
@onready var article_content: RichTextLabel = $MainVBox/HSplitContainer/DetailView/TabContainer/Article/ScrollContainer/ContentLabel
@onready var related_content: RichTextLabel = $MainVBox/HSplitContainer/DetailView/TabContainer/Related/ScrollContainer/ContentLabel
@onready var timeline_content: RichTextLabel = $MainVBox/HSplitContainer/DetailView/TabContainer/Timeline/ScrollContainer/ContentLabel

var world_db: WorldDB
var _current_entry: LoreEntry = null
var _all_entries: Array[LoreEntry] = []
var _filtered_entries: Array[LoreEntry] = []
var _categories: Array[String] = []

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	search_box.text_changed.connect(_on_search_changed)
	category_filter.item_selected.connect(_on_category_selected)
	entry_list.item_selected.connect(_on_entry_selected)
	article_content.meta_clicked.connect(_on_article_meta_clicked)
	related_content.meta_clicked.connect(_on_related_meta_clicked)
	visible = false

func set_world_db(p_world_db: WorldDB):
	world_db = p_world_db

func show_entity(entity_id: String):
	"""Show lore for a specific entity, or fallback to entity details if no lore exists."""
	if not world_db:
		return
	
	# Try to find a lore entry for this entity
	var entry := world_db.get_lore_entry_for_entity(entity_id)
	if entry:
		show_lore_entry(entry.entry_id)
		return
	
	# Fallback: show basic entity info (legacy behavior)
	_show_basic_entity_info(entity_id)

func show_lore_entry(entry_id: String):
	"""Show a specific lore entry by ID."""
	if not world_db:
		return
	
	_refresh_entry_list()
	
	var entry := world_db.get_lore_entry(entry_id)
	if entry == null:
		push_warning("Lore entry not found: " + entry_id)
		return
	
	_select_entry(entry)
	visible = true

func open_codex():
	"""Open the lore codex to browse all unlocked entries."""
	if not world_db:
		return
	
	_refresh_entry_list()
	
	# Select first entry if available
	if _filtered_entries.size() > 0:
		_select_entry(_filtered_entries[0])
	else:
		_clear_detail_view()
	
	visible = true

func _refresh_entry_list():
	"""Rebuild the list of unlocked lore entries."""
	if not world_db or not world_db.lore_db:
		_all_entries.clear()
		_filtered_entries.clear()
		_update_entry_list_ui()
		return
	
	# Gather all unlocked entries
	_all_entries.clear()
	_categories.clear()
	var category_set := {}
	
	for entry in world_db.lore_db.list_entries():
		if entry.is_unlocked(world_db):
			_all_entries.append(entry)
			if entry.category != "" and not category_set.has(entry.category):
				category_set[entry.category] = true
				_categories.append(entry.category)
	
	# Sort entries by title
	_all_entries.sort_custom(func(a, b): return a.title.naturalnocasecmp_to(b.title) < 0)
	_categories.sort()
	
	# Update category filter
	_update_category_filter()
	
	# Apply current filters
	_apply_filters()

func _update_category_filter():
	"""Rebuild the category dropdown."""
	category_filter.clear()
	category_filter.add_item("All Categories", 0)
	for i in range(_categories.size()):
		category_filter.add_item(_categories[i], i + 1)
	category_filter.selected = 0

func _apply_filters():
	"""Filter entries based on search and category."""
	var search_text := search_box.text.strip_edges().to_lower()
	var selected_category := ""
	if category_filter.selected > 0 and category_filter.selected <= _categories.size():
		selected_category = _categories[category_filter.selected - 1]
	
	_filtered_entries.clear()
	
	for entry in _all_entries:
		# Category filter
		if selected_category != "" and entry.category != selected_category:
			continue
		
		# Search filter
		if search_text != "":
			var title_match := entry.title.to_lower().contains(search_text)
			var id_match := entry.entry_id.to_lower().contains(search_text)
			var summary_match := entry.summary.to_lower().contains(search_text)
			var tag_match := false
			for tag in entry.tags:
				if str(tag).to_lower().contains(search_text):
					tag_match = true
					break
			
			if not (title_match or id_match or summary_match or tag_match):
				continue
		
		_filtered_entries.append(entry)
	
	_update_entry_list_ui()

func _update_entry_list_ui():
	"""Refresh the ItemList widget with filtered entries."""
	entry_list.clear()
	
	for entry in _filtered_entries:
		var display_name := entry.title if entry.title != "" else entry.entry_id
		if entry.category != "":
			display_name = "[" + entry.category + "] " + display_name
		entry_list.add_item(display_name)

func _select_entry(entry: LoreEntry):
	"""Display the given lore entry in the detail view."""
	if entry == null:
		return
	
	_current_entry = entry
	
	# Highlight in list if visible
	for i in range(_filtered_entries.size()):
		if _filtered_entries[i].entry_id == entry.entry_id:
			entry_list.select(i)
			entry_list.ensure_current_is_visible()
			break
	
	# Update detail view
	_update_detail_view(entry)

func _update_detail_view(entry: LoreEntry):
	"""Render the lore entry details."""
	if entry == null:
		_clear_detail_view()
		return
	
	var can_view := entry.is_unlocked(world_db)
	
	# Update header
	entry_title.text = entry.title if entry.title != "" else entry.entry_id
	category_label.text = "[" + entry.category + "]" if entry.category != "" else ""
	
	# Switch to Article tab
	tab_container.current_tab = 0
	
	# Update Article tab
	if can_view:
		var content := ""
		if entry.summary != "":
			content += "[i]" + entry.summary.strip_edges() + "[/i]\n\n"
		
		var visible_sections := entry.get_unlocked_sections(world_db)
		if visible_sections.size() > 0:
			for s in visible_sections:
				content += "[b][font_size=16]" + str(s.title) + "[/font_size][/b]\n"
				if str(s.body) != "":
					content += str(s.body).strip_edges() + "\n\n"
		elif entry.article != "":
			content += entry.article.strip_edges()
		
		_set_rich_text(article_content, content if content != "" else "No details available.")
	else:
		_set_rich_text(article_content, "[center][i]This lore entry has not been unlocked yet.[/i][/center]")
	
	# Update Related tab
	_update_related_tab(entry)
	
	# Update Timeline tab
	_update_timeline_tab(entry)

func _update_related_tab(entry: LoreEntry):
	"""Show related entities and lore entries."""
	var content := ""
	
	if entry.related_entity_ids.size() > 0:
		content += "[b]Related Entities:[/b]\n"
		for entity_id in entry.related_entity_ids:
			# Make entity clickable
			content += "  • [url=" + entity_id + "]" + entity_id.capitalize() + "[/url]\n"
		content += "\n"
	
	# Find other lore entries that reference this one
	if world_db and world_db.lore_db:
		var related_entries: Array[LoreEntry] = []
		for other in world_db.lore_db.list_entries():
			if other.entry_id == entry.entry_id:
				continue
			if entry.entry_id in other.related_entity_ids:
				related_entries.append(other)
		
		if related_entries.size() > 0:
			content += "[b]Referenced by:[/b]\n"
			for other in related_entries:
				var title := other.title if other.title != "" else other.entry_id
				content += "  • [url=lore:" + other.entry_id + "]" + title + "[/url]\n"
			content += "\n"
	
	if entry.tags.size() > 0:
		content += "[b]Tags:[/b] " + ", ".join(entry.tags) + "\n"
	
	if content == "":
		content = "No related information."
	
	_set_rich_text(related_content, content)

func _update_timeline_tab(entry: LoreEntry):
	"""Show discovery timeline for this lore entry."""
	var content := ""
	
	# Check if the entry is unlocked and when
	if world_db and world_db.unlocked_lore_entries.has(entry.entry_id):
		content += "[b]Status:[/b] Unlocked\n\n"
		
		# Look for unlock event in history
		for event in world_db.history:
			if event.get("event") == "lore_unlock" and event.get("entry_id") == entry.entry_id:
				var ts: String = str(event.get("ts", ""))
				var source: String = str(event.get("source", "unknown"))
				content += "[b]Unlocked:[/b] " + ts + "\n"
				content += "[b]Source:[/b] " + source + "\n\n"
				break
	else:
		content += "[b]Status:[/b] Locked\n\n"
	
	# Show unlock conditions if locked
	if not entry.is_unlocked(world_db) and entry.unlock_conditions.size() > 0:
		content += "[b]Unlock Conditions:[/b]\n"
		for condition in entry.unlock_conditions:
			content += "  • " + str(condition) + "\n"
		content += "\n"
	
	# Show related entity discoveries
	var discovered_entities: Array[String] = []
	for entity_id in entry.related_entity_ids:
		if world_db and world_db.has_entity_been_discovered(entity_id):
			discovered_entities.append(entity_id)
	
	if discovered_entities.size() > 0:
		content += "[b]Related Entities Discovered:[/b]\n"
		for entity_id in discovered_entities:
			content += "  • " + entity_id.capitalize() + "\n"
	
	if content == "":
		content = "No timeline information available."
	
	_set_rich_text(timeline_content, content)

func _clear_detail_view():
	"""Reset detail view to empty state."""
	entry_title.text = "Select an entry"
	category_label.text = ""
	_set_rich_text(article_content, "[center][i]Select a lore entry from the list to view details.[/i][/center]")
	_set_rich_text(related_content, "")
	_set_rich_text(timeline_content, "")

func _show_basic_entity_info(entity_id: String):
	"""Fallback for entities without lore entries - show basic info."""
	if not world_db:
		return
	
	_refresh_entry_list()
	_clear_detail_view()
	
	var scene := world_db.get_scene(world_db.flags.get("current_scene", ""))
	var entity: Entity = null
	var entity_data: Dictionary = {}
	
	if scene:
		entity = scene.get_entity(entity_id)
	
	if not entity and world_db.entities.has(entity_id):
		entity_data = world_db.entities[entity_id] if world_db.entities[entity_id] is Dictionary else {}
	
	entry_title.text = entity_id.capitalize()
	category_label.text = "[Entity]"
	tab_container.current_tab = 0
	
	var content := ""
	
	if entity:
		content += "[b]Type:[/b] " + entity.type_name + "\n\n"
		
		if entity.tags.size() > 0:
			content += "[b]Tags:[/b] " + ", ".join(entity.tags) + "\n\n"
		
		if entity.props.size() > 0:
			content += "[b]Properties:[/b]\n"
			for key in entity.props.keys():
				content += "  • " + key + ": " + str(entity.props[key]) + "\n"
			content += "\n"
	elif entity_data.has("type"):
		content += "[b]Type:[/b] " + str(entity_data.type) + "\n\n"
	
	if content == "":
		content = "[i]No information available about this entity.[/i]"
	
	_set_rich_text(article_content, content)
	_set_rich_text(related_content, "")
	_set_rich_text(timeline_content, "")
	
	visible = true

func _set_rich_text(label: RichTextLabel, text: String):
	"""Helper to safely update RichTextLabel content."""
	if label == null:
		return
	label.clear()
	if text == "":
		return
	label.append_text(text)

func _on_close_pressed():
	visible = false
	closed.emit()

func _on_search_changed(_new_text: String):
	_apply_filters()

func _on_category_selected(_index: int):
	_apply_filters()

func _on_entry_selected(index: int):
	if index < 0 or index >= _filtered_entries.size():
		return
	_select_entry(_filtered_entries[index])

func _on_article_meta_clicked(meta: Variant):
	_handle_meta_click(str(meta))

func _on_related_meta_clicked(meta: Variant):
	_handle_meta_click(str(meta))

func _handle_meta_click(meta: String):
	"""Handle BBCode link clicks - navigate to other lore entries or entities."""
	var target := meta.to_lower()
	
	# Check if it's a lore: link
	if target.begins_with("lore:"):
		var entry_id := target.substr(5)
		show_lore_entry(entry_id)
		return
	
	# Otherwise treat as entity ID
	show_entity(target)
