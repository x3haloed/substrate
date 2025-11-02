extends Control
class_name CardManager

## Card Manager - Browse and manage character cards

signal closed

const CardRepositoryRef = preload("res://tools/CardRepository.gd")

@onready var card_shelf: HBoxContainer = %CardShelf
@onready var exit_button: Button = %ExitButton
@onready var help_button: Button = %HelpButton
@onready var scroll_left_button: Button = %ScrollLeftButton
@onready var scroll_right_button: Button = %ScrollRightButton
@onready var auto_scroll_button: Button = %AutoScrollButton
@onready var shuffle_button: Button = %ShuffleButton
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var card_preview: PanelContainer = %CardPreview
@onready var card_preview_texture: TextureRect = %CardPreviewTexture
@onready var card_preview_name: Label = %CardPreviewName
@onready var total_cards_label: Label = %TotalCardsLabel
@onready var sort_option: OptionButton = %SortOption

var character_cards: Array[CharacterProfile] = []
var current_scroll_index: int = 0
var auto_scrolling: bool = false
var auto_scroll_timer: Timer

const CARD_WIDTH: int = 112  # 96px + 16px gap

func _ready():
	_setup_sort_options()
	_load_character_cards()
	_populate_card_shelf()
	_connect_signals()
	_setup_auto_scroll_timer()
	_update_total_cards_label()

func _setup_sort_options():
	sort_option.clear()
	sort_option.add_item("NAME (A-Z)", 0)
	sort_option.add_item("RARITY", 1)
	sort_option.add_item("MANA COST", 2)
	sort_option.add_item("POWER", 3)

func _load_character_cards():
	character_cards.clear()
	var cards: Array[CharacterProfile] = CardRepositoryRef.load_cards()
	for character in cards:
		if character:
			# Warm the portrait cache to avoid lag during rendering
			character.warm_portrait_cache()
			character_cards.append(character)

func _populate_card_shelf():
	# Clear existing cards
	for child in card_shelf.get_children():
		child.queue_free()
	
	# Create card buttons for each character
	for character in character_cards:
		var card = _create_card_button(character)
		card_shelf.add_child(card)
	
	# Show first card in preview if available
	if character_cards.size() > 0:
		_show_card_preview(character_cards[0])

func _create_card_button(character: CharacterProfile) -> Control:
	var card = preload("res://ui/ShelfCard.tscn").instantiate()
	var button = card.get_node("Button") as Button
	button.pressed.connect(func(): _on_card_clicked(character))
	
	var texture_rect = card.get_node("Margin/VBox/TextureRect") as TextureRect

	var portrait = character.get_portrait_texture()
	if portrait:
		texture_rect.texture = portrait
	
	var name_label = card.get_node("Margin/VBox/NameLabel") as Label
	name_label.text = character.name if character.name != "" else "UNKNOWN"
	
	return card

func _show_card_preview(character: CharacterProfile):
	# Update preview texture
	var portrait = character.get_portrait_texture()
	if portrait:
		card_preview_texture.texture = portrait
	else:
		card_preview_texture.texture = null
	
	# Update preview name
	card_preview_name.text = character.name if character.name != "" else "UNKNOWN"

func _on_card_clicked(character: CharacterProfile):
	_show_card_preview(character)

func _connect_signals():
	exit_button.pressed.connect(_on_exit_pressed)
	help_button.pressed.connect(_on_help_pressed)
	scroll_left_button.pressed.connect(_on_scroll_left)
	scroll_right_button.pressed.connect(_on_scroll_right)
	auto_scroll_button.pressed.connect(_on_auto_scroll_toggled)
	shuffle_button.pressed.connect(_on_shuffle_pressed)

func _on_exit_pressed():
	closed.emit()

func _on_help_pressed():
	# Show help dialog (placeholder for now)
	pass

func _on_scroll_left():
	var current = scroll_container.scroll_horizontal
	scroll_container.scroll_horizontal = max(0, current - CARD_WIDTH)

func _on_scroll_right():
	var current = scroll_container.scroll_horizontal
	var max_scroll = card_shelf.size.x - scroll_container.size.x
	scroll_container.scroll_horizontal = min(max_scroll, current + CARD_WIDTH)

func _on_auto_scroll_toggled():
	auto_scrolling = !auto_scrolling
	if auto_scrolling:
		auto_scroll_button.text = "■ AUTO SCROLL"
		auto_scroll_timer.start()
	else:
		auto_scroll_button.text = "▶ AUTO SCROLL"
		auto_scroll_timer.stop()

func _on_shuffle_pressed():
	# Shuffle to random position
	var max_scroll = max(0, card_shelf.size.x - scroll_container.size.x)
	scroll_container.scroll_horizontal = randi() % int(max_scroll + 1)

func _setup_auto_scroll_timer():
	auto_scroll_timer = Timer.new()
	auto_scroll_timer.wait_time = 2.0
	auto_scroll_timer.timeout.connect(_on_auto_scroll_tick)
	add_child(auto_scroll_timer)

func _on_auto_scroll_tick():
	_on_scroll_right()
	# Reset to start if at end
	var max_scroll = max(0, card_shelf.size.x - scroll_container.size.x)
	if scroll_container.scroll_horizontal >= max_scroll:
		scroll_container.scroll_horizontal = 0

func _update_total_cards_label():
	var total = character_cards.size()
	total_cards_label.text = "TOTAL CARDS: %d | SHOWING: 1-%d" % [total, total]
