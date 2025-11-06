extends Node
class_name Game

## Main game bootstrap and run loop

@onready var chat_window: ChatWindow = $GameUI/game_container/main_game/center_panel/ChatWindow
@onready var choice_panel: ChoicePanel = $GameUI/game_container/main_game/center_panel/ChoicePanel
@onready var lore_panel: LorePanel = $GameUI/LorePanel
@onready var settings_panel: SettingsPanel = $GameUI/SettingsPanel
@onready var settings_button: Button = $GameUI/game_container/header/HBoxContainer/button_group/settings_button
@onready var inventory_panel: PlayerInventoryPanel = $GameUI/game_container/main_game/InventoryPanel
@onready var npc_panel: NPCPanel = $GameUI/game_container/main_game/right_panel/NPCInventoryPanel
#@onready var action_queue_panel: ActionQueuePanel = $UI/ActionQueuePanel
@onready var card_editor: CardEditor = $GameUI/CardEditor
@onready var editor_button: Button = $GameUI/game_container/header/HBoxContainer/button_group/editor_button
@onready var card_manager: CardManager = $GameUI/CardManager
@onready var cards_button: Button = $GameUI/game_container/header/HBoxContainer/button_group/cards_button
@onready var saveload_button: Button = $GameUI/game_container/header/HBoxContainer/button_group/saveload_button
@onready var save_load_panel: Control = $GameUI/SaveLoadPanel
@onready var campaign_browser: Control = $GameUI/CampaignBrowser
@onready var campaign_detail: Control = $GameUI/CampaignDetail
@onready var campaigns_button: Button = $GameUI/game_container/header/HBoxContainer/button_group/campaigns_button
@onready var studio_button: Button = $GameUI/game_container/header/HBoxContainer/button_group/studio_button
@onready var lore_button: Button = $GameUI/game_container/header/HBoxContainer/button_group/lore_button
@onready var campaign_studio: Control = $GameUI/CampaignStudio
@onready var campaign_picker: Window = $GameUI/CampaignPicker
@onready var clipboard_button: Button = %clipboard_button

var llm_settings: LLMSettings
var llm_client: LLMClient
var prompt_engine: PromptEngine
var world_db: WorldDB
var director: Node
var autosave_timer: Timer
var autosave_interval: float = 300.0  # 5 minutes
var clipboard_manager: ClipboardManager

func _enter_tree():
	# Ensure the user's card repository is initialized with builtin cards
	CardRepository.sync_builtin_cards_to_repo(CardRepository.StoreKind.PLAYER)

