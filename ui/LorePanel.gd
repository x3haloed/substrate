extends Control
class_name LorePanel

## Overlay showing entity lore and facts

signal closed()

@onready var title_label: Label = $VBox/TitleLabel
@onready var content_label: RichTextLabel = $VBox/ScrollContainer/ContentLabel
@onready var close_button: Button = $VBox/CloseButton

var world_db: WorldDB

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	visible = false

func set_world_db(p_world_db: WorldDB):
	world_db = p_world_db

func show_entity(entity_id: String):
	if not world_db:
		return
	
	var scene = world_db.get_scene(world_db.flags.get("current_scene", ""))
	if not scene:
		return
	
	var entity = scene.get_entity(entity_id)
	if not entity:
		# Try world DB entities
		if world_db.entities.has(entity_id):
			var entity_data = world_db.entities[entity_id]
			title_label.text = entity_id
			content_label.text = _format_entity_data(entity_data)
			visible = true
		return
	
	title_label.text = entity_id
	var content = "[b]Type:[/b] " + entity.type_name + "\n\n"
	
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
	
	content_label.text = content
	visible = true

func _format_entity_data(data: Dictionary) -> String:
	var content = ""
	if data.has("type"):
		content += "[b]Type:[/b] " + str(data.type) + "\n\n"
	if data.has("notes"):
		content += "[b]Notes:[/b]\n"
		for note in data.notes:
			content += "  • " + str(note) + "\n"
	return content

func _on_close_pressed():
	visible = false
	closed.emit()

