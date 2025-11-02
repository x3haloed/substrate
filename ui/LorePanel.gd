extends Control
class_name LorePanel

## Overlay showing entity lore, timeline, and relationships

signal closed()

@onready var title_label: Label = $VBox/TitleLabel
@onready var tab_container: TabContainer = $VBox/TabContainer
@onready var lore_content: RichTextLabel = $VBox/TabContainer/Lore/ScrollContainer/ContentLabel
@onready var timeline_content: RichTextLabel = $VBox/TabContainer/Timeline/ScrollContainer/ContentLabel
@onready var relationships_content: RichTextLabel = $VBox/TabContainer/Relationships/ScrollContainer/ContentLabel
@onready var close_button: Button = $VBox/CloseButton

var world_db: WorldDB
var current_entity_id: String = ""
var _current_entry: LoreEntry = null

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	visible = false

func set_world_db(p_world_db: WorldDB):
	world_db = p_world_db

func show_entity(entity_id: String):
	if not world_db:
		return
	
	current_entity_id = entity_id
	_current_entry = world_db.get_lore_entry_for_entity(entity_id)
	if _current_entry:
		_show_lore_entry(_current_entry)
		return
	
	var scene = world_db.get_scene(world_db.flags.get("current_scene", ""))
	if not scene:
		return
	
	var entity = scene.get_entity(entity_id)
	if not entity:
		# Try world DB entities
		if world_db.entities.has(entity_id):
			var entity_data = world_db.entities[entity_id]
			if entity_data is Dictionary and entity_data.has("lore_entry_id"):
				var explicit_entry = world_db.get_lore_entry(str(entity_data.lore_entry_id))
				if explicit_entry:
					_current_entry = explicit_entry
					_show_lore_entry(explicit_entry)
					return
			title_label.text = entity_id
			_update_all_tabs(null, entity_data)
			visible = true
		return
	
	title_label.text = entity_id
	_update_all_tabs(entity, {})
	visible = true

func _update_all_tabs(entity, entity_data):
	_update_lore_tab(entity, entity_data)
	_update_timeline_tab(entity)
	_update_relationships_tab(entity)

func _update_lore_tab(entity, entity_data):
	var content = ""
	
	if entity != null:
		content += "[b]Type:[/b] " + entity.type_name + "\n\n"
		
		if entity.tags.size() > 0:
			content += "[b]Tags:[/b] " + ", ".join(entity.tags) + "\n\n"
		
		if entity.props.size() > 0:
			content += "[b]Properties:[/b]\n"
			for key in entity.props.keys():
				content += "  • " + key + ": " + str(entity.props[key]) + "\n"
			content += "\n"
		
		if entity.lore.has("notes") and entity.lore.notes.size() > 0:
			content += "[b]Notes:[/b]\n"
			for note in entity.lore.notes:
				content += "  • " + str(note) + "\n"
		
		if entity.lore.has("discovered_by") and entity.lore.discovered_by.size() > 0:
			content += "\n[b]Discovered by:[/b] " + ", ".join(entity.lore.discovered_by) + "\n"
	elif entity_data is Dictionary:
		if entity_data.has("type"):
			content += "[b]Type:[/b] " + str(entity_data.type) + "\n\n"
		if entity_data.has("notes"):
			content += "[b]Notes:[/b]\n"
			for note in entity_data.notes:
				content += "  • " + str(note) + "\n"
		if entity_data.has("discovered_by"):
			content += "\n[b]Discovered by:[/b] " + ", ".join(entity_data.discovered_by) + "\n"
	
	if content == "":
		content = "No information available about this entity."
	
	lore_content.bbcode_text = content

