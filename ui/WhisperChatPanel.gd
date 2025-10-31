extends Control
class_name WhisperChatPanel

## Private chat panel with NPC tabs (placeholder implementation)

@onready var whisper_tabs: TabBar = $VBox/WhisperTabs
@onready var npc_portrait: ColorRect = $VBox/Content/HBox/SidebarVBox/Portrait
@onready var npc_name: Label = $VBox/Content/HBox/SidebarVBox/NPCName
@onready var chat_log: RichTextLabel = $VBox/Content/HBox/ChatVBox/ChatLog
@onready var input_line: LineEdit = $VBox/Content/HBox/ChatVBox/InputBox/InputLine
@onready var send_button: Button = $VBox/Content/HBox/ChatVBox/InputBox/SendButton
@onready var close_button: Button = $VBox/HeaderBar/HBox/CloseButton

var current_npc: String = "Vex"

func _ready():
    _setup_tabs()
    _setup_placeholder_chat()
    send_button.pressed.connect(_on_send_pressed)
    input_line.text_submitted.connect(_on_input_submitted)
    close_button.pressed.connect(_on_close_pressed)

func _setup_tabs():
    whisper_tabs.add_tab("Vex")
    whisper_tabs.add_tab("Zara")
    whisper_tabs.add_tab("Kane")

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

func _on_close_pressed():
    visible = false


