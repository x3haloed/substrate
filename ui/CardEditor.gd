extends Control
class_name CardEditor

## Character Profile Card Editor
## Allows creating and editing CharacterProfile resources with .scrd extension

signal closed()
signal profile_saved(path: String)

var current_profile: CharacterProfile = null
var current_path: String = ""  # Path for save (without .scrd extension)

# File dialogs
var save_file_dialog: FileDialog
var open_file_dialog: FileDialog
var import_file_dialog: FileDialog
var portrait_file_dialog: FileDialog

# Core fields
@onready var name_edit: LineEdit = $VBox/ScrollContainer/VBox/CoreSection/NameEdit
@onready var description_edit: TextEdit = $VBox/ScrollContainer/VBox/CoreSection/DescriptionEdit
@onready var personality_edit: TextEdit = $VBox/ScrollContainer/VBox/CoreSection/PersonalityEdit
@onready var first_mes_edit: TextEdit = $VBox/ScrollContainer/VBox/CoreSection/FirstMesEdit
@onready var mes_example_edit: TextEdit = $VBox/ScrollContainer/VBox/CoreSection/MesExampleEdit

# Metadata fields
@onready var creator_edit: LineEdit = $VBox/ScrollContainer/VBox/MetadataSection/CreatorEdit
@onready var character_version_edit: LineEdit = $VBox/ScrollContainer/VBox/MetadataSection/CharacterVersionEdit
@onready var portrait_preview: TextureRect = $VBox/ScrollContainer/VBox/MetadataSection/PortraitSection/HBox/PortraitPreview
@onready var set_portrait_button: Button = $VBox/ScrollContainer/VBox/MetadataSection/PortraitSection/HBox/VBox/SetPortraitButton
@onready var clear_portrait_button: Button = $VBox/ScrollContainer/VBox/MetadataSection/PortraitSection/HBox/VBox/ClearPortraitButton
@onready var creator_notes_edit: TextEdit = $VBox/ScrollContainer/VBox/MetadataSection/CreatorNotesEdit
@onready var system_prompt_edit: TextEdit = $VBox/ScrollContainer/VBox/MetadataSection/SystemPromptEdit
@onready var tags_edit: LineEdit = $VBox/ScrollContainer/VBox/MetadataSection/TagsEdit
@onready var alternate_greetings_list: ItemList = $VBox/ScrollContainer/VBox/MetadataSection/AlternateGreetingsBox/GreetingsList
@onready var alternate_greeting_edit: LineEdit = $VBox/ScrollContainer/VBox/MetadataSection/AlternateGreetingsBox/HBox/GreetingEdit
@onready var add_greeting_button: Button = $VBox/ScrollContainer/VBox/MetadataSection/AlternateGreetingsBox/HBox/AddGreetingButton
@onready var remove_greeting_button: Button = $VBox/ScrollContainer/VBox/MetadataSection/AlternateGreetingsBox/HBox/RemoveGreetingButton

