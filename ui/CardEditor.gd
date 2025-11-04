extends Control
class_name CardEditor

## Character Profile Card Editor
## Allows creating and editing CharacterProfile resources with .scrd extension

signal closed()
signal profile_saved(path: String)

var llm_client: LLMClient

var current_profile: CharacterProfile = null
var current_path: String = ""  # Path for save (without .scrd extension)

# File dialogs
var export_file_dialog: FileDialog
var open_file_dialog: FileDialog
var import_file_dialog: FileDialog
var portrait_file_dialog: FileDialog

# Left panel
@onready var card_list: ItemList = %CardList
@onready var delete_button: Button = %DeleteButton

# Core fields
@onready var name_edit: LineEdit = %NameEdit
@onready var description_edit: TextEdit = %DescriptionEdit
@onready var personality_edit: TextEdit = %PersonalityEdit
@onready var first_mes_edit: TextEdit = %FirstMesEdit
@onready var mes_example_edit: TextEdit = %MesExampleEdit

# Metadata fields
@onready var creator_edit: LineEdit = %CreatorEdit
@onready var character_version_edit: LineEdit = %CharacterVersionEdit
@onready var portrait_preview: TextureRect = %PortraitPreview
@onready var set_portrait_button: Button = %SetPortraitButton
@onready var clear_portrait_button: Button = %ClearPortraitButton
@onready var creator_notes_edit: TextEdit = %CreatorNotesEdit
@onready var system_prompt_edit: TextEdit = %SystemPromptEdit
@onready var tags_edit: LineEdit = %TagsEdit
@onready var alternate_greetings_list: ItemList = %GreetingsList
@onready var alternate_greeting_edit: LineEdit = %GreetingEdit
@onready var add_greeting_button: Button = %AddGreetingButton
@onready var remove_greeting_button: Button = %RemoveGreetingButton

# Character Book section
@onready var character_book_panel: Panel = %BookPanel
@onready var book_name_edit: LineEdit = %BookNameEdit
@onready var book_description_edit: TextEdit = %BookDescriptionEdit
@onready var scan_depth_spin: SpinBox = %ScanDepthSpin
@onready var token_budget_spin: SpinBox = %TokenBudgetSpin
@onready var recursive_scanning_check: CheckBox = %RecursiveScanningCheck
@onready var book_entries_list: ItemList = %EntriesList
@onready var book_entry_panel: Panel = %EntryEditPanel
@onready var entry_keys_edit: LineEdit = %EntryKeysEdit
@onready var entry_content_edit: TextEdit = %EntryContentEdit
@onready var entry_enabled_check: CheckBox = %EntryEnabledCheck
@onready var entry_insertion_order_spin: SpinBox = %EntryInsertionOrderSpin
@onready var add_entry_button: Button = %AddEntryButton
@onready var remove_entry_button: Button = %RemoveEntryButton
@onready var create_book_button: Button = %CreateBookButton

# Stats section
@onready var stats_tree: Tree = %StatsTree
@onready var stat_key_edit: LineEdit = %StatKeyEdit
@onready var stat_value_edit: LineEdit = %StatValueEdit
@onready var add_stat_button: Button = %AddStatButton
@onready var remove_stat_button: Button = %RemoveStatButton

# Traits section
@onready var traits_list: ItemList = %TraitsList
@onready var trait_edit: LineEdit = %TraitEdit
@onready var add_trait_button: Button = %AddTraitButton
@onready var remove_trait_button: Button = %RemoveTraitButton

# Style section
@onready var style_tree: Tree = %StyleTree
@onready var style_key_edit: LineEdit = %StyleKeyEdit
@onready var style_value_edit: LineEdit = %StyleValueEdit
@onready var add_style_button: Button = %AddStyleButton
@onready var remove_style_button: Button = %RemoveStyleButton

# Triggers section
@onready var triggers_list: ItemList = %TriggersList
@onready var trigger_panel: Panel = %TriggerEditPanel
@onready var trigger_id_edit: LineEdit = %TriggerIdEdit
@onready var trigger_ns_edit: LineEdit = %TriggerNsEdit
@onready var trigger_when_edit: LineEdit = %TriggerWhenEdit
@onready var trigger_narration_edit: TextEdit = %TriggerNarrationEdit
@onready var trigger_priority_spin: SpinBox = %TriggerPrioritySpin
@onready var trigger_cooldown_spin: SpinBox = %TriggerCooldownSpin
@onready var trigger_action_verb_edit: LineEdit = %VerbEdit
@onready var trigger_action_target_edit: LineEdit = %TargetEdit
@onready var add_trigger_button: Button = %AddTriggerButton
@onready var remove_trigger_button: Button = %RemoveTriggerButton

