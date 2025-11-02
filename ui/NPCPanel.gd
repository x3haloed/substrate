extends Control
class_name NPCPanel

## NPC inventory panel bound to current scene NPCs

@onready var npc_tabs: TabBar = $VBox/NPCTabs
@onready var npc_name: Label = $VBox/Header/HBox/VBoxInfo/NPCName
@onready var npc_disposition: Label = $VBox/Header/HBox/VBoxInfo/Disposition
@onready var npc_portrait: TextureRect = $VBox/Header/HBox/Portrait
@onready var item_grid: GridContainer = $VBox/Content/ItemScroll/ItemGrid
@onready var chat_log: RichTextLabel = $VBox/Content/WhisperContent/HBox/ChatVBox/ChatLog
@onready var input_line: LineEdit = $VBox/Content/WhisperContent/HBox/ChatVBox/InputBox/InputLine
@onready var send_button: Button = $VBox/Content/WhisperContent/HBox/ChatVBox/InputBox/SendButton

var world_db: WorldDB
var npc_ids: Array[String] = []
var selected_npc_id: String = ""

func _ready():
	send_button.pressed.connect(_on_send_pressed)
	input_line.text_submitted.connect(_on_input_submitted)
	npc_tabs.tab_selected.connect(_on_tab_selected)
	_refresh_tabs_from_scene()
	_refresh_selected_npc()

func set_world_db(db: WorldDB) -> void:
	world_db = db
	_refresh_tabs_from_scene()
	_refresh_selected_npc()

func refresh() -> void:
	_refresh_tabs_from_scene()
	_refresh_selected_npc()

func _refresh_tabs_from_scene() -> void:
	if world_db == null:
		return
	var scene_id = world_db.flags.get("current_scene", "")
	var scene = world_db.get_scene(scene_id)
	if not scene:
		return
	# Cache old selection
	var prev_id = selected_npc_id
	# Rebuild tabs
	for i in range(npc_tabs.get_tab_count() - 1, -1, -1):
		npc_tabs.remove_tab(i)
	npc_ids.clear()
	var npcs = scene.get_entities_by_type("npc")
	# Only show party NPCs in tabs
	var party_ids: Array[String] = world_db.party if world_db and world_db.party is Array else []
	for e in npcs:
		if not (e.id in party_ids):
			continue
		var label = e.id
		var profile = world_db.get_character(e.id)
		if profile and profile.name != "":
			label = profile.name
		npc_tabs.add_tab(label)
		npc_ids.append(e.id)
	# Restore selection if possible
	if prev_id != "" and prev_id in npc_ids:
		var idx = npc_ids.find(prev_id)
		npc_tabs.current_tab = idx
		selected_npc_id = prev_id
	else:
		selected_npc_id = npc_ids[0] if npc_ids.size() > 0 else ""

func _on_tab_selected(index: int) -> void:
	if index >= 0 and index < npc_ids.size():
		selected_npc_id = npc_ids[index]
		_refresh_selected_npc()

func _refresh_selected_npc() -> void:
	# Clear grid
	for child in item_grid.get_children():
		child.queue_free()
	if world_db == null or selected_npc_id == "":
		npc_name.text = ""
		npc_disposition.text = ""
		npc_portrait.texture = null
		return
	# Header info
	var profile = world_db.get_character(selected_npc_id)
	var display_name = selected_npc_id
	if profile and profile.name != "":
		display_name = profile.name
	npc_name.text = display_name
	# TODO: derive from stats later
	npc_disposition.text = "Disposition: Neutral"
	# Portrait if available
	if profile:
		npc_portrait.texture = profile.get_portrait_texture()
	# Inventory grid from entity.contents for now (Phase 2 of NPCs could use Inventory)
	var scene_id = world_db.flags.get("current_scene", "")
	var scene = world_db.get_scene(scene_id)
	if not scene:
		return
	var entity = scene.get_entity(selected_npc_id)
	if entity and entity.contents is Array:
		for item_id in entity.contents:
			var btn = Button.new()
			btn.text = str(item_id)
			btn.custom_minimum_size = Vector2(60, 60)
			item_grid.add_child(btn)

func _setup_placeholder_chat():
	chat_log.clear()
	# leave empty; will be populated by gameplay later

func _on_send_pressed():
	var text = input_line.text.strip_edges()
	if text != "":
		chat_log.append_text("[You]: " + text + "\n")
		input_line.text = ""

func _on_input_submitted(_text: String):
	_on_send_pressed()
