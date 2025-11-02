extends Control

@onready var tab_container: TabContainer = $Margin/VBox/Tabs
@onready var dashboard: Node = $Margin/VBox/Tabs/Dashboard
@onready var scenes: Node = $Margin/VBox/Tabs/Scenes
@onready var graph: Node = $Margin/VBox/Tabs/Graph
@onready var characters: Node = $Margin/VBox/Tabs/Characters

signal closed()
signal playtest_requested(world_db: WorldDB)

var current_world_db: WorldDB = null
var validator: CampaignValidator = CampaignValidator.new()
var exporter: WorldExporter = null

func _ready():
	# Instantiate exporter (needs to be a Node for file operations)
	exporter = WorldExporter.new()
	add_child(exporter)
	# Forward dashboard playtest signal to studio consumers
	if dashboard and dashboard.has_signal("playtest_requested"):
		dashboard.playtest_requested.connect(func(db: WorldDB): playtest_requested.emit(db))

func show_studio():
	visible = true

func hide_studio():
	visible = false
	closed.emit()

## Open the studio with a specific world database
func open_with_world(world_db: WorldDB) -> void:
	current_world_db = world_db
	# Propagate world db to child views
	if dashboard:
		dashboard.current_world_db = world_db
	if scenes:
		scenes.current_world_db = world_db
	if graph:
		graph.current_world_db = world_db
	if characters:
		characters.current_world_db = world_db

	# Share exporter with dashboard for packaging actions
	if dashboard:
		dashboard.exporter = exporter

	# Refresh child views
	if dashboard and dashboard.has_method("_refresh_dashboard"):
		dashboard._refresh_dashboard()
	if scenes and scenes.has_method("_refresh_scenes_list"):
		scenes._refresh_scenes_list()
	if graph and graph.has_method("_load_links_data"):
		graph._load_links_data()
	if graph and graph.has_method("_rebuild_graph"):
		graph._rebuild_graph()
	if characters and characters.has_method("refresh_characters_list"):
		characters.refresh_characters_list()
	show_studio()

## ========================================
## UTILITIES
## ========================================

func _parse_comma_list(text: String) -> Array[String]:
	var result: Array[String] = []
	var parts := text.split(",")
	for part in parts:
		var trimmed := part.strip_edges()
		if not trimmed.is_empty():
			result.append(trimmed)
	return result