# Extensions section
@onready var extensions_tree: Tree = %ExtensionsTree
@onready var extension_key_edit: LineEdit = %ExtensionKeyEdit
@onready var extension_value_edit: LineEdit = %ExtensionValueEdit
@onready var add_extension_button: Button = %AddExtensionButton
@onready var remove_extension_button: Button = %RemoveExtensionButton

# Advanced visibility controls
@onready var advanced_sections: VBoxContainer = %AdvancedSections
@onready var advanced_toggle_button: Button = %AdvancedToggleButton
@onready var advanced_button: Button = %AdvancedButton
@onready var scroll_container: ScrollContainer = %ScrollContainer

# Chat test controls
@onready var chat_window: ChatWindow = %ChatWindow

# Toolbar buttons
@onready var new_button: Button = %NewButton
@onready var open_button: Button = %OpenButton
@onready var import_button: Button = %ImportButton
@onready var save_button: Button = %SaveButton
@onready var export_button: Button = %ExportButton
@onready var close_button: Button = %CloseButton
@onready var start_chat_button: Button = %StartChatButton

var editor_cards: Array[Dictionary] = [] # Array of {path: String, profile: CharacterProfile}

var selected_entry_index: int = -1
var selected_trigger_index: int = -1
var advanced_visible: bool = false
var _greeting_index: int = 0

# Lightweight LLM chat sandbox state for the editor's ChatWindow
var _prompt_engine: PromptEngine
var _sandbox_world: WorldDB
var _sandbox_scene: SceneGraph
var _sandbox_npc_id: String = ""

func _ready():
	# Sync builtin cards to editor storage
	CardRepository.sync_builtin_cards_to_repo(CardRepository.StoreKind.EDITOR)
	
	# Connect toolbar buttons
	new_button.pressed.connect(_on_new_pressed)
	open_button.pressed.connect(_on_open_pressed)
	import_button.pressed.connect(_on_import_pressed)
	save_button.pressed.connect(_on_save_pressed)
	export_button.pressed.connect(_on_export_pressed)
	close_button.pressed.connect(_on_close_pressed)
	advanced_button.pressed.connect(_on_advanced_toggle_pressed)
	advanced_toggle_button.pressed.connect(_on_advanced_toggle_pressed)
	_set_advanced_visible(advanced_sections.visible)
	start_chat_button.pressed.connect(_on_start_chat_pressed)
	
	# Connect card list
	card_list.item_selected.connect(_on_card_list_item_selected)
	delete_button.pressed.connect(_on_delete_button_pressed)
	
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
	
	# Hide content until user starts or opens/imports a card
	scroll_container.visible = false
	
	# Load editor cards
	_refresh_card_list()
	
	visible = false

func _setup_file_dialogs():
	# Export file dialog (.scrd only)
	export_file_dialog = FileDialog.new()
	export_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_file_dialog.add_filter("*.scrd ; Substrate Card Files")
	export_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_file_dialog.file_selected.connect(_on_export_file_selected)
	add_child(export_file_dialog)
	
	# Open file dialog
	open_file_dialog = FileDialog.new()
	open_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_file_dialog.add_filter("*.tres ; Godot Resource Files")
	open_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	open_file_dialog.file_selected.connect(_on_open_file_selected)
	add_child(open_file_dialog)

	# Import JSON dialog
	import_file_dialog = FileDialog.new()
	import_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_file_dialog.add_filter("*.json ; CC v2 JSON Files")
	import_file_dialog.add_filter("*.png ; CC v2 PNG Files")
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
	var imported: CharacterProfile = null
	if path.to_lower().ends_with(".png"):
		imported = CharacterCardLoader.import_from_png(path)
	else:
		imported = CharacterCardLoader.import_from_json(path)
	if not imported:
		push_error("Failed to import character card from JSON")
		return
	
	# Save to editor store
	var saved_path := CardRepository.add_card_to_repo(imported, CardRepository.StoreKind.EDITOR)
	if saved_path == "":
		push_error("Failed to save imported card to editor repository")
		return
	
	current_profile = imported
	current_path = saved_path
	_load_profile_to_ui()
	# Reveal content after import completes
	scroll_container.visible = true
	# Refresh card list to show new import
	_refresh_card_list()

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
	
	# Save as .tres in editor repository
	var tres_path = path
	if not tres_path.ends_with(".tres"):
		if tres_path.ends_with(".scrd"):
			tres_path = tres_path.substr(0, tres_path.length() - 5) + ".tres"
		else:
			tres_path = tres_path + ".tres"
	
	var error = ResourceSaver.save(current_profile, tres_path)
	if error != OK:
		push_error("Failed to save profile: " + str(error))
		return false
	
	current_path = tres_path
	profile_saved.emit(tres_path)
	_refresh_card_list()
	return true