func _ready():
	# Load or create LLM settings
	_load_settings()
	
	# Initialize world DB
	world_db = load("res://data/world_state.tres") as WorldDB
	if not world_db:
		push_error("Failed to load world state")
		return
	# Ensure player entity exists for inventory/ownership
	world_db.ensure_player_entity()
	# Ensure player inventory exists (Phase 2)
	world_db.ensure_player_inventory()
	# Ensure lore database is initialized for UI/editor features
	world_db.ensure_lore_database()
	
	# Initialize LLM client (must be a Node in the scene tree)
	llm_client = LLMClient.new(llm_settings)
	add_child(llm_client)
	llm_client.request_started.connect(_on_llm_request_started)
	llm_client.request_finished.connect(_on_llm_request_finished)
	
	# Initialize prompt engine
	prompt_engine = PromptEngine.new(llm_client, world_db)
	
	# Initialize director
	var director_script = load("res://llm/Director.gd")
	director = director_script.new(prompt_engine, world_db)
	add_child(director)
	director.action_resolved.connect(_on_action_resolved)
	#director.action_queue_updated.connect(_on_action_queue_updated)
	
	# Connect UI signals
	chat_window.entity_clicked.connect(_on_entity_clicked)
	chat_window.message_sent.connect(_on_message_sent)
	choice_panel.action_selected.connect(_on_action_selected)
	# Bind inventory panel to player inventory (Phase 2)
	inventory_panel.set_inventory(world_db.player_inventory)
	# Bind NPC panel to world DB
	npc_panel.set_world_db(world_db)
	lore_panel.set_world_db(world_db)
	# Provide world context to chat window for asset resolution
	chat_window.set_world_db(world_db)
	world_db.lore_entry_unlocked.connect(_on_lore_entry_unlocked)
	settings_panel.settings_saved.connect(_on_settings_saved)
	settings_button.pressed.connect(_on_settings_button_pressed)
	card_editor.closed.connect(_on_card_editor_closed)
	if editor_button:
		editor_button.pressed.connect(_on_editor_button_pressed)
	card_manager.closed.connect(_on_card_manager_closed)
	if cards_button:
		cards_button.pressed.connect(_on_cards_button_pressed)
	if saveload_button:
		saveload_button.pressed.connect(_on_saveload_button_pressed)
	if campaigns_button:
		campaigns_button.pressed.connect(_on_campaigns_button_pressed)
	if studio_button:
		studio_button.pressed.connect(_on_studio_button_pressed)
	if lore_button:
		lore_button.pressed.connect(_on_lore_button_pressed)
	
	# Setup autosave
	_setup_autosave()
	
	# Install browser clipboard bridge for Web builds
	if OS.has_feature("web"):
		clipboard_manager = load("res://ui/ClipboardManager.tscn").instantiate()
		add_child(clipboard_manager)
		clipboard_button.visible = true
		clipboard_button.pressed.connect(_on_clipboard_button_pressed)
	
	# set up card editor
	card_editor.llm_client = llm_client

	# Start the game
	_start_game()

	# Initialize Save/Load panel context
	if save_load_panel:
		save_load_panel.set_context(world_db.flags.get("cartridge_id", "default"))
		save_load_panel.save_requested.connect(_on_save_requested)
		save_load_panel.load_requested.connect(_on_load_requested)

	# Hook up campaign browser/detail
	if campaign_browser:
		campaign_browser.campaign_selected.connect(_on_campaign_selected)
	if campaign_detail:
		campaign_detail.start_new_game.connect(_on_campaign_new_game)
		campaign_detail.load_slot_requested.connect(_on_campaign_load_slot)
	if campaign_studio:
		campaign_studio.closed.connect(_on_campaign_studio_closed)
		campaign_studio.playtest_requested.connect(_on_studio_playtest_requested)
	if campaign_picker:
		campaign_picker.campaign_selected.connect(_on_campaign_picker_selected)
		campaign_picker.cancelled.connect(_on_campaign_picker_cancelled)

func _load_settings():
	var defaults_path = "res://llm/settings.tres"
	llm_settings = null
	if ResourceLoader.exists(defaults_path):
		llm_settings = load(defaults_path) as LLMSettings
	
	if not llm_settings:
		# In exports, res:// is read-only; fall back to in-memory defaults
		llm_settings = LLMSettings.new()
	
	# Overlay user overrides from persistent storage (works on Web via IndexedDB)
	var cfg := ConfigFile.new()
	var cfg_err := cfg.load("user://llm_settings.cfg")
	if cfg_err == OK:
		var provider := str(cfg.get_value("llm", "provider", llm_settings.provider))
		llm_settings.set_provider(provider)
		var api_base := str(cfg.get_value("llm", "api_base_url", llm_settings.api_base_url))
		# Allow overriding API URL for any provider (not only "custom")
		llm_settings.api_base_url = api_base
		llm_settings.api_key = str(cfg.get_value("llm", "api_key", llm_settings.api_key))
		llm_settings.model = str(cfg.get_value("llm", "model", llm_settings.model))
		llm_settings.debug_trace = bool(cfg.get_value("llm", "debug_trace", llm_settings.debug_trace))
		llm_settings.supports_vision = bool(cfg.get_value("llm", "supports_vision", llm_settings.supports_vision))
	
	settings_panel.load_settings(llm_settings)

