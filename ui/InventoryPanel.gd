extends Control
class_name InventoryPanel

## Player inventory panel with stats sidebar (placeholder implementation)

@onready var search_input: LineEdit = $VBox/Header/HeaderVBox/SearchBar/SearchInput
@onready var category_option: OptionButton = $VBox/Header/HeaderVBox/SearchBar/CategoryOption
@onready var sort_button: Button = $VBox/Header/HeaderVBox/SearchBar/SortButton
@onready var item_grid: GridContainer = $VBox/Content/ItemScroll/ItemGrid
@onready var weight_bar: ProgressBar = $VBox/Footer/FooterVBox/WeightBar/ProgressBar
@onready var weight_label: Label = $VBox/Footer/FooterVBox/WeightBar/WeightLabel
@onready var hp_label: Label = $VBox/Content/StatsSidebar/StatsVBox/HPLabel
@onready var mp_label: Label = $VBox/Content/StatsSidebar/StatsVBox/MPLabel
@onready var str_label: Label = $VBox/Content/StatsSidebar/StatsVBox/STRLabel
@onready var dex_label: Label = $VBox/Content/StatsSidebar/StatsVBox/DEXLabel
@onready var int_label: Label = $VBox/Content/StatsSidebar/StatsVBox/INTLabel

func _ready():
	_setup_categories()
	_setup_placeholder_items()
	_update_stats()
	_update_weight()

func _setup_categories():
	category_option.add_item("All")
	category_option.add_item("Weapons")
	category_option.add_item("Items")

func _setup_placeholder_items():
	# Add placeholder items
	var items = ["Rifle", "Ammo", "Med Kit"]
	for item_name in items:
		var button = Button.new()
		button.text = item_name
		button.custom_minimum_size = Vector2(60, 60)
		item_grid.add_child(button)
	
	# Add empty slots
	for i in range(6):
		var button = Button.new()
		button.text = ""
		button.custom_minimum_size = Vector2(60, 60)
		button.disabled = true
		item_grid.add_child(button)

func _update_stats():
	hp_label.text = "HP: 100"
	mp_label.text = "MP: 50"
	str_label.text = "STR: 15"
	dex_label.text = "DEX: 12"
	int_label.text = "INT: 18"

func _update_weight():
	weight_bar.value = 60  # 15/25 = 60%
	weight_label.text = "15/25 kg"