func _export_to_path(path: String) -> bool:
	# Export as .scrd by saving to a temporary .tres then renaming
	_save_profile_from_ui()
	var temp_tres := "user://__temp_export_card.tres"
	var error = ResourceSaver.save(current_profile, temp_tres)
	if error != OK:
		push_error("Failed to prepare export: " + str(error))
		return false
	# Remove existing target if present
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var success := DirAccess.rename_absolute(temp_tres, path)
	if success != OK:
		push_error("Failed to write .scrd export: " + str(success))
		return false
	return true

# Toolbar handlers
func _on_new_pressed():
	create_new_profile()
	# Reveal content after creating new profile
	scroll_container.visible = true

func _on_open_pressed():
	open_file_dialog.popup_centered_ratio(0.75)

func _on_open_file_selected(path: String):
	current_profile = load(path) as CharacterProfile
	if not current_profile:
		push_error("Failed to load profile from " + path)
		return
	
	current_path = path
	_load_profile_to_ui()
	# Reveal content after file load completes
	scroll_container.visible = true

func _on_save_pressed():
	# Save to editor store, overwrite if existing in editor repo; otherwise create new
	var editor_dir := CardRepository.get_repo_dir(CardRepository.StoreKind.EDITOR)
	if current_path != "" and current_path.begins_with(editor_dir):
		_save_to_path(current_path)
		return
	# No current editor path: insert into repo to get a path, then overwrite to ensure latest content
	var ensured := CardRepository.add_card_to_repo(current_profile, CardRepository.StoreKind.EDITOR)
	if ensured == "":
		push_error("Failed to determine save path in editor repository")
		return
	_save_to_path(ensured)

func _on_export_pressed():
	# Suggest .scrd file name based on card name
	if current_profile and current_profile.name != "":
		var suggested_name = current_profile.name.to_lower().replace(" ", "_")
		export_file_dialog.current_file = suggested_name + ".scrd"
	export_file_dialog.popup_centered_ratio(0.75)

func _on_export_file_selected(path: String):
	var out_path := path
	if not out_path.to_lower().ends_with(".scrd"):
		out_path += ".scrd"
	if _export_to_path(out_path):
		print("Card exported to: " + out_path)

func _on_close_pressed():
	closed.emit()
	visible = false
	# Hide content so next open starts hidden
	scroll_container.visible = false
	_set_advanced_visible(false)

func _set_advanced_visible(show_advanced: bool) -> void:
	advanced_visible = show_advanced
	advanced_sections.visible = show_advanced
	var label_text = "Hide Advanced" if show_advanced else "Show Advanced"
	advanced_toggle_button.text = label_text
	advanced_button.text = "Hide Advanced" if show_advanced else "Advanced"

func _on_advanced_toggle_pressed():
	_set_advanced_visible(not advanced_visible)

func _on_start_chat_pressed():
	chat_window.clear_chat()
	chat_window.show_typing("npc", current_profile.name)
	var greet := _select_greeting()
	chat_window.add_message(greet, "npc", current_profile.name)
	chat_window.hide_typing()
	# Prepare/refresh minimal sandbox context and seed history with greeting
	_ensure_chat_sandbox()
	if _sandbox_world:
		_sandbox_world.history.clear()
		if greet != "":
			_sandbox_world.add_history_entry({
				"event": "narration",
				"style": "npc",
				"speaker": _sandbox_npc_id,
				"text": greet
			})
			_sandbox_world.flags["last_npc_speaker"] = _sandbox_npc_id
			_sandbox_world.flags["last_npc_line"] = greet

