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
	
	# Update choice panel
	choice_panel.set_choices(envelope.ui_choices)

func _on_action_selected(verb: String, target: String):
	var action = ActionRequest.new()
	action.actor = "player"
	action.verb = verb
	action.target = target
	action.scene = world_db.flags.get("current_scene", "")
	# Let Director emit action_resolved; we handle display in _on_action_resolved
	await director.process_player_action(action)

func _on_message_sent(text: String):
	# Parse simple commands and emit player.command.* events
	var command = text.to_lower().strip_edges()
	
	if command.contains("cover"):
		# Emit player.command.cover_me event
		var scene = world_db.get_scene(world_db.flags.get("current_scene", ""))
		if scene:
			var npc_entities = scene.get_entities_by_type("npc")
			for npc_entity in npc_entities:
				var character = world_db.get_character(npc_entity.id)
				if character:
					var context = {
						"scene_id": world_db.flags.get("current_scene", ""),
						"world": {"flags": world_db.flags},
						"scene": {"id": scene.scene_id}
					}
					var trigger = director.companion_ai.should_act(npc_entity.id, "player.command.cover_me", "global", context)
					if trigger:
						# Execute trigger action
						var action = ActionRequest.new()
						action.actor = npc_entity.id
						action.verb = trigger.get_verb()
						action.target = trigger.get_target()
						action.scene = world_db.flags.get("current_scene", "")
						
						var envelope = await director.process_player_action(action)
						
						# Override narration if trigger provides it
						if trigger.narration != "" and envelope.narration.size() > 0:
							envelope.narration[0].text = trigger.narration
							envelope.narration[0].speaker = npc_entity.id
						
						_display_envelope(envelope)
						return
		
		# Fallback if no trigger matched
		chat_window.add_message("(No companion available to cover you)", "world")
	else:
		# Just acknowledge chat messages for now
		chat_window.add_message("(Chat not yet fully implemented - use action buttons)", "world")

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

func _notification(what):
	# Save on exit
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if world_db:
			world_db.autosave()
		get_tree().quit()
