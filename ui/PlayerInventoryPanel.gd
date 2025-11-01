extends Control
class_name PlayerInventoryPanel

## Player inventory panel with stats sidebar (placeholder implementation)

var world_db: WorldDB
var inventory: Inventory

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
	_update_stats()
	_update_weight()
	# If world_db already provided, populate from player contents
	if world_db != null:
		refresh()

func _setup_categories():
	category_option.add_item("All")
	category_option.add_item("Weapons")
	category_option.add_item("Items")

func set_world_db(p_world_db: WorldDB) -> void:
	world_db = p_world_db
	refresh()

func set_inventory(inv: Inventory) -> void:
	if inventory != null:
		if inventory.inv_changed.is_connected(_on_inventory_changed):
			inventory.inv_changed.disconnect(_on_inventory_changed)
	inventory = inv
	if inventory != null:
		inventory.inv_changed.connect(_on_inventory_changed)
	refresh()

func _on_inventory_changed() -> void:
	refresh()

func refresh() -> void:
	# Clear current grid
	for child in item_grid.get_children():
		child.queue_free()
	# Prefer Inventory (Phase 2)
	if inventory != null:
		for s in inventory.slots:
			if s == null:
				continue
			var button = Button.new()
			var name_str = s.item.display_name if s.item and s.item.display_name != "" else (s.item.id if s.item else "")
			var qty_str = "x" + str(s.quantity) if s.quantity > 1 else ""
			button.text = (name_str + " " + qty_str).strip_edges()
			button.custom_minimum_size = Vector2(60, 60)
			item_grid.add_child(button)
		_update_weight_from_inventory()
		return
	# Fallback to Phase 1 contents if no inventory bound
	var contents: Array = []
	if world_db and world_db.entities.has("player"):
		var player = world_db.entities["player"]
		if player is Dictionary and player.has("contents") and player.contents is Array:
			contents = player.contents
	for item_id in contents:
		var button2 = Button.new()
		button2.text = str(item_id)
		button2.custom_minimum_size = Vector2(60, 60)
		item_grid.add_child(button2)

func _update_weight_from_inventory() -> void:
	if inventory == null:
		return
	var total := inventory.get_total_weight_kg()
	var max_w := float(max(inventory.max_carry_weight_kg, 0.001))
	var pct := float(clamp((total / max_w) * 100.0, 0.0, 100.0))
	weight_bar.value = pct
	weight_label.text = str(round(total * 10.0) / 10.0) + "/" + str(inventory.max_carry_weight_kg) + " kg"

func _update_stats():
	hp_label.text = "HP: 100"
	mp_label.text = "MP: 50"
	str_label.text = "STR: 15"
	dex_label.text = "DEX: 12"
	int_label.text = "INT: 18"

func _update_weight():
	weight_bar.value = 60  # 15/25 = 60%
	weight_label.text = "15/25 kg"
