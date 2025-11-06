extends Control
class_name ChatWindow

## Main chat display with entity tags and styles

signal entity_clicked(entity_id: String)
signal message_sent(text: String)

@export var show_address_option: bool = true

@onready var chat_log: RichTextLabel = $VBox/ChatLog
@onready var typing_indicator: TypingIndicator = $VBox/TypingIndicator
@onready var address_option: OptionButton = $VBox/InputBox/AddressOption
@onready var input_line: LineEdit = $VBox/InputBox/InputLine
@onready var send_button: Button = $VBox/InputBox/SendButton

var world_db: WorldDB = null

func _ready():
	send_button.pressed.connect(_on_send_pressed)
	input_line.text_submitted.connect(_on_input_submitted)
	chat_log.meta_clicked.connect(_on_meta_clicked)
	address_option.visible = show_address_option

func set_world_db(db: WorldDB) -> void:
	world_db = db

func add_message(text: String, style: String = "world", speaker: String = ""):
	var formatted = Narrator.format_narration(text, style)
	# Extract entity tags from text (simple pattern matching)
	var entity_pattern = RegEx.new()
	var compile_result = entity_pattern.compile("\\[(\\w+)\\]")
	if compile_result == OK:
		var entities = {}
		var results = entity_pattern.search_all(text)
		for result in results:
			var entity_id = result.get_string(1)
			entities[entity_id] = true
		formatted = Narrator.add_entity_tags(formatted, entities)
	
	if speaker != "":
		formatted = "[b]" + speaker + ":[/b] " + formatted
	
	chat_log.append_text(formatted + "\n")
	_scroll_to_bottom()

func clear_chat():
	chat_log.clear()

func add_image_from_path(path: String):
	var texture := _load_image_texture(path)
	if texture:
		add_image(texture)

func add_image(texture: Texture2D):
	if not texture:
		return
	# Scale image to fit chat width while preserving aspect ratio
	var chat_width := chat_log.size.x - 32  # Account for padding/scrollbar
	var img_size := texture.get_size()
	var scale_factor := 1.0
	if img_size.x > chat_width:
		scale_factor = chat_width / img_size.x
	var display_width := int(img_size.x * scale_factor)
	var display_height := int(img_size.y * scale_factor)
	
	# Add image using RichTextLabel's built-in BBCode support
	chat_log.add_image(texture, display_width, display_height)
	chat_log.append_text("\n")
	_scroll_to_bottom()

func _load_image_texture(path: String) -> Texture2D:
	if typeof(path) != TYPE_STRING or path == "":
		return null
	
	# Resolve via centralized PathResolver
	var img := PathResolver.try_load_image(path, world_db)
	if img != null:
		return ImageTexture.create_from_image(img)
	push_warning("Failed to load image from path: " + path)
	return null

func _scroll_to_bottom():
	await get_tree().process_frame
	chat_log.scroll_to_line(chat_log.get_line_count())

func show_typing(source: String, name_hint: String = "") -> void:
	if typing_indicator:
		typing_indicator.start(source, name_hint)

func hide_typing() -> void:
	if typing_indicator:
		typing_indicator.stop()

func set_address_options(target_ids: Array[String]):
	# Optional address dropdown for talking to specific entities
	address_option.clear()
	# First item means no direct address → narrator/world
	address_option.add_item("Address…")
	address_option.selected = 0
	for id in target_ids:
		address_option.add_item(id)

func get_selected_address() -> String:
	# Return selected entity id or empty if none chosen
	if address_option.get_item_count() == 0:
		return ""
	# OptionButton uses numeric item ids starting at 0 by default; 0 is the placeholder
	var selected_index = address_option.get_selected()
	if selected_index <= 0:
		return ""
	return address_option.get_item_text(selected_index)

func _on_send_pressed():
	var text = input_line.text.strip_edges()
	if text != "":
		message_sent.emit(text)
		add_message(text, "player", "You")
		input_line.text = ""

func _on_input_submitted(_text: String):
	_on_send_pressed()

func _on_meta_clicked(meta: Variant):
	entity_clicked.emit(str(meta).to_lower())
