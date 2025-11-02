extends Control

## Characters Tab - Manage campaign character roster

signal character_added(character_id: String)
signal character_removed(character_id: String)

var current_world_db: WorldDB = null

# UI references
@onready var character_list: ItemList = $HBox/CharacterList
@onready var detail_panel: VBoxContainer = $HBox/DetailPanel
@onready var no_selection_label: Label = $HBox/DetailPanel/NoSelection
@onready var character_info: VBoxContainer = $HBox/DetailPanel/CharacterInfo
@onready var portrait_preview: TextureRect = $HBox/DetailPanel/CharacterInfo/PortraitPreview
@onready var character_name_label: Label = $HBox/DetailPanel/CharacterInfo/NameLabel
@onready var character_desc_label: Label = $HBox/DetailPanel/CharacterInfo/DescLabel
@onready var character_version_label: Label = $HBox/DetailPanel/CharacterInfo/VersionLabel
@onready var add_character_btn: Button = $HBox/DetailPanel/CharacterInfo/ButtonSection/AddToPartyBtn
@onready var remove_character_btn: Button = $HBox/DetailPanel/CharacterInfo/ButtonSection/RemoveFromCampaignBtn

# Card picker dialog
@onready var card_picker_dialog: Window = $CardPickerDialog
@onready var picker_list: ItemList = $CardPickerDialog/PickerContent/VBox/HSplitContainer/PickerList
@onready var picker_portrait: TextureRect = $CardPickerDialog/PickerContent/VBox/HSplitContainer/PreviewSection/PortraitPreview
@onready var picker_name_label: Label = $CardPickerDialog/PickerContent/VBox/HSplitContainer/PreviewSection/NameLabel
@onready var picker_desc_label: Label = $CardPickerDialog/PickerContent/VBox/HSplitContainer/PreviewSection/DescLabel

var available_cards: Array[CharacterProfile] = []
var selected_character_id: String = ""

func _ready() -> void:
	# Connect signals
	character_list.item_selected.connect(_on_character_selected)
	picker_list.item_selected.connect(_on_picker_item_selected)
	
	# Hide character info initially
	character_info.visible = false
	no_selection_label.visible = true
	
	# Sync built-in cards to repository on startup
	CardRepository.sync_builtin_cards_to_repo()

func refresh_characters_list() -> void:
	if current_world_db == null:
		character_list.clear()
		return
	
	character_list.clear()
	selected_character_id = ""
	
	# Populate list from world_db.characters
	for character_id in current_world_db.characters.keys():
		var character: CharacterProfile = current_world_db.get_character(character_id)
		if character:
			var display_name: String = character.name if not character.name.is_empty() else character_id
			character_list.add_item(display_name)
			character_list.set_item_metadata(character_list.item_count - 1, character_id)
	
	# Clear selection
	no_selection_label.visible = true
	character_info.visible = false

func _on_character_selected(index: int) -> void:
	if index < 0 or index >= character_list.item_count:
		return
	
	var character_id: String = str(character_list.get_item_metadata(index))
	selected_character_id = character_id
	_display_character_info(character_id)

func _display_character_info(character_id: String) -> void:
	if current_world_db == null:
		return
	
	var character: CharacterProfile = current_world_db.get_character(character_id)
	if character == null:
		no_selection_label.visible = true
		character_info.visible = false
		return
	
	# Show character details
	no_selection_label.visible = false
	character_info.visible = true
	
	character_name_label.text = character.name
	character_desc_label.text = _truncate_text(character.description, 600)
	character_version_label.text = "Version: " + character.character_version
	
	# Set portrait
	character.warm_portrait_cache()
	portrait_preview.texture = character.get_portrait_texture()
	
	# Update button states
	var is_in_party := character_id in current_world_db.party
	add_character_btn.disabled = is_in_party
	add_character_btn.text = "✓ In Party" if is_in_party else "➕ Add to Party"

func _on_add_character_pressed() -> void:
	# Open card picker dialog
	_populate_card_picker()
	card_picker_dialog.popup_centered()

