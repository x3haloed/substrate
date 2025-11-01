extends Control
class_name NPCInventoryPanel

## NPC inventory panel with tabs (placeholder implementation)

@onready var npc_tabs: TabBar = $VBox/NPCTabs
@onready var npc_name: Label = $VBox/Header/HBox/VBoxInfo/NPCName
@onready var npc_disposition: Label = $VBox/Header/HBox/VBoxInfo/Disposition
@onready var npc_portrait: ColorRect = $VBox/Header/HBox/Portrait
@onready var item_grid: GridContainer = $VBox/Content/ItemScroll/ItemGrid
@onready var chat_log: RichTextLabel = $VBox/Content/WhisperContent/HBox/ChatVBox/ChatLog
@onready var input_line: LineEdit = $VBox/Content/WhisperContent/HBox/ChatVBox/InputBox/InputLine
@onready var send_button: Button = $VBox/Content/WhisperContent/HBox/ChatVBox/InputBox/SendButton

var current_npc: String = "Trader Vex"

func _ready():
	_setup_tabs()
	_setup_placeholder_items()
	_setup_placeholder_chat()
	send_button.pressed.connect(_on_send_pressed)
	input_line.text_submitted.connect(_on_input_submitted)

func _setup_tabs():
	npc_tabs.add_tab("Trader Vex")
	npc_tabs.add_tab("Mechanic Zara")
	npc_tabs.add_tab("Pilot Kane")

func _setup_placeholder_items():
	var items = ["Plasma Cell", "Armor Plating", "Data Chip", "Stim Pack"]
	for item_name in items:
		var button = Button.new()
		button.text = item_name
		button.custom_minimum_size = Vector2(60, 60)
		item_grid.add_child(button)

func _setup_placeholder_chat():
	chat_log.clear()
	chat_log.append_text("[Vex]: Got some rare tech here, Commander\n")
	chat_log.append_text("[You]: What's the price?\n")
	chat_log.append_text("[Vex]: 500 credits for the plasma cell\n")

func _on_send_pressed():
	var text = input_line.text.strip_edges()
	if text != "":
		chat_log.append_text("[You]: " + text + "\n")
		input_line.text = ""

func _on_input_submitted(_text: String):
	_on_send_pressed()
