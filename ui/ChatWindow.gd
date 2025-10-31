extends Control
class_name ChatWindow

## Main chat display with entity tags and styles

signal entity_clicked(entity_id: String)
signal message_sent(text: String)

@onready var chat_log: RichTextLabel = $VBox/ChatLog
@onready var address_option: OptionButton = $VBox/InputBox/AddressOption
@onready var input_line: LineEdit = $VBox/InputBox/InputLine
@onready var send_button: Button = $VBox/InputBox/SendButton

func _ready():
	send_button.pressed.connect(_on_send_pressed)
	input_line.text_submitted.connect(_on_input_submitted)
	chat_log.meta_clicked.connect(_on_meta_clicked)

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
	# Scroll to bottom
	await get_tree().process_frame
	chat_log.scroll_to_line(chat_log.get_line_count())

func clear_chat():
	chat_log.clear()

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
	entity_clicked.emit(str(meta))
