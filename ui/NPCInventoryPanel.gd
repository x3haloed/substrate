extends Control
class_name NPCInventoryPanel

## NPC inventory panel with tabs (placeholder implementation)

@onready var npc_tabs: TabBar = $VBox/NPCTabs
@onready var npc_name: Label = $VBox/Header/HBox/VBoxInfo/NPCName
@onready var npc_disposition: Label = $VBox/Header/HBox/VBoxInfo/Disposition
@onready var npc_portrait: ColorRect = $VBox/Header/HBox/Portrait
@onready var item_grid: GridContainer = $VBox/Content/ItemScroll/ItemGrid
@onready var close_button: Button = $VBox/Header/HBox/CloseButton

var current_npc: String = "Trader Vex"

func _ready():
	_setup_tabs()
	_setup_placeholder_items()
	close_button.pressed.connect(_on_close_pressed)

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

func _on_close_pressed():
	visible = false
