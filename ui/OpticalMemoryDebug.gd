extends Control
class_name OpticalMemoryDebug

## Debug viewer for OpticalMemory rendering (live preview)

@onready var viewport_container: SubViewportContainer = %ViewportContainer
@onready var generate_button: Button = %GenerateButton
@onready var close_button: Button = %CloseButton
@onready var mode_option: OptionButton = %ModeOption
@onready var status_label: Label = %StatusLabel

var world_db: WorldDB
var optical_memory: OpticalMemory

signal closed

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	generate_button.pressed.connect(_on_generate_pressed)
	mode_option.add_item("Text Pages + Visuals", 0)
	mode_option.add_item("Minimap Only", 1)
	mode_option.add_item("Relationships Only", 2)
	mode_option.add_item("Timeline Only", 3)
	mode_option.add_item("Portraits Only", 4)
	mode_option.selected = 0
	status_label.text = "Ready. Click 'Generate' to render optical memory."

func setup(p_world_db: WorldDB, p_optical_memory: OpticalMemory) -> void:
	world_db = p_world_db
	optical_memory = p_optical_memory

func _on_close_pressed() -> void:
	hide()
	closed.emit()

func _on_generate_pressed() -> void:
	if world_db == null or optical_memory == null:
		status_label.text = "Error: Missing world_db or optical_memory"
		return
	
	generate_button.disabled = true
	status_label.text = "Generating..."
	
	# Clear existing viewport children
	var viewport := _get_or_create_viewport()
	for child in viewport.get_children():
		child.queue_free()
	
	# Build memory context
	var memory_context := world_db.build_prompt_memory([], "player")
	var history_text: String = String(memory_context.get("history_text", ""))
	var lore_text: String = String(memory_context.get("lore_text", ""))
	var full_summary_text := history_text
	if lore_text != "":
		full_summary_text += "\n\n[b]LORE DATABASE[/b]\n\n" + lore_text
	
	# Render based on selected mode
	var mode: int = mode_option.selected
	match mode:
		0:  # Full bundle
			await _render_full_bundle(viewport, full_summary_text)
		1:  # Minimap
			await _render_single_visual(viewport, "minimap")
		2:  # Relationships
			await _render_single_visual(viewport, "relationships")
		3:  # Timeline
			await _render_single_visual(viewport, "timeline")
		4:  # Portraits
			await _render_single_visual(viewport, "portraits")
	
	status_label.text = "Done! Viewport updated."
	generate_button.disabled = false

func _get_or_create_viewport() -> SubViewport:
	if viewport_container.get_child_count() > 0:
		var existing_vp := viewport_container.get_child(0)
		if existing_vp is SubViewport:
			return existing_vp
	# Create new viewport
	var new_vp := SubViewport.new()
	new_vp.size = Vector2i(1536, 2048)
	new_vp.transparent_bg = false
	viewport_container.add_child(new_vp)
	return new_vp

func _render_full_bundle(viewport: SubViewport, summary_text: String) -> void:
	# Render a vertical stack: text pages + visuals
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport.add_child(vbox)
	
	# Generate images in memory
	var images: Array[Image] = await optical_memory.generate_optical_memory_images(summary_text)
	
	for img in images:
		var tex := ImageTexture.create_from_image(img)
		var rect := TextureRect.new()
		rect.texture = tex
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		rect.custom_minimum_size = Vector2(0, 400)
		vbox.add_child(rect)
	
	status_label.text = "Rendered %d images in viewport" % images.size()

func _render_single_visual(viewport: SubViewport, visual_type: String) -> void:
	var img: Image
	match visual_type:
		"minimap":
			img = await optical_memory._render_scene_minimap_to_image()
		"relationships":
			img = await optical_memory._render_relationship_graph_to_image()
		"timeline":
			img = await optical_memory._render_timeline_strip_to_image()
		"portraits":
			img = await optical_memory._render_entity_portraits_to_image()
	
	if img:
		var tex := ImageTexture.create_from_image(img)
		var rect := TextureRect.new()
		rect.texture = tex
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		viewport.add_child(rect)
		status_label.text = "Rendered %s" % visual_type
