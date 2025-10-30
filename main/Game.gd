extends Node
class_name Game

## Main game bootstrap and run loop

@onready var chat_window: ChatWindow = $UI/MainSplit/ChatWindow
@onready var choice_panel: ChoicePanel = $UI/MainSplit/ChoicePanel
@onready var lore_panel: LorePanel = $UI/LorePanel
@onready var settings_panel: SettingsPanel = $UI/SettingsPanel
@onready var settings_button: Button = $UI/SettingsButton
@onready var action_queue_panel: ActionQueuePanel = $UI/ActionQueuePanel

var llm_settings: LLMSettings
var llm_client: LLMClient
var prompt_engine: PromptEngine
var world_db: WorldDB
var director: Director

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
		chat_window.add_message(narr.text, narr.style, narr.speaker)
	
	# Update choice panel
	choice_panel.set_choices(envelope.ui_choices)

func _on_action_selected(verb: String, target: String):
	var action = ActionRequest.new()
	action.actor = "player"
	action.verb = verb
	action.target = target
	action.scene = world_db.flags.get("current_scene", "")
	
	var envelope = await director.process_player_action(action)
	_display_envelope(envelope)

func _on_message_sent(text: String):
	# For MVP, parse simple commands like "cover me" -> supportive action
	if text.to_lower().contains("cover"):
		var action = ActionRequest.new()
		action.actor = "archer"
		action.verb = "cover"
		action.target = "player"
		action.scene = world_db.flags.get("current_scene", "")
		action.context = {"command": "cover_me"}
		
		var envelope = await director.process_companion_action("archer", "cover", "player", "The archer steps back, bow drawn, eyes scanning for threats.")
		_display_envelope(envelope)
	else:
		# Just acknowledge chat messages for now
		chat_window.add_message("(Chat not yet fully implemented - use action buttons)", "world")

func _on_entity_clicked(entity_id: String):
	lore_panel.show_entity(entity_id)

func _on_action_resolved(_envelope: ResolutionEnvelope):
	# Additional handling if needed
	pass

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
