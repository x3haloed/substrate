extends VBoxContainer

# Graph view references
@onready var graph_edit: GraphEdit = $"GraphEdit"
@onready var tab_container: TabContainer = get_parent() as TabContainer
@onready var scenes_view: Node = get_parent().get_node("Scenes")
@onready var open_area_dialog: Window = $"OpenAreaDialog"
@onready var area_node_id_field: LineEdit = $"OpenAreaDialog/OpenAreaContent/VBox/NodeIdSection/NodeIdField"
@onready var area_label_field: LineEdit = $"OpenAreaDialog/OpenAreaContent/VBox/LabelSection/LabelField"
@onready var area_entry_scene_field: LineEdit = $"OpenAreaDialog/OpenAreaContent/VBox/EntrySceneSection/EntrySceneField"
@onready var area_objective_kind: OptionButton = $"OpenAreaDialog/OpenAreaContent/VBox/ObjectiveSection/ObjectiveKindSection/ObjectiveKindOption"
@onready var area_objective_entity_field: LineEdit = $"OpenAreaDialog/OpenAreaContent/VBox/ObjectiveSection/ObjectiveEntitySection/ObjectiveEntityField"
@onready var area_objective_flag_field: LineEdit = $"OpenAreaDialog/OpenAreaContent/VBox/ObjectiveSection/ObjectiveFlagSection/ObjectiveFlagField"
@onready var area_completion_scene_field: LineEdit = $"OpenAreaDialog/OpenAreaContent/VBox/CompletionSection/CompletionSceneField"

var current_world_db: WorldDB = null

# Graph view state
var links_data: Dictionary = {"nodes": [], "edges": []}
var editing_open_area_node: Dictionary = {}
var editing_open_area_index: int = -1

func _ready():
	# Initialize objective kind dropdown
	area_objective_kind.clear()
	area_objective_kind.add_item("discover_entity", 0)
	area_objective_kind.add_item("interact_entity", 1)
	area_objective_kind.add_item("flag_equals", 2)

## ========================================
## LINK GRAPH VIEW
## ========================================

## Load links.json from world flags or create empty structure
func _load_links_data() -> void:
	if current_world_db == null:
		links_data = {"nodes": [], "edges": []}
		return
	
	# Check if links data is stored in world flags
	var links_json: String = str(current_world_db.flags.get("links_json", ""))
	if not links_json.is_empty():
		var parser := JSON.new()
		var error := parser.parse(links_json)
		if error == OK and parser.data is Dictionary:
			links_data = parser.data
			if not links_data.has("nodes"):
				links_data["nodes"] = []
			if not links_data.has("edges"):
				links_data["edges"] = []
			return
	
	# No links data yet, create empty
	links_data = {"nodes": [], "edges": []}

## Save links data back to world flags
func _save_links_data() -> void:
	if current_world_db == null:
		return
	
	current_world_db.flags["links_json"] = JSON.stringify(links_data, "  ")

## Rebuild the entire graph from scenes and links data
func _rebuild_graph() -> void:
	# Clear existing graph
	graph_edit.clear_connections()
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.queue_free()
	
	if current_world_db == null:
		return
	
	# Build nodes from links_data AND from scenes
	var node_ids_in_links: Dictionary = {}
	
	# First, add nodes from links.json
	for node_def in links_data.get("nodes", []):
		if node_def is Dictionary:
			var node_id: String = str(node_def.get("id", ""))
			if not node_id.is_empty():
				node_ids_in_links[node_id] = true
				_create_graph_node(node_def)
	
	# Then, add scene nodes that aren't in links.json
	for scene_id in current_world_db.scenes.keys():
		if not node_ids_in_links.has(scene_id):
			# Auto-create a scene node
			var node_def := {
				"id": scene_id,
				"type": "scene",
				"scene_id": scene_id
			}
			_create_graph_node(node_def)
	
	# Build edges from links_data
	for edge_def in links_data.get("edges", []):
		if edge_def is Dictionary:
			var from_node: String = str(edge_def.get("from", ""))
			var to_node: String = str(edge_def.get("to", ""))
			if not from_node.is_empty() and not to_node.is_empty():
				# Find ports (for now use port 0)
				graph_edit.connect_node(from_node, 0, to_node, 0)
	
	# Also detect edges from exit entities
	_add_exit_edges_to_graph()