func _update_timeline_tab(entity):
	var content = ""
	
	if not entity:
		timeline_content.bbcode_text = "No timeline data available."
		return
	
	var history = world_db.get_entity_history(entity.id)
	
	if history.size() == 0:
		timeline_content.bbcode_text = "No history recorded for this entity."
		return
	
	content += "[b]Entity History[/b]\n\n"
	
	var discoveries = entity.get_discoveries()
	if discoveries.size() > 0:
		content += "[b]Discoveries:[/b]\n"
		for disc in discoveries:
			var actor = disc.get("actor", "unknown")
			var timestamp = disc.get("timestamp", disc.get("ts", "unknown"))
			content += "  • Discovered by [i]" + actor + "[/i] at [color=#888]" + timestamp + "[/color]\n"
		content += "\n"
	
	var changes = entity.get_changes()
	if changes.size() > 0:
		content += "[b]Changes:[/b]\n"
		for change in changes:
			var change_type = change.get("change_type", "unknown")
			var path = change.get("path", "")
			var actor = change.get("actor", "system")
			var timestamp = change.get("timestamp", change.get("ts", "unknown"))
			var old_val = str(change.get("old_value", ""))
			var new_val = str(change.get("new_value", ""))
			
			# Truncate long values for display
			if old_val.length() > 50:
				old_val = old_val.substr(0, 47) + "..."
			if new_val.length() > 50:
				new_val = new_val.substr(0, 47) + "..."
			
			content += "  • [color=#888]" + timestamp + "[/color] - "
			content += change_type.capitalize() + " change by [i]" + actor + "[/i]\n"
			content += "      Path: [code]" + path + "[/code]\n"
			if old_val != "":
				content += "      Old: [color=#f88]" + old_val + "[/color] → New: [color=#8f8]" + new_val + "[/color]\n"
			content += "\n"
	
	if content == "":
		content = "No timeline events recorded."
	
	timeline_content.bbcode_text = content

func _update_relationships_tab(entity):
	var content = ""
	
	if not entity:
		relationships_content.bbcode_text = "No relationship data available."
		return
	
	var relationships = world_db.get_entity_relationships(entity.id)
	
	if relationships.size() == 0:
		relationships_content.bbcode_text = "No relationships recorded for this entity."
		return
	
	content += "[b]Entity Relationships[/b]\n\n"
	
	for related_id in relationships.keys():
		var rel_type = relationships[related_id]
		content += "  • [b]" + rel_type + "[/b] → [i]" + related_id + "[/i]\n"
	
	# Also show reverse relationships (entities that relate to this one)
	var has_reverse = false
	for entity_id in world_db.relationships.keys():
		if entity_id != entity.id and world_db.relationships[entity_id] is Dictionary:
			if world_db.relationships[entity_id].has(entity.id):
				if not has_reverse:
					content += "\n[b]Related by:[/b]\n"
					has_reverse = true
				var rel_type = world_db.relationships[entity_id][entity.id]
				content += "  • [i]" + entity_id + "[/i] → [b]" + rel_type + "[/b]\n"
	
	if content == "":
		content = "No relationships recorded."
	
	relationships_content.bbcode_text = content

func _on_close_pressed():
	visible = false
	closed.emit()

func show_lore_entry(entry_id: String):
	if not world_db:
		return
	var entry := world_db.get_lore_entry(entry_id)
	if entry == null:
		push_warning("Lore entry not found: " + entry_id)
		return
	_current_entry = entry
	_show_lore_entry(entry)

func _show_lore_entry(entry: LoreEntry):
	if entry == null:
		return
	var can_view := entry.is_unlocked(world_db)
	title_label.text = entry.title if entry.title != "" else entry.entry_id
	# default to Lore tab
	if tab_container:
		tab_container.current_tab = 0
	if can_view:
		var content := ""
		if entry.summary != "":
			content += entry.summary.strip_edges() + "\n\n"
		if entry.article != "":
			content += entry.article.strip_edges()
		_update_lore_tab_from_text(content if content != "" else "No lore details available.")
	else:
		_update_lore_tab_from_text("You have not unlocked this lore yet.")
	_update_timeline_tab(null)
	_update_relationships_tab(null)
	visible = true

func _update_lore_tab_from_text(text: String):
	lore_content.bbcode_text = text