# Character Book section
@onready var character_book_panel: Panel = $VBox/ScrollContainer/VBox/CharacterBookSection/BookPanel
@onready var book_name_edit: LineEdit = $VBox/ScrollContainer/VBox/CharacterBookSection/BookPanel/VBox/BookNameEdit
@onready var book_description_edit: TextEdit = $VBox/ScrollContainer/VBox/CharacterBookSection/BookPanel/VBox/BookDescriptionEdit
@onready var scan_depth_spin: SpinBox = $VBox/ScrollContainer/VBox/CharacterBookSection/BookPanel/VBox/ScanDepthSpin
@onready var token_budget_spin: SpinBox = $VBox/ScrollContainer/VBox/CharacterBookSection/BookPanel/VBox/TokenBudgetSpin
@onready var recursive_scanning_check: CheckBox = $VBox/ScrollContainer/VBox/CharacterBookSection/BookPanel/VBox/RecursiveScanningCheck
@onready var book_entries_list: ItemList = $VBox/ScrollContainer/VBox/CharacterBookSection/BookPanel/VBox/EntriesList
@onready var book_entry_panel: Panel = $VBox/ScrollContainer/VBox/CharacterBookSection/BookPanel/VBox/EntryEditPanel
@onready var entry_keys_edit: LineEdit = $VBox/ScrollContainer/VBox/CharacterBookSection/BookPanel/VBox/EntryEditPanel/VBox/EntryKeysEdit
@onready var entry_content_edit: TextEdit = $VBox/ScrollContainer/VBox/CharacterBookSection/BookPanel/VBox/EntryEditPanel/VBox/EntryContentEdit
@onready var entry_enabled_check: CheckBox = $VBox/ScrollContainer/VBox/CharacterBookSection/BookPanel/VBox/EntryEditPanel/VBox/EntryEnabledCheck
@onready var entry_insertion_order_spin: SpinBox = $VBox/ScrollContainer/VBox/CharacterBookSection/BookPanel/VBox/EntryEditPanel/VBox/EntryInsertionOrderSpin
@onready var add_entry_button: Button = $VBox/ScrollContainer/VBox/CharacterBookSection/BookPanel/VBox/AddEntryButton
@onready var remove_entry_button: Button = $VBox/ScrollContainer/VBox/CharacterBookSection/BookPanel/VBox/RemoveEntryButton
@onready var create_book_button: Button = $VBox/ScrollContainer/VBox/CharacterBookSection/CreateBookButton

# Stats section
@onready var stats_tree: Tree = $VBox/ScrollContainer/VBox/StatsSection/StatsTree
@onready var stat_key_edit: LineEdit = $VBox/ScrollContainer/VBox/StatsSection/HBox/StatKeyEdit
@onready var stat_value_edit: LineEdit = $VBox/ScrollContainer/VBox/StatsSection/HBox/StatValueEdit
@onready var add_stat_button: Button = $VBox/ScrollContainer/VBox/StatsSection/HBox/AddStatButton
@onready var remove_stat_button: Button = $VBox/ScrollContainer/VBox/StatsSection/HBox/RemoveStatButton

# Traits section
@onready var traits_list: ItemList = $VBox/ScrollContainer/VBox/TraitsSection/TraitsList
@onready var trait_edit: LineEdit = $VBox/ScrollContainer/VBox/TraitsSection/HBox/TraitEdit
@onready var add_trait_button: Button = $VBox/ScrollContainer/VBox/TraitsSection/HBox/AddTraitButton
@onready var remove_trait_button: Button = $VBox/ScrollContainer/VBox/TraitsSection/HBox/RemoveTraitButton

# Style section
@onready var style_tree: Tree = $VBox/ScrollContainer/VBox/StyleSection/StyleTree
@onready var style_key_edit: LineEdit = $VBox/ScrollContainer/VBox/StyleSection/HBox/StyleKeyEdit
@onready var style_value_edit: LineEdit = $VBox/ScrollContainer/VBox/StyleSection/HBox/StyleValueEdit
@onready var add_style_button: Button = $VBox/ScrollContainer/VBox/StyleSection/HBox/AddStyleButton
@onready var remove_style_button: Button = $VBox/ScrollContainer/VBox/StyleSection/HBox/RemoveStyleButton

# Triggers section
@onready var triggers_list: ItemList = $VBox/ScrollContainer/VBox/TriggersSection/TriggersList
@onready var trigger_panel: Panel = $VBox/ScrollContainer/VBox/TriggersSection/TriggerEditPanel
@onready var trigger_id_edit: LineEdit = $VBox/ScrollContainer/VBox/TriggersSection/TriggerEditPanel/VBox/TriggerIdEdit
@onready var trigger_ns_edit: LineEdit = $VBox/ScrollContainer/VBox/TriggersSection/TriggerEditPanel/VBox/TriggerNsEdit
@onready var trigger_when_edit: LineEdit = $VBox/ScrollContainer/VBox/TriggersSection/TriggerEditPanel/VBox/TriggerWhenEdit
@onready var trigger_narration_edit: TextEdit = $VBox/ScrollContainer/VBox/TriggersSection/TriggerEditPanel/VBox/TriggerNarrationEdit
@onready var trigger_priority_spin: SpinBox = $VBox/ScrollContainer/VBox/TriggersSection/TriggerEditPanel/VBox/TriggerPrioritySpin
@onready var trigger_cooldown_spin: SpinBox = $VBox/ScrollContainer/VBox/TriggersSection/TriggerEditPanel/VBox/TriggerCooldownSpin
@onready var trigger_action_verb_edit: LineEdit = $VBox/ScrollContainer/VBox/TriggersSection/TriggerEditPanel/VBox/ActionBox/VerbEdit
@onready var trigger_action_target_edit: LineEdit = $VBox/ScrollContainer/VBox/TriggersSection/TriggerEditPanel/VBox/ActionBox/TargetEdit
@onready var add_trigger_button: Button = $VBox/ScrollContainer/VBox/TriggersSection/HBox/AddTriggerButton
@onready var remove_trigger_button: Button = $VBox/ScrollContainer/VBox/TriggersSection/HBox/RemoveTriggerButton