## Add edges derived from exit entities in scenes
func _add_exit_edges_to_graph() -> void:
	if current_world_db == null:
		return
	
	for scene_id in current_world_db.scenes.keys():
		var scene_data = current_world_db.scenes[scene_id]
		var scene: SceneGraph = null
		
		if scene_data is String:
			scene = load(scene_data) as SceneGraph
		elif scene_data is SceneGraph:
			scene = scene_data
		
		if scene == null:
			continue
		
		# Find exit entities
		for entity in scene.entities:
			if entity.type_name == "exit":
				var leads_to: String = str(entity.props.get("leads", ""))
				if not leads_to.is_empty():
					# Check if this edge already exists in links_data
					var edge_exists := false
					for edge_def in links_data.get("edges", []):
						if edge_def is Dictionary:
							if str(edge_def.get("from", "")) == scene_id and str(edge_def.get("to", "")) == leads_to:
								edge_exists = true
								break
					
					# Add edge if both nodes exist and edge doesn't exist
					if not edge_exists and graph_edit.has_node(scene_id) and graph_edit.has_node(leads_to):
						graph_edit.connect_node(scene_id, 0, leads_to, 0)

## Create a GraphNode from a node definition
func _create_graph_node(node_def: Dictionary) -> GraphNode:
	var node_id: String = str(node_def.get("id", ""))
	var node_type: String = str(node_def.get("type", "scene"))
	
	var graph_node := GraphNode.new()
	graph_node.name = node_id
	graph_node.title = node_id
	graph_node.draggable = true
	graph_node.selectable = true
	graph_node.resizable = false
	
	# Set slots for connections
	graph_node.set_slot(0, true, 0, Color.WHITE, true, 0, Color.WHITE)
	
	# Style based on type
	if node_type == "open_area":
		graph_node.title = str(node_def.get("label", node_id))
		# Add visual indicator for open area
		var label := Label.new()
		label.text = "🗺 Open Area"
		label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
		graph_node.add_child(label)
	else:
		# Regular scene node
		var label := Label.new()
		label.text = "📍 Scene"
		graph_node.add_child(label)
	
	# Add to graph
	graph_edit.add_child(graph_node)

	# Handle double-clicks on the node to open its editor without
	# interfering with drag operations
	graph_node.gui_input.connect(_on_graph_node_gui_input.bind(graph_node))
	
	# Position (try to load from node_def or use auto-layout later)
	if node_def.has("position") and node_def.position is Vector2:
		graph_node.position_offset = node_def.position
	else:
		# Random initial position
		graph_node.position_offset = Vector2(randf() * 400, randf() * 300)
	
	return graph_node

## Graph event handlers

func _on_refresh_graph_pressed() -> void:
	_rebuild_graph()

func _on_add_scene_node_pressed() -> void:
	if current_world_db == null:
		return
	
	# Generate unique ID
	var base_id := "node"
	var node_id := base_id
	var counter := 1
	while _node_exists_in_links(node_id):
		node_id = base_id + "_" + str(counter)
		counter += 1
	
	# Create node def
	var node_def := {
		"id": node_id,
		"type": "scene",
		"scene_id": ""
	}
	
	# Add to links
	if not links_data.has("nodes"):
		links_data["nodes"] = []
	links_data["nodes"].append(node_def)
	_save_links_data()
	
	# Rebuild graph
	_rebuild_graph()