func _start_game():
	chat_window.clear_chat()
	chat_window.add_message("Welcome to Substrate.", "world")
	
	# Enter initial scene (display via action_resolved)
	await director.enter_scene("tavern_common")

func _display_envelope(envelope: ResolutionEnvelope):
	# Display narration
	# Show scene image first if provided
	if envelope.scene_image_path != "":
		chat_window.add_image_from_path(envelope.scene_image_path)
	var narration_current_scene_id = world_db.flags.get("current_scene", "")
	var narration_current_scene = world_db.get_scene(narration_current_scene_id)
	for narr in envelope.narration:
		# Naively auto-tag scene entity IDs in narration so ChatWindow can link them
		var tagged_text = narr.text
		if narration_current_scene:
			var entity_ids: Array[String] = []
			for e in narration_current_scene.entities:
				entity_ids.append(e.id)
			tagged_text = Narrator.auto_tag_entities(narr.text, entity_ids)
		chat_window.add_message(tagged_text, narr.style, narr.speaker)
		# Record narration into world history and recency flags for freeform inference
		world_db.add_history_entry({
			"event": "narration",
			"style": narr.style,
			"speaker": narr.speaker,
			"text": narr.text
		})
		if narr.style == "npc":
			world_db.flags["last_npc_speaker"] = narr.speaker
			world_db.flags["last_npc_line"] = narr.text
	
	# Update choice panel
	choice_panel.set_choices(envelope.ui_choices)
	# Update chat address options with entities that support the talk verb
	_update_chat_address_options()
	# Refresh inventory panel to reflect any item transfers
	inventory_panel.refresh()
	# Refresh NPC panel (tabs and selection detail)
	npc_panel.refresh()

func _on_action_selected(verb: String, target: String):
	# Fail early for take if inventory cannot accept
	if verb == "take":
		var scene_id = world_db.flags.get("current_scene", "")
		var scene = world_db.get_scene(scene_id)
		if scene:
			var entity = scene.get_entity(target)
			if entity:
				world_db.ensure_player_inventory()
				var def = _resolve_item_def_for_entity(entity)
				if def != null:
					var stack := ItemStack.new()
					stack.item = def
					stack.quantity = 1
					if world_db.player_inventory and not world_db.player_inventory.can_accept(stack):
						chat_window.add_message("Your pack is full. You can't carry the [" + entity.id + "] right now.", "world")
						return
	
	var action = ActionRequest.new()
	action.actor = "player"
	action.verb = verb
	action.target = target
	action.scene = world_db.flags.get("current_scene", "")
	# Let Director emit action_resolved; we handle display in _on_action_resolved
	await director.process_player_action(action)

## Map a scene entity to an ItemDef for inventory checks (kept in sync with Director)
func _resolve_item_def_for_entity(entity: Entity) -> ItemDef:
	if entity == null:
		return null
	var def := ItemDef.new()
	def.id = entity.id
	def.display_name = entity.props.get("display_name", entity.id.capitalize())
	def.description = entity.props.get("description", "")
	def.weight_kg = float(entity.props.get("weight_kg", 0.5))
	def.max_stack = int(entity.props.get("max_stack", 1))
	return def

func _on_message_sent(text: String):
	# Track the player's raw text for freeform inference
	world_db.flags["last_player_line"] = text
	world_db.add_history_entry({
		"event": "player_text",
		"text": text
	})
	# If the user addressed a specific entity, route as a talk action
	var addressed_target = chat_window.get_selected_address()
	if addressed_target != "":
		var action = ActionRequest.new()
		action.actor = "player"
		action.verb = "talk"
		action.target = addressed_target
		action.scene = world_db.flags.get("current_scene", "")
		action.context = {"utterance": text}
		await director.process_player_action(action)
		return
	
	# No address: let Director interpret freeform input and resolve it
	await director.process_freeform_player_input(text)
	return