func _on_chat_message_sent(chat_text: String):
	chat_window.show_typing("npc", current_profile.name)
	_ensure_chat_sandbox()
	# Record player's line into sandbox history for prompt context
	if _sandbox_world:
		_sandbox_world.add_history_entry({
			"event": "player_text",
			"style": "player",
			"speaker": "player",
			"text": chat_text
		})
		_sandbox_world.flags["last_player_line"] = chat_text

	# Build an NPC prompt from the current card, chat history, and a minimal scene
	var action := ActionRequest.new()
	action.actor = "player"
	action.verb = "talk"
	action.target = _sandbox_npc_id
	action.scene = _sandbox_scene.scene_id if _sandbox_scene else "sandbox"
	action.context = {"utterance": chat_text}

	var messages: Array[Dictionary] = _prompt_engine.build_npc_prompt(action, _sandbox_scene, current_profile)
	var response_text: String = await _prompt_engine._make_llm_request(messages, _prompt_engine._resolution_envelope_schema(), {"source": "npc", "npc_id": action.target})
	if response_text != "":
		var envelope: ResolutionEnvelope = _prompt_engine._parse_response(response_text)
		if envelope.narration.size() > 0:
			# Ensure style/speaker for display and history
			envelope.narration[0].style = "npc"
			envelope.narration[0].speaker = action.target
			chat_window.add_message(envelope.narration[0].text, "npc", current_profile.name)
			# Record NPC line into sandbox history
			if _sandbox_world:
				_sandbox_world.add_history_entry({
					"event": "narration",
					"style": "npc",
					"speaker": action.target,
					"text": envelope.narration[0].text
				})
				_sandbox_world.flags["last_npc_speaker"] = action.target
				_sandbox_world.flags["last_npc_line"] = envelope.narration[0].text
	chat_window.hide_typing()

func _ensure_chat_sandbox() -> void:
	if _prompt_engine != null and _sandbox_scene != null and _sandbox_world != null and llm_client != null:
		return
	# Create a tiny world DB for chat snapshotting
	_sandbox_world = WorldDB.new()
	_sandbox_world.flags["current_scene"] = "card_editor_sandbox"
	var PromptEngineScript = load("res://llm/PromptEngine.gd")
	_prompt_engine = PromptEngineScript.new(llm_client, _sandbox_world)
	# Build a minimal scene with a single NPC entity derived from the card name
	_sandbox_scene = SceneGraph.new()
	_sandbox_scene.scene_id = "card_editor_sandbox"
	_sandbox_scene.description = "Ad-hoc chat sandbox"
	var npc := Entity.new()
	_sandbox_npc_id = (current_profile.name.to_lower().replace(" ", "_") if current_profile and current_profile.name != "" else "npc")
	npc.id = _sandbox_npc_id
	npc.type_name = "npc"
	_sandbox_scene.entities = [npc]

func _select_greeting() -> String:
	if current_profile == null:
		return ""
	var all_greetings: Array[String] = []
	if typeof(current_profile.first_mes) == TYPE_STRING and current_profile.first_mes.strip_edges() != "":
		all_greetings.append(current_profile.first_mes)
	for g in current_profile.alternate_greetings:
		var gg := str(g)
		if gg.strip_edges() != "":
			all_greetings.append(gg)
	if all_greetings.is_empty():
		return ""
	# Cycle selection across starts to emulate ST swipe behavior
	if _greeting_index >= all_greetings.size():
		_greeting_index = 0
	var picked := all_greetings[_greeting_index]
	_greeting_index = (_greeting_index + 1) % all_greetings.size()
	return picked

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

# Card list management
func _refresh_card_list():
	card_list.clear()
	editor_cards.clear()
	
	var paths := CardRepository.list_card_paths(CardRepository.StoreKind.EDITOR)
	for path in paths:
		var profile := load(path) as CharacterProfile
		if profile:
			editor_cards.append({"path": path, "profile": profile})
			var display_name := profile.name if profile.name != "" else path.get_file().get_basename()
			display_name += " - " + profile.character_version if profile.character_version != "" else ""
			card_list.add_item(display_name)

func _on_card_list_item_selected(index: int):
	if index < 0 or index >= editor_cards.size():
		return
	
	var entry: Dictionary = editor_cards[index]
	var profile: CharacterProfile = entry.profile
	var path: String = entry.path
	
	# Load the selected card into the editor
	current_profile = profile
	current_path = path
	_load_profile_to_ui()
	scroll_container.visible = true

func _on_delete_button_pressed():
	var selected_indices := card_list.get_selected_items()
	if selected_indices.is_empty():
		return
	
	var index := selected_indices[0]
	if index < 0 or index >= editor_cards.size():
		return
	
	var entry: Dictionary = editor_cards[index]
	var path: String = entry.path
	
	# Delete file from disk
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(path)
		if err != OK:
			push_error("Failed to delete card file: " + path)
			return
	
	# Clear editor if this was the current card
	if current_path == path:
		current_profile = null
		current_path = ""
		scroll_container.visible = false
	
	# Refresh list
	_refresh_card_list()