func _on_add_open_area_pressed() -> void:
	if current_world_db == null:
		return
	
	# Create new open area with defaults
	editing_open_area_node = {
		"id": "open_area_" + str(randi() % 10000),
		"type": "open_area",
		"label": "New Area",
		"entry_template": {"scene": ""},
		"objective": {"kind": "discover_entity", "entity_id": ""},
		"on_complete": {"goto_scene_id": ""}
	}
	editing_open_area_index = -1
	
	_open_open_area_editor(editing_open_area_node)

func _on_auto_layout_pressed() -> void:
	# Simple force-directed layout
	var nodes := graph_edit.get_children().filter(func(n): return n is GraphNode)
	
	if nodes.size() == 0:
		return
	
	# Arrange in a grid for simplicity
	var cols := int(ceil(sqrt(nodes.size())))
	var spacing := Vector2(250, 200)
	var start_pos := Vector2(50, 50)
	
	for i in range(nodes.size()):
		var node: GraphNode = nodes[i]
		@warning_ignore("integer_division")
		var row := i / cols
		var col := i % cols
		node.position_offset = start_pos + Vector2(col * spacing.x, row * spacing.y)
		
		# Save position to links_data
		_save_node_position(node.name, node.position_offset)
	
	_save_links_data()

func _on_graph_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	# Create edge
	graph_edit.connect_node(from_node, from_port, to_node, to_port)
	
	# Add to links_data
	var edge_def := {
		"from": str(from_node),
		"to": str(to_node),
		"label": ""
	}
	
	if not links_data.has("edges"):
		links_data["edges"] = []
	links_data["edges"].append(edge_def)
	_save_links_data()

func _on_graph_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	# Remove edge
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	
	# Remove from links_data
	var edges: Array = links_data.get("edges", [])
	for i in range(edges.size() - 1, -1, -1):
		var edge_def = edges[i]
		if edge_def is Dictionary:
			if str(edge_def.get("from", "")) == str(from_node) and str(edge_def.get("to", "")) == str(to_node):
				edges.remove_at(i)
				break
	
	_save_links_data()

func _on_graph_node_gui_input(event: InputEvent, node: GraphNode) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click and mb.pressed:
			_open_node_by_id(node.name)

func _open_node_by_id(node_id: String) -> void:
	# Find node in links_data
	var node_def: Dictionary = _find_node_in_links(node_id)
	
	if node_def.is_empty():
		# Not in links, might be auto-generated scene node
		# Open scene editor if scene exists
		if current_world_db.scenes.has(node_id):
			# Switch to Scenes tab and load this scene
			tab_container.current_tab = 1  # Scenes tab
			if scenes_view and scenes_view.has_method("select_scene_by_id"):
				scenes_view.select_scene_by_id(node_id)
		return
	
	# Check type
	var node_type: String = str(node_def.get("type", "scene"))
	if node_type == "open_area":
		# Open open area editor
		editing_open_area_node = node_def
		editing_open_area_index = links_data["nodes"].find(node_def)
		_open_open_area_editor(node_def)
	else:
		# Open scene editor
		var scene_id: String = str(node_def.get("scene_id", node_id))
		if current_world_db.scenes.has(scene_id):
			tab_container.current_tab = 1  # Scenes tab
			if scenes_view and scenes_view.has_method("select_scene_by_id"):
				scenes_view.select_scene_by_id(scene_id)

## ========================================
## OPEN AREA EDITOR DIALOG
## ========================================