func _update_chat_address_options():
	var scene = world_db.get_scene(world_db.flags.get("current_scene", ""))
	if not scene:
		chat_window.set_address_options([])
		return
	var talkables: Array[String] = []
	for entity in scene.entities:
		if "talk" in entity.verbs:
			talkables.append(entity.id)
	chat_window.set_address_options(talkables)

func _on_entity_clicked(entity_id: String):
	var target_id := entity_id
	if entity_id.begins_with("lore:"):
		target_id = entity_id.substr(5)
	# Clicking an entity or lore link should count as discovery before opening
	if world_db and target_id != "":
		world_db.record_entity_discovery(target_id, "player", world_db.flags.get("current_scene", ""))
	if world_db:
		var lore_entry := world_db.get_lore_entry(target_id)
		if lore_entry:
			lore_panel.show_lore_entry(target_id)
			return
	if entity_id.begins_with("lore:"):
		# Lore link without backing entry; bail quietly.
		return
	lore_panel.show_entity(target_id)

func _on_action_resolved(envelope: ResolutionEnvelope):
	_display_envelope(envelope)

func _on_settings_button_pressed():
	settings_panel.visible = true

#func _on_action_queue_updated(queue_preview: Array[String], current_actor: String):
	#action_queue_panel.update_queue(queue_preview, current_actor)

func _on_settings_saved():
	# Reload LLM client with new settings
	if llm_client:
		llm_client.queue_free()
	llm_client = LLMClient.new(llm_settings)
	add_child(llm_client)
	prompt_engine.llm_client = llm_client
	llm_client.request_started.connect(_on_llm_request_started)
	llm_client.request_finished.connect(_on_llm_request_finished)
	chat_window.add_message("Settings saved and applied.", "world")

func _on_llm_request_started(meta: Dictionary):
	var source := str(meta.get("source", ""))
	var name_hint := ""
	if source == "npc":
		var candidate_id := str(meta.get("npc_id", meta.get("npc_hint", "")))
		if candidate_id != "":
			var profile = world_db.get_character(candidate_id)
			if profile and profile.name != "":
				name_hint = profile.name
			else:
				name_hint = candidate_id
	chat_window.show_typing(source, name_hint)

func _on_llm_request_finished(_meta: Dictionary):
	chat_window.hide_typing()

func _on_lore_entry_unlocked(entry_id: String):
	var entry := world_db.get_lore_entry(entry_id) if world_db else null
	if entry:
		var title := entry.title if entry.title != "" else entry.entry_id
		chat_window.add_message("New lore unlocked: [url=lore:" + entry_id + "]" + title + "[/url]", "world")
	else:
		chat_window.add_message("New lore unlocked: [url=lore:" + entry_id + "]" + entry_id + "[/url]", "world")

func _setup_autosave():
	autosave_timer = Timer.new()
	autosave_timer.wait_time = autosave_interval
	autosave_timer.timeout.connect(_on_autosave_timer)
	autosave_timer.autostart = true
	add_child(autosave_timer)

func _on_autosave_timer():
	if world_db:
		world_db.autosave()
		print("Autosave completed")

