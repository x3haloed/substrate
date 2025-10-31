extends Node
class_name Game

## Main game bootstrap and run loop

@onready var chat_window: ChatWindow = $UI/MainSplit/ChatWindow
@onready var choice_panel: ChoicePanel = $UI/MainSplit/ChoicePanel
@onready var lore_panel: LorePanel = $UI/LorePanel
@onready var settings_panel: SettingsPanel = $UI/SettingsPanel
@onready var settings_button: Button = $UI/SettingsButton
@onready var action_queue_panel: ActionQueuePanel = $UI/ActionQueuePanel
@onready var card_editor: CardEditor = $UI/CardEditor
@onready var editor_button: Button = $UI/EditorButton

var llm_settings: LLMSettings
var llm_client: LLMClient
var prompt_engine: PromptEngine
var world_db: WorldDB
var director: Director
var autosave_timer: Timer
var autosave_interval: float = 300.0  # 5 minutes

func _ready():
	# Load or create LLM settings
	_load_settings()
	
	# Initialize world DB
	world_db = load("res://data/world_state.tres") as WorldDB
	if not world_db:
		push_error("Failed to load world state")
		return
	
	# Initialize LLM client (must be a Node in the scene tree)
	llm_client = LLMClient.new(llm_settings)
	add_child(llm_client)
	
	# Initialize prompt engine
	prompt_engine = PromptEngine.new(llm_client, world_db)
	
	# Initialize director
	director = Director.new(prompt_engine, world_db)
	add_child(director)
	director.action_resolved.connect(_on_action_resolved)
	director.action_queue_updated.connect(_on_action_queue_updated)
	
	# Connect UI signals
	chat_window.entity_clicked.connect(_on_entity_clicked)
	chat_window.message_sent.connect(_on_message_sent)
	choice_panel.action_selected.connect(_on_action_selected)
	lore_panel.set_world_db(world_db)
	settings_panel.settings_saved.connect(_on_settings_saved)
	settings_button.pressed.connect(_on_settings_button_pressed)
	card_editor.closed.connect(_on_card_editor_closed)
	if editor_button:
		editor_button.pressed.connect(_on_editor_button_pressed)
	
	# Setup autosave
	_setup_autosave()
	
	# Start the game
	_start_game()

func _load_settings():
	var settings_path = "res://llm/settings.tres"
	llm_settings = load(settings_path) as LLMSettings
	
	if not llm_settings:
		# Create default settings
		llm_settings = LLMSettings.new()
		llm_settings.provider = "openai"
		llm_settings.model = "gpt-4o-mini"
		ResourceSaver.save(llm_settings, settings_path)
	
	settings_panel.load_settings(llm_settings)

func _start_game():
	chat_window.clear_chat()
	chat_window.add_message("Welcome to Substrate.", "world")
	
	# Enter initial scene
	var envelope = await director.enter_scene("tavern_common")
	_display_envelope(envelope)

func _display_envelope(envelope: ResolutionEnvelope):
	# Display narration
	for narr in envelope.narration:
		# Naively auto-tag scene entity IDs in narration so ChatWindow can link them
		var scene_id = world_db.flags.get("current_scene", "")
		var scene = world_db.get_scene(scene_id)
		var tagged_text = narr.text
		if scene:
			var entity_ids: Array[String] = []
			for e in scene.entities:
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

func _on_action_selected(verb: String, target: String):
	var action = ActionRequest.new()
	action.actor = "player"
	action.verb = verb
	action.target = target
	action.scene = world_db.flags.get("current_scene", "")
	# Let Director emit action_resolved; we handle display in _on_action_resolved
	await director.process_player_action(action)

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
	lore_panel.show_entity(entity_id)

func _on_action_resolved(envelope: ResolutionEnvelope):
	_display_envelope(envelope)

func _on_settings_button_pressed():
	settings_panel.visible = true

func _on_action_queue_updated(queue_preview: Array[String], current_actor: String):
	action_queue_panel.update_queue(queue_preview, current_actor)

func _on_settings_saved():
	# Reload LLM client with new settings
	if llm_client:
		llm_client.queue_free()
	llm_client = LLMClient.new(llm_settings)
	add_child(llm_client)
	prompt_engine.llm_client = llm_client
	chat_window.add_message("Settings saved. Restart to apply changes.", "world")

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

func _on_editor_button_pressed():
	# Hide main game UI
	chat_window.visible = false
	choice_panel.visible = false
	lore_panel.visible = false
	settings_panel.visible = false
	action_queue_panel.visible = false
	settings_button.visible = false
	if editor_button:
		editor_button.visible = false
	
	# Show editor
	card_editor.visible = true

func _on_card_editor_closed():
	# Show main game UI
	chat_window.visible = true
	choice_panel.visible = true
	lore_panel.visible = true
	action_queue_panel.visible = true
	settings_button.visible = true
	if editor_button:
		editor_button.visible = true
	
	# Hide editor
	card_editor.visible = false

func _notification(what):
	# Save on exit
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if world_db:
			world_db.autosave()
		get_tree().quit()