func _open_open_area_editor(node_def: Dictionary) -> void:
	# Populate fields
	area_node_id_field.text = str(node_def.get("id", ""))
	area_label_field.text = str(node_def.get("label", ""))
	
	var entry_template: Dictionary = node_def.get("entry_template", {})
	area_entry_scene_field.text = str(entry_template.get("scene", ""))
	
	var objective: Dictionary = node_def.get("objective", {})
	var obj_kind: String = str(objective.get("kind", "discover_entity"))
	
	# Set objective kind dropdown
	var kind_idx := 0
	if obj_kind == "interact_entity":
		kind_idx = 1
	elif obj_kind == "flag_equals":
		kind_idx = 2
	area_objective_kind.selected = kind_idx
	
	area_objective_entity_field.text = str(objective.get("entity_id", ""))
	
	# For flag_equals, format as "flag=value"
	if obj_kind == "flag_equals":
		var flag_key: String = str(objective.get("flag", ""))
		var flag_value: String = str(objective.get("value", ""))
		area_objective_flag_field.text = flag_key + "=" + flag_value
	else:
		area_objective_flag_field.text = ""
	
	var on_complete: Dictionary = node_def.get("on_complete", {})
	area_completion_scene_field.text = str(on_complete.get("goto_scene_id", ""))
	
	# Show dialog
	open_area_dialog.popup_centered()

func _on_open_area_dialog_close() -> void:
	open_area_dialog.hide()
	editing_open_area_node = {}
	editing_open_area_index = -1

func _on_open_area_save_pressed() -> void:
	if editing_open_area_node.is_empty():
		return
	
	# Read fields
	var node_id := area_node_id_field.text.strip_edges()
	if node_id.is_empty():
		push_warning("Node ID cannot be empty")
		return
	
	# Update node_def
	var old_id: String = str(editing_open_area_node.get("id", ""))
	editing_open_area_node["id"] = node_id
	editing_open_area_node["type"] = "open_area"
	editing_open_area_node["label"] = area_label_field.text.strip_edges()
	
	editing_open_area_node["entry_template"] = {
		"scene": area_entry_scene_field.text.strip_edges()
	}
	
	# Build objective
	var obj_kind_idx := area_objective_kind.selected
	var obj_kind := "discover_entity"
	if obj_kind_idx == 1:
		obj_kind = "interact_entity"
	elif obj_kind_idx == 2:
		obj_kind = "flag_equals"
	
	var objective := {
		"kind": obj_kind
	}
	
	if obj_kind in ["discover_entity", "interact_entity"]:
		objective["entity_id"] = area_objective_entity_field.text.strip_edges()
	elif obj_kind == "flag_equals":
		# Parse "flag=value"
		var flag_text := area_objective_flag_field.text.strip_edges()
		var parts := flag_text.split("=", false, 1)
		if parts.size() == 2:
			objective["flag"] = parts[0].strip_edges()
			objective["value"] = parts[1].strip_edges()
	
	editing_open_area_node["objective"] = objective
	
	editing_open_area_node["on_complete"] = {
		"goto_scene_id": area_completion_scene_field.text.strip_edges()
	}
	
	# Add to or update links_data
	if editing_open_area_index < 0:
		# New node
		if not links_data.has("nodes"):
			links_data["nodes"] = []
		links_data["nodes"].append(editing_open_area_node)
	else:
		# Update existing
		links_data["nodes"][editing_open_area_index] = editing_open_area_node
		
		# If ID changed, update edges
		if old_id != node_id:
			for edge_def in links_data.get("edges", []):
				if edge_def is Dictionary:
					if str(edge_def.get("from", "")) == old_id:
						edge_def["from"] = node_id
					if str(edge_def.get("to", "")) == old_id:
						edge_def["to"] = node_id
	
	_save_links_data()
	_rebuild_graph()
	_on_open_area_dialog_close()

## ========================================
## GRAPH UTILITIES
## ========================================

func _node_exists_in_links(node_id: String) -> bool:
	for node_def in links_data.get("nodes", []):
		if node_def is Dictionary:
			if str(node_def.get("id", "")) == node_id:
				return true
	return false

func _find_node_in_links(node_id: String) -> Dictionary:
	for node_def in links_data.get("nodes", []):
		if node_def is Dictionary:
			if str(node_def.get("id", "")) == node_id:
				return node_def
	return {}

func _save_node_position(node_id: String, pos: Vector2) -> void:
	for node_def in links_data.get("nodes", []):
		if node_def is Dictionary:
			if str(node_def.get("id", "")) == node_id:
				node_def["position"] = pos
				return