func switch_cartridge(file_path: String, slot: String = "") -> void:
	# Auto-save current session to last_played slot
	var cid := str(world_db.flags.get("cartridge_id", "default"))
	var last_slot := "last_played"
	var dir := "user://saves/%s" % cid
	DirAccess.make_dir_recursive_absolute(dir)
	world_db.save_to_file("%s/%s.tres" % [dir, last_slot])
	var last_meta := {
		"scene": world_db.flags.get("current_scene", world_db.flags.get("initial_scene_id", "")),
		"timestamp": Time.get_datetime_string_from_system()
	}
	var f := FileAccess.open("%s/%s.json" % [dir, last_slot], FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(last_meta, "  "))
		f.close()

	# Import and load the new cartridge
	var new_id := CartridgeManagerTool.import_cartridge(file_path, CartridgeManager.StoreKind.PLAYER)
	if new_id == "":
		chat_window.add_message("Failed to import cartridge.", "world")
		return
	var new_world: WorldDB = CartridgeManagerTool.build_world_db_from_import(new_id, CartridgeManager.StoreKind.PLAYER)
	if new_world == null:
		chat_window.add_message("Failed to load cartridge world.", "world")
		return
	_apply_world_db(new_world)
	# Load requested slot if provided
	if slot != "":
		var sp := "user://saves/%s/%s.tres" % [new_id, slot]
		if FileAccess.file_exists(sp):
			var loaded: WorldDB = WorldDB.load_from_file(sp)
			if loaded:
				_apply_world_db(loaded)
	# Enter initial or current scene
	var sid: String = str(world_db.flags.get("current_scene", world_db.flags.get("initial_scene_id", "tavern_common")))
	await director.enter_scene(sid)
	chat_window.add_message("Switched to cartridge '%s'." % new_id, "world")

func _on_editor_button_pressed():
	# Hide main game UI
	var game_container = $GameUI/game_container
	game_container.visible = false
	lore_panel.visible = false
	settings_panel.visible = false
	
	# Show editor
	card_editor.visible = true

func _on_card_editor_closed():
	# Show main game UI
	var game_container = $GameUI/game_container
	game_container.visible = true
	
	# Hide editor
	card_editor.visible = false

func _on_cards_button_pressed():
	# Hide main game UI
	var game_container = $GameUI/game_container
	game_container.visible = false
	lore_panel.visible = false
	settings_panel.visible = false
	card_editor.visible = false
	
	# Show card manager
	card_manager.visible = true

func _on_saveload_button_pressed():
	# Hide other overlays
	settings_panel.visible = false
	card_editor.visible = false
	card_manager.visible = false
	# Show panel with current cartridge context
	if save_load_panel:
		save_load_panel.set_context(world_db.flags.get("cartridge_id", "default"))
		save_load_panel.visible = true

func _on_campaigns_button_pressed():
	# Hide other overlays
	settings_panel.visible = false
	card_editor.visible = false
	card_manager.visible = false
	save_load_panel.visible = false
	campaign_detail.visible = false
	# Show browser
	if campaign_browser:
		campaign_browser.visible = true

func _on_campaign_selected(cart, file_path: String):
	# Open detail view for selected cartridge
	campaign_browser.visible = false
	if campaign_detail:
		campaign_detail.set_cartridge(cart, file_path)
		campaign_detail.visible = true

func _on_campaign_new_game(_cart, file_path: String):
	campaign_detail.visible = false
	await switch_cartridge(file_path, "")

func _on_campaign_load_slot(_cart, slot: String, file_path: String):
	campaign_detail.visible = false
	await switch_cartridge(file_path, slot)

func _on_save_requested(slot: String):
	var cid := str(world_db.flags.get("cartridge_id", "default"))
	var dir := "user://saves/%s" % cid
	var fname := "%s.tres" % slot
	var path := "%s/%s" % [dir, fname]
	# Ensure directory
	var d := DirAccess.open("user://")
	if d and not d.dir_exists(dir):
		d.make_dir_recursive(dir)
	# Save world
	var ok: bool = world_db.save_to_file(path)
	if ok:
		# Write sidecar metadata
		var meta := {
			"scene": world_db.flags.get("current_scene", world_db.flags.get("initial_scene_id", "")),
			"timestamp": Time.get_datetime_string_from_system()
		}
		var mpath := "%s/%s.json" % [dir, slot]
		var f := FileAccess.open(mpath, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(meta, "  "))
			f.close()
		chat_window.add_message("Game saved to slot '%s'." % slot, "world")
		save_load_panel.refresh_slots()