# Extensions section
@onready var extensions_tree: Tree = $VBox/ScrollContainer/VBox/ExtensionsSection/ExtensionsTree
@onready var extension_key_edit: LineEdit = $VBox/ScrollContainer/VBox/ExtensionsSection/HBox/ExtensionKeyEdit
@onready var extension_value_edit: LineEdit = $VBox/ScrollContainer/VBox/ExtensionsSection/HBox/ExtensionValueEdit
@onready var add_extension_button: Button = $VBox/ScrollContainer/VBox/ExtensionsSection/HBox/AddExtensionButton
@onready var remove_extension_button: Button = $VBox/ScrollContainer/VBox/ExtensionsSection/HBox/RemoveExtensionButton

# Toolbar buttons
@onready var new_button: Button = $VBox/Toolbar/NewButton
@onready var open_button: Button = $VBox/Toolbar/OpenButton
@onready var import_button: Button = $VBox/Toolbar/ImportButton
@onready var save_button: Button = $VBox/Toolbar/SaveButton
@onready var save_as_button: Button = $VBox/Toolbar/SaveAsButton
@onready var close_button: Button = $VBox/Toolbar/CloseButton

var selected_entry_index: int = -1
var selected_trigger_index: int = -1

func _ready():
	# Connect toolbar buttons
	new_button.pressed.connect(_on_new_pressed)
	open_button.pressed.connect(_on_open_pressed)
	import_button.pressed.connect(_on_import_pressed)
	save_button.pressed.connect(_on_save_pressed)
	save_as_button.pressed.connect(_on_save_as_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	# Connect metadata buttons
	add_greeting_button.pressed.connect(_on_add_greeting_pressed)
	remove_greeting_button.pressed.connect(_on_remove_greeting_pressed)
	set_portrait_button.pressed.connect(_on_set_portrait_pressed)
	clear_portrait_button.pressed.connect(_on_clear_portrait_pressed)
	
	# Connect character book buttons
	create_book_button.pressed.connect(_on_create_book_pressed)
	add_entry_button.pressed.connect(_on_add_entry_pressed)
	remove_entry_button.pressed.connect(_on_remove_entry_pressed)
	book_entries_list.item_selected.connect(_on_entry_selected)
	
	# Connect stats buttons
	add_stat_button.pressed.connect(_on_add_stat_pressed)
	remove_stat_button.pressed.connect(_on_remove_stat_pressed)
	stats_tree.item_selected.connect(_on_stat_selected)
	
	# Connect traits buttons
	add_trait_button.pressed.connect(_on_add_trait_pressed)
	remove_trait_button.pressed.connect(_on_remove_trait_pressed)
	
	# Connect style buttons
	add_style_button.pressed.connect(_on_add_style_pressed)
	remove_style_button.pressed.connect(_on_remove_style_pressed)
	style_tree.item_selected.connect(_on_style_selected)
	
	# Connect triggers buttons
	add_trigger_button.pressed.connect(_on_add_trigger_pressed)
	remove_trigger_button.pressed.connect(_on_remove_trigger_pressed)
	triggers_list.item_selected.connect(_on_trigger_selected)
	
	# Connect extensions buttons
	add_extension_button.pressed.connect(_on_add_extension_pressed)
	remove_extension_button.pressed.connect(_on_remove_extension_pressed)
	extensions_tree.item_selected.connect(_on_extension_selected)
	
	# Connect auto-save signals for entries
	entry_keys_edit.text_changed.connect(_on_entry_keys_edit_text_changed)
	entry_content_edit.text_changed.connect(_on_entry_content_edit_text_changed)
	entry_enabled_check.toggled.connect(_on_entry_enabled_check_toggled)
	entry_insertion_order_spin.value_changed.connect(_on_entry_insertion_order_spin_value_changed)
	
	# Connect auto-save signals for triggers
	trigger_id_edit.text_changed.connect(_on_trigger_id_edit_text_changed)
	trigger_ns_edit.text_changed.connect(_on_trigger_ns_edit_text_changed)
	trigger_when_edit.text_changed.connect(_on_trigger_when_edit_text_changed)
	trigger_narration_edit.text_changed.connect(_on_trigger_narration_edit_text_changed)
	trigger_priority_spin.value_changed.connect(_on_trigger_priority_spin_value_changed)
	trigger_cooldown_spin.value_changed.connect(_on_trigger_cooldown_spin_value_changed)
	trigger_action_verb_edit.text_changed.connect(_on_trigger_action_verb_edit_text_changed)
	trigger_action_target_edit.text_changed.connect(_on_trigger_action_target_edit_text_changed)
	
	# Setup file dialogs
	_setup_file_dialogs()
	
	# Initialize with new profile
	create_new_profile()
	
	visible = false

func _setup_file_dialogs():
	# Save file dialog
	save_file_dialog = FileDialog.new()
	save_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_file_dialog.add_filter("*.scrd ; Substrate Card Files")
	save_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_file_dialog.file_selected.connect(_on_save_file_selected)
	add_child(save_file_dialog)
	
	# Open file dialog
	open_file_dialog = FileDialog.new()
	open_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_file_dialog.add_filter("*.scrd ; Substrate Card Files")
	open_file_dialog.add_filter("*.tres ; Godot Resource Files")
	open_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	open_file_dialog.file_selected.connect(_on_open_file_selected)
	add_child(open_file_dialog)

	# Import JSON dialog
	import_file_dialog = FileDialog.new()
	import_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_file_dialog.add_filter("*.json ; CC v2 JSON Files")
	import_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_file_dialog.file_selected.connect(_on_import_file_selected)
	add_child(import_file_dialog)

	# Portrait image dialog (allow common image types Godot can load)
	portrait_file_dialog = FileDialog.new()
	portrait_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	portrait_file_dialog.add_filter("*.png ; PNG Images")
	portrait_file_dialog.add_filter("*.jpg, *.jpeg ; JPEG Images")
	portrait_file_dialog.add_filter("*.webp ; WebP Images")
	portrait_file_dialog.add_filter("*.bmp ; BMP Images")
	portrait_file_dialog.add_filter("*.tga ; TGA Images")
	portrait_file_dialog.add_filter("*.* ; All Files")
	portrait_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	portrait_file_dialog.file_selected.connect(_on_portrait_file_selected)
	add_child(portrait_file_dialog)

func _on_import_pressed():
	import_file_dialog.popup_centered_ratio(0.75)

func _on_import_file_selected(path: String):
	var imported: CharacterProfile = CharacterCardLoader.import_from_json(path)
	if not imported:
		push_error("Failed to import character card from JSON")
		return
	current_profile = imported
	current_path = ""  # New imported profile has no save path yet
	_load_profile_to_ui()

func _on_set_portrait_pressed():
	portrait_file_dialog.popup_centered_ratio(0.75)

func _on_portrait_file_selected(path: String):
	# Load image from disk and set as portrait
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		push_error("Failed to load image: " + path)
		return
	var tex := ImageTexture.create_from_image(img)
	if current_profile and tex:
		current_profile.set_portrait_texture(tex)
		portrait_preview.texture = current_profile.get_portrait_texture()

func _on_clear_portrait_pressed():
	if current_profile:
		current_profile.clear_portrait()
		portrait_preview.texture = null

func create_new_profile():
	current_profile = CharacterProfile.new()
	current_path = ""
	_load_profile_to_ui()

func _load_profile_to_ui():
	if not current_profile:
		return
	
	# Core fields
	name_edit.text = current_profile.name
	description_edit.text = current_profile.description
	personality_edit.text = current_profile.personality
	first_mes_edit.text = current_profile.first_mes
	mes_example_edit.text = current_profile.mes_example
	
	# Metadata
	creator_edit.text = current_profile.creator
	character_version_edit.text = current_profile.character_version
	creator_notes_edit.text = current_profile.creator_notes
	system_prompt_edit.text = current_profile.system_prompt
	
	# Tags
	tags_edit.text = ", ".join(current_profile.tags)
	
	# Alternate greetings
	alternate_greetings_list.clear()
	for greeting in current_profile.alternate_greetings:
		alternate_greetings_list.add_item(greeting)
	
	# Character book
	_update_character_book_ui()
	
	# Stats
	_update_stats_tree()
	
	# Traits
	traits_list.clear()
	for t in current_profile.traits:
		traits_list.add_item(t)
	
	# Style
	_update_style_tree()
	
	# Triggers
	_update_triggers_list()
	
	# Extensions
	_update_extensions_tree()

	# Portrait preview
	if current_profile:
		# Try to warm cache and set texture
		current_profile.warm_portrait_cache()
		portrait_preview.texture = current_profile.get_portrait_texture()

func _update_character_book_ui():
	if current_profile.character_book:
		character_book_panel.visible = true
		create_book_button.visible = false
		var book = current_profile.character_book
		book_name_edit.text = book.name
		book_description_edit.text = book.description
		scan_depth_spin.value = book.scan_depth
		token_budget_spin.value = book.token_budget
		recursive_scanning_check.button_pressed = book.recursive_scanning
		
		book_entries_list.clear()
		for i in range(book.entries.size()):
			var entry = book.entries[i]
			var keys_str = ", ".join(entry.keys)
			book_entries_list.add_item("%d: %s" % [i, keys_str])
	else:
		character_book_panel.visible = false
		create_book_button.visible = true
		book_entry_panel.visible = false
		selected_entry_index = -1

func _update_stats_tree():
	stats_tree.clear()
	var root = stats_tree.create_item()
	root.set_text(0, "Stats")
	for key in current_profile.stats.keys():
		var item = stats_tree.create_item(root)
		item.set_text(0, key)
		item.set_text(1, str(current_profile.stats[key]))
		item.set_metadata(0, key)

func _update_style_tree():
	style_tree.clear()
	var root = style_tree.create_item()
	root.set_text(0, "Style")
	for key in current_profile.style.keys():
		var item = style_tree.create_item(root)
		item.set_text(0, key)
		item.set_text(1, str(current_profile.style[key]))
		item.set_metadata(0, key)

func _update_triggers_list():
	triggers_list.clear()
	for i in range(current_profile.triggers.size()):
		var trigger = current_profile.triggers[i]
		var label = trigger.id if trigger.id != "" else "Trigger %d" % i
		triggers_list.add_item(label)
	if current_profile.triggers.is_empty():
		trigger_panel.visible = false
		selected_trigger_index = -1

func _update_extensions_tree():
	extensions_tree.clear()
	var root = extensions_tree.create_item()
	root.set_text(0, "Extensions")
	for key in current_profile.extensions.keys():
		var item = extensions_tree.create_item(root)
		item.set_text(0, key)
		item.set_text(1, str(current_profile.extensions[key]))
		item.set_metadata(0, key)

func _save_profile_from_ui():
	if not current_profile:
		return
	
	# Core fields
	current_profile.name = name_edit.text
	current_profile.description = description_edit.text
	current_profile.personality = personality_edit.text
	current_profile.first_mes = first_mes_edit.text
	current_profile.mes_example = mes_example_edit.text
	
	# Metadata
	current_profile.creator = creator_edit.text
	current_profile.character_version = character_version_edit.text
	current_profile.creator_notes = creator_notes_edit.text
	current_profile.system_prompt = system_prompt_edit.text
	
	# Tags (convert PackedStringArray -> Array[String])
	var tags_text = tags_edit.text.strip_edges()
	var tags_arr: Array[String] = []
	if tags_text != "":
		var parts = tags_text.split(",")
		for p in parts:
			tags_arr.append(str(p).strip_edges())
	current_profile.tags = tags_arr
	
	# Alternate greetings
	current_profile.alternate_greetings.clear()
	for i in range(alternate_greetings_list.get_item_count()):
		current_profile.alternate_greetings.append(alternate_greetings_list.get_item_text(i))
	
	# Character book
	if current_profile.character_book:
		var book = current_profile.character_book
		book.name = book_name_edit.text
		book.description = book_description_edit.text
		book.scan_depth = int(scan_depth_spin.value)
		book.token_budget = int(token_budget_spin.value)
		book.recursive_scanning = recursive_scanning_check.button_pressed
		# Entries are saved when edited
	
	# Traits (save from list)
	current_profile.traits.clear()
	for i in range(traits_list.get_item_count()):
		current_profile.traits.append(traits_list.get_item_text(i))
	
	# Stats, style, triggers, extensions are saved when edited via buttons

func _save_to_path(path: String) -> bool:
	_save_profile_from_ui()
	
	# Ensure path ends with .scrd, then convert to .tres for actual saving
	var scrd_path = path
	if not scrd_path.ends_with(".scrd"):
		if scrd_path.ends_with(".tres"):
			scrd_path = scrd_path.substr(0, scrd_path.length() - 5) + ".scrd"
		else:
			scrd_path = scrd_path + ".scrd"
	
	var tres_path = scrd_path.substr(0, scrd_path.length() - 5) + ".tres"
	
	var error = ResourceSaver.save(current_profile, tres_path)
	if error != OK:
		push_error("Failed to save profile: " + str(error))
		return false
	
	# Rename file from tres_path to scrd_path
	var success = DirAccess.rename_absolute(tres_path, scrd_path)
	if success != OK:
		push_error("Failed to rename .tres to .scrd: " + str(success))
		return false
	
	current_path = scrd_path
	profile_saved.emit(scrd_path)
	return true

# Toolbar handlers
func _on_new_pressed():
	create_new_profile()

func _on_open_pressed():
	open_file_dialog.popup_centered_ratio(0.75)

func _on_open_file_selected(path: String):
	# Determine the actual file to load and the .scrd path to remember
	var tres_path = path
	var scrd_path = path
	
	if path.ends_with(".scrd"):
		# User selected .scrd - copy to temp .tres file and load
		if not FileAccess.file_exists(tres_path):
			push_error("Failed to load profile from " + path)

		tres_path = "user://__temp_load.tres"
		DirAccess.copy_absolute(path, tres_path)
	
	current_profile = load(tres_path) as CharacterProfile
	if not current_profile:
		push_error("Failed to load profile from " + path)
		return

	if path.ends_with(".scrd"):
		DirAccess.remove_absolute(tres_path)
	
	current_path = scrd_path
	_load_profile_to_ui()

func _on_save_pressed():
	if current_path == "":
		_on_save_as_pressed()
	else:
		_save_to_path(current_path)

func _on_save_as_pressed():
	# Suggest filename based on character name if available
	if current_profile and current_profile.name != "":
		var suggested_name = current_profile.name.to_lower().replace(" ", "_")
		save_file_dialog.current_file = suggested_name + ".scrd"
	save_file_dialog.popup_centered_ratio(0.75)

func _on_save_file_selected(path: String):
	if _save_to_path(path):
		print("Profile saved to: " + path)

func _on_close_pressed():
	closed.emit()
	visible = false

# Metadata handlers
func _on_add_greeting_pressed():
	var text = alternate_greeting_edit.text.strip_edges()
	if text != "":
		alternate_greetings_list.add_item(text)
		alternate_greeting_edit.text = ""
		# Update profile immediately
		current_profile.alternate_greetings.append(text)

func _on_remove_greeting_pressed():
	var selected = alternate_greetings_list.get_selected_items()
	if not selected.is_empty():
		var index = selected[0]
		if index < current_profile.alternate_greetings.size():
			current_profile.alternate_greetings.remove_at(index)
		alternate_greetings_list.remove_item(index)

# Character book handlers
func _on_create_book_pressed():
	if not current_profile.character_book:
		current_profile.character_book = CharacterBook.new()
		_update_character_book_ui()

func _on_add_entry_pressed():
	if not current_profile.character_book:
		return
	var entry = CharacterBookEntry.new()
	current_profile.character_book.entries.append(entry)
	_update_character_book_ui()
	book_entries_list.select(book_entries_list.get_item_count() - 1)
	_on_entry_selected(book_entries_list.get_item_count() - 1)

func _on_remove_entry_pressed():
	if selected_entry_index >= 0 and current_profile.character_book:
		current_profile.character_book.entries.remove_at(selected_entry_index)
		selected_entry_index = -1
		book_entry_panel.visible = false
		_update_character_book_ui()

func _on_entry_selected(index: int):
	if not current_profile.character_book or index < 0 or index >= current_profile.character_book.entries.size():
		return
	selected_entry_index = index
	var entry = current_profile.character_book.entries[index]
	entry_keys_edit.text = ", ".join(entry.keys)
	entry_content_edit.text = entry.content
	entry_enabled_check.button_pressed = entry.enabled
	entry_insertion_order_spin.value = entry.insertion_order
	book_entry_panel.visible = true

func _save_current_entry():
	if selected_entry_index >= 0 and current_profile.character_book:
		var entry = current_profile.character_book.entries[selected_entry_index]
		var keys_text = entry_keys_edit.text.strip_edges()
		var keys_arr: Array[String] = []
		if keys_text != "":
			var parts = keys_text.split(",")
			for p in parts:
				keys_arr.append(str(p).strip_edges())
		entry.keys = keys_arr
		entry.content = entry_content_edit.text
		entry.enabled = entry_enabled_check.button_pressed
		entry.insertion_order = int(entry_insertion_order_spin.value)
		_update_character_book_ui()
		if selected_entry_index < book_entries_list.get_item_count():
			book_entries_list.select(selected_entry_index)

# Stats handlers
func _on_add_stat_pressed():
	var key = stat_key_edit.text.strip_edges()
	var value_str = stat_value_edit.text.strip_edges()
	if key != "":
		current_profile.stats[key] = value_str
		stat_key_edit.text = ""
		stat_value_edit.text = ""
		_update_stats_tree()

func _on_remove_stat_pressed():
	var selected = stats_tree.get_selected()
	if selected and selected.get_metadata(0):
		var key = selected.get_metadata(0)
		current_profile.stats.erase(key)
		_update_stats_tree()

func _on_stat_selected():
	var selected = stats_tree.get_selected()
	if selected and selected.get_metadata(0):
		var key = selected.get_metadata(0)
		stat_key_edit.text = key
		stat_value_edit.text = str(current_profile.stats[key])

# Traits handlers
func _on_add_trait_pressed():
	var text = trait_edit.text.strip_edges()
	if text != "":
		traits_list.add_item(text)
		trait_edit.text = ""
		# Update profile immediately
		current_profile.traits.append(text)

func _on_remove_trait_pressed():
	var selected = traits_list.get_selected_items()
	if not selected.is_empty():
		var index = selected[0]
		if index < current_profile.traits.size():
			current_profile.traits.remove_at(index)
		traits_list.remove_item(index)

# Style handlers
func _on_add_style_pressed():
	var key = style_key_edit.text.strip_edges()
	var value_str = style_value_edit.text.strip_edges()
	if key != "":
		current_profile.style[key] = value_str
		style_key_edit.text = ""
		style_value_edit.text = ""
		_update_style_tree()

func _on_remove_style_pressed():
	var selected = style_tree.get_selected()
	if selected and selected.get_metadata(0):
		var key = selected.get_metadata(0)
		current_profile.style.erase(key)
		_update_style_tree()

func _on_style_selected():
	var selected = style_tree.get_selected()
	if selected and selected.get_metadata(0):
		var key = selected.get_metadata(0)
		style_key_edit.text = key
		style_value_edit.text = str(current_profile.style[key])

# Triggers handlers
func _on_add_trigger_pressed():
	var trigger = TriggerDef.new()
	trigger.id = "trigger_%d" % current_profile.triggers.size()
	current_profile.triggers.append(trigger)
	_update_triggers_list()
	triggers_list.select(triggers_list.get_item_count() - 1)
	_on_trigger_selected(triggers_list.get_item_count() - 1)

func _on_remove_trigger_pressed():
	if selected_trigger_index >= 0:
		current_profile.triggers.remove_at(selected_trigger_index)
		selected_trigger_index = -1
		trigger_panel.visible = false
		_update_triggers_list()

func _on_trigger_selected(index: int):
	if index < 0 or index >= current_profile.triggers.size():
		return
	selected_trigger_index = index
	var trigger = current_profile.triggers[index]
	trigger_id_edit.text = trigger.id
	trigger_ns_edit.text = trigger.ns
	trigger_when_edit.text = trigger.when
	trigger_narration_edit.text = trigger.narration
	trigger_priority_spin.value = trigger.priority
	trigger_cooldown_spin.value = trigger.cooldown
	trigger_action_verb_edit.text = trigger.action.get("verb", "")
	trigger_action_target_edit.text = trigger.action.get("target", "")
	trigger_panel.visible = true

func _save_current_trigger():
	if selected_trigger_index >= 0:
		var trigger = current_profile.triggers[selected_trigger_index]
		trigger.id = trigger_id_edit.text
		trigger.ns = trigger_ns_edit.text
		trigger.when = trigger_when_edit.text
		trigger.narration = trigger_narration_edit.text
		trigger.priority = int(trigger_priority_spin.value)
		trigger.cooldown = trigger_cooldown_spin.value
		trigger.action["verb"] = trigger_action_verb_edit.text
		trigger.action["target"] = trigger_action_target_edit.text
		_update_triggers_list()
		if selected_trigger_index < triggers_list.get_item_count():
			triggers_list.select(selected_trigger_index)

# Extensions handlers
func _on_add_extension_pressed():
	var key = extension_key_edit.text.strip_edges()
	var value_str = extension_value_edit.text.strip_edges()
	if key != "":
		current_profile.extensions[key] = value_str
		extension_key_edit.text = ""
		extension_value_edit.text = ""
		_update_extensions_tree()

func _on_remove_extension_pressed():
	var selected = extensions_tree.get_selected()
	if selected and selected.get_metadata(0):
		var key = selected.get_metadata(0)
		current_profile.extensions.erase(key)
		_update_extensions_tree()

func _on_extension_selected():
	var selected = extensions_tree.get_selected()
	if selected and selected.get_metadata(0):
		var key = selected.get_metadata(0)
		extension_key_edit.text = key
		extension_value_edit.text = str(current_profile.extensions[key])

# Auto-save entries and triggers when editing
func _on_entry_keys_edit_text_changed():
	if selected_entry_index >= 0:
		_save_current_entry()

func _on_entry_content_edit_text_changed():
	if selected_entry_index >= 0:
		_save_current_entry()

func _on_entry_enabled_check_toggled(_button_pressed: bool):
	if selected_entry_index >= 0:
		_save_current_entry()

func _on_entry_insertion_order_spin_value_changed(_value: float):
	if selected_entry_index >= 0:
		_save_current_entry()

func _on_trigger_id_edit_text_changed():
	if selected_trigger_index >= 0:
		_save_current_trigger()

func _on_trigger_ns_edit_text_changed():
	if selected_trigger_index >= 0:
		_save_current_trigger()

func _on_trigger_when_edit_text_changed():
	if selected_trigger_index >= 0:
		_save_current_trigger()

func _on_trigger_narration_edit_text_changed():
	if selected_trigger_index >= 0:
		_save_current_trigger()

func _on_trigger_priority_spin_value_changed(_value: float):
	if selected_trigger_index >= 0:
		_save_current_trigger()

func _on_trigger_cooldown_spin_value_changed(_value: float):
	if selected_trigger_index >= 0:
		_save_current_trigger()

func _on_trigger_action_verb_edit_text_changed():
	if selected_trigger_index >= 0:
		_save_current_trigger()

func _on_trigger_action_target_edit_text_changed():
	if selected_trigger_index >= 0:
		_save_current_trigger()