func _populate_card_picker() -> void:
	picker_list.clear()
	var all_cards := CardRepository.load_cards()
	available_cards.clear()
	
	# Filter out characters already in campaign
	var campaign_char_ids: Dictionary = {}
	if current_world_db:
		for char_id in current_world_db.characters.keys():
			campaign_char_ids[char_id] = true
	
	for card in all_cards:
		var char_id := _generate_character_id(card)
		if not campaign_char_ids.has(char_id):
			available_cards.append(card)
			var display_name: String = card.name if not card.name.is_empty() else char_id
			picker_list.add_item(display_name)

func _on_picker_item_selected(index: int) -> void:
	if index < 0 or index >= available_cards.size():
		return
	
	var card: CharacterProfile = available_cards[index]
	
	# Update preview
	picker_name_label.text = card.name
	picker_desc_label.text = _truncate_text(card.description, 300)
	card.warm_portrait_cache()
	picker_portrait.texture = card.get_portrait_texture()

func _on_picker_add_pressed() -> void:
	var selected := picker_list.get_selected_items()
	if selected.is_empty():
		push_warning("No character selected")
		return
	
	var index := selected[0]
	if index < 0 or index >= available_cards.size():
		return
	
	var card: CharacterProfile = available_cards[index]
	_add_character_to_campaign(card)
	
	card_picker_dialog.hide()

func _on_picker_cancel_pressed() -> void:
	card_picker_dialog.hide()

func _add_character_to_campaign(card: CharacterProfile) -> void:
	if current_world_db == null:
		return
	
	# Generate character ID from card name
	var character_id := _generate_character_id(card)
	
	# Check if already exists
	if current_world_db.characters.has(character_id):
		push_warning("Character already in campaign: " + character_id)
		return
	
	# Add to repository if not already there
	var card_path := CardRepository.add_card_to_repo(card)
	if card_path.is_empty():
		push_error("Failed to add character to repository")
		return
	
	# Add to world_db
	current_world_db.characters[character_id] = card_path
	
	# Emit signal
	character_added.emit(character_id)
	
	# Refresh list
	refresh_characters_list()
	
	# Select the newly added character
	for i in range(character_list.item_count):
		if str(character_list.get_item_metadata(i)) == character_id:
			character_list.select(i)
			_on_character_selected(i)
			break

func _on_add_to_party_pressed() -> void:
	if current_world_db == null or selected_character_id.is_empty():
		return
	
	# Add to party array if not already there
	if not selected_character_id in current_world_db.party:
		current_world_db.party.append(selected_character_id)
	
	# Refresh display to update button state
	_display_character_info(selected_character_id)

func _on_remove_from_campaign_pressed() -> void:
	if current_world_db == null or selected_character_id.is_empty():
		return
	
	# Remove from party if present
	var party_idx := current_world_db.party.find(selected_character_id)
	if party_idx >= 0:
		current_world_db.party.remove_at(party_idx)
	
	# Remove from characters dict
	current_world_db.characters.erase(selected_character_id)
	
	# Emit signal
	character_removed.emit(selected_character_id)
	
	# Clear selection and refresh
	selected_character_id = ""
	refresh_characters_list()

func _generate_character_id(card: CharacterProfile) -> String:
	# Generate a character_id from the card name
	var base_id := card.name.to_lower().replace(" ", "_")
	
	# Remove special characters
	var regex := RegEx.new()
	regex.compile("[^a-z0-9_]")
	base_id = regex.sub(base_id, "", true)
	
	if base_id.is_empty():
		base_id = "character"
	
	return base_id

func _truncate_text(text: String, max_chars: int) -> String:
	if text.is_empty():
		return text
	if text.length() <= max_chars:
		return text
	var truncated := text.substr(0, max_chars)
	var last_space := truncated.rfind(" ")
	if last_space > max_chars - 60:
		truncated = truncated.substr(0, last_space)
	return truncated + "…"