func _on_load_requested(slot: String):
	var cid := str(world_db.flags.get("cartridge_id", "default"))
	var path := "user://saves/%s/%s.tres" % [cid, slot]
	if not FileAccess.file_exists(path):
		chat_window.add_message("Save slot not found: %s" % slot, "world")
		return
	var new_world: WorldDB = WorldDB.load_from_file(path)
	if new_world == null:
		chat_window.add_message("Failed to load slot '%s'." % slot, "world")
		return
	_apply_world_db(new_world)
	# Enter the saved or initial scene (display via action_resolved)
	var sid: String = str(new_world.flags.get("current_scene", new_world.flags.get("initial_scene_id", "tavern_common")))
	await director.enter_scene(sid)
	chat_window.add_message("Loaded slot '%s'." % slot, "world")
	save_load_panel.visible = false

func _apply_world_db(new_world: WorldDB):
	# Replace references and rebind UI
	world_db = new_world
	# Ensure essentials
	world_db.ensure_player_entity()
	world_db.ensure_player_inventory()
	# Rebind UI panels
	inventory_panel.set_inventory(world_db.player_inventory)
	npc_panel.set_world_db(world_db)
	lore_panel.set_world_db(world_db)
	# Rebuild prompt engine and director
	prompt_engine.world_db = world_db
	if director:
		director.queue_free()
	var director_script = load("res://llm/Director.gd")
	director = director_script.new(prompt_engine, world_db)
	add_child(director)
	director.action_resolved.connect(_on_action_resolved)

func _on_card_manager_closed():
	# Show main game UI
	var game_container = $GameUI/game_container
	game_container.visible = true
	
	# Hide card manager
	card_manager.visible = false

func _on_studio_button_pressed():
	# Show campaign picker instead of directly opening studio
	if campaign_picker:
		campaign_picker.show_picker()

func _on_campaign_studio_closed():
	# Show main game UI
	var game_container = $GameUI/game_container
	game_container.visible = true
	# Hide studio
	if campaign_studio:
		campaign_studio.visible = false

func _on_studio_playtest_requested(test_world_db: WorldDB):
	# Close the studio
	_on_campaign_studio_closed()
	# Start with a clean chat log for the playtest session
	chat_window.clear_chat()
	# Apply the test world and enter its start scene
	if test_world_db == null:
		return
	_apply_world_db(test_world_db)
	# Determine starting scene (current -> initial -> fallback)
	var sid: String = str(world_db.flags.get("current_scene", world_db.flags.get("initial_scene_id", "tavern_common")))
	await director.enter_scene(sid)
	chat_window.add_message("Playtesting campaign '%s'." % world_db.flags.get("campaign_name", "unnamed"), "world")

func _on_campaign_picker_selected(cart_path: String, loaded_world: WorldDB):
	# Hide main game UI
	var game_container = $GameUI/game_container
	game_container.visible = false
	lore_panel.visible = false
	settings_panel.visible = false
	card_editor.visible = false
	card_manager.visible = false
	save_load_panel.visible = false
	campaign_browser.visible = false
	campaign_detail.visible = false
	
	# Open studio with the selected/new campaign
	if campaign_studio:
		campaign_studio.open_with_world(loaded_world, cart_path)

func _on_campaign_picker_cancelled():
	# User cancelled the picker, do nothing
	pass

func _on_clipboard_button_pressed():
	# Show clipboard manager
	if clipboard_manager:
		clipboard_manager.visible = true

func _on_lore_button_pressed():
	# Hide other overlays
	settings_panel.visible = false
	card_editor.visible = false
	card_manager.visible = false
	save_load_panel.visible = false
	campaign_browser.visible = false
	campaign_detail.visible = false
	# Open lore codex
	if lore_panel:
		lore_panel.open_codex()

func _notification(what):
	# Save on exit
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if world_db:
			world_db.autosave()
		get_tree().quit()
