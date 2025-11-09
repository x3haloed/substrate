extends Node
class_name OpticalMemory

## Optical memory rendering constants (tuned for OCR/VLM readability)
const PAGE_WIDTH: int = 1536
const PAGE_HEIGHT: int = 2048
const PAGE_MARGIN: int = 48
const FONT_SIZE: int = 28           # 26–32px works well for OCR
const LINE_SPACING: float = 1.1
const MAX_HISTORY: int = 20          # default cap for recent history in summaries

# Portrait/icon grid constants
const PORTRAIT_COLS: int = 4
const PORTRAIT_SLOT_W: int = 320
const PORTRAIT_SLOT_H: int = 360
const PORTRAIT_GAP: int = 16
const PORTRAIT_RADIUS: int = 12
const PORTRAIT_BG := Color(0.98, 0.98, 0.98)
const PORTRAIT_FRAME := Color(0.2, 0.2, 0.2)

# Visual diagram constants
const GRID_SIZE: int = 32
const NODE_RADIUS: int = 18
const EDGE_THICKNESS: float = 2.0
const COLOR_BG := Color(1,1,1)
const COLOR_GRID := Color(0.92,0.92,0.92)
const COLOR_TEXT := Color(0,0,0)
const COLOR_NODE := Color(0.15,0.15,0.15)
const COLOR_NODE_FILL := Color(0.85,0.9,1.0)
const COLOR_EDGE := Color(0.2,0.2,0.2)
const COLOR_HILITE := Color(0.1,0.6,0.95)

## Create a generic drawing viewport with a white background
func _create_drawing_page() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(PAGE_WIDTH, PAGE_HEIGHT)
	viewport.transparent_bg = false
	add_child(viewport)
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(PAGE_WIDTH, PAGE_HEIGHT)
	bg.position = Vector2.ZERO
	viewport.add_child(bg)
	return viewport

## --- 1) Scene Minimap: top-down spatial snapshot of entities
func _render_scene_minimap_to_image() -> Image:
	var viewport := _create_drawing_page()
	# Grid layer
	var grid := Control.new()
	grid.custom_minimum_size = Vector2(PAGE_WIDTH, PAGE_HEIGHT)
	grid.draw.connect(func():
		for x in range(0, PAGE_WIDTH, GRID_SIZE):
			grid.draw_line(Vector2(x,0), Vector2(x,PAGE_HEIGHT), COLOR_GRID)
		for y in range(0, PAGE_HEIGHT, GRID_SIZE):
			grid.draw_line(Vector2(0,y), Vector2(PAGE_WIDTH,y), COLOR_GRID)
	)
	viewport.add_child(grid)

	# Title
	var title := Label.new()
	title.text = "Scene Minimap"
	title.add_theme_color_override("font_color", COLOR_TEXT)
	var f := _load_optical_font()
	if f:
		title.add_theme_font_override("font", f)
		title.add_theme_font_size_override("font_size", FONT_SIZE + 4)
	title.position = Vector2(PAGE_MARGIN, PAGE_MARGIN/2)
	viewport.add_child(title)

	# Entities layer
	var nodes := Control.new()
	nodes.custom_minimum_size = Vector2(PAGE_WIDTH, PAGE_HEIGHT)
	nodes.draw.connect(func():
		var scene_id = world_db.flags.get("current_scene", "")
		var scene = world_db.get_scene(scene_id)
		if scene == null:
			return
		for entity in scene.entities:
			var pos := Vector2(PAGE_WIDTH/2, PAGE_HEIGHT/2) # default center
			if entity.props.has("pos"):
				var p = entity.props.get("pos")
				if typeof(p) == TYPE_VECTOR2:
					pos = Vector2(PAGE_MARGIN, PAGE_MARGIN) + p
				elif typeof(p) == TYPE_ARRAY and p.size() >= 2:
					pos = Vector2(PAGE_MARGIN + float(p[0]), PAGE_MARGIN + float(p[1]))
			# Clamp to page safe zone
			pos.x = clamp(pos.x, PAGE_MARGIN + NODE_RADIUS, PAGE_WIDTH - PAGE_MARGIN - NODE_RADIUS)
			pos.y = clamp(pos.y, PAGE_MARGIN + NODE_RADIUS + 24, PAGE_HEIGHT - PAGE_MARGIN - NODE_RADIUS)
			# Draw node
			nodes.draw_circle(pos, NODE_RADIUS, COLOR_NODE_FILL)
			nodes.draw_circle(pos, NODE_RADIUS, COLOR_NODE, EDGE_THICKNESS)
			# Label under node (truncated to prevent overflow)
			var label_text := _truncate_label(str(entity.id), 12)
			nodes.draw_string(ThemeDB.fallback_font, pos + Vector2(-NODE_RADIUS, NODE_RADIUS + 16), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 2)
	)
	viewport.add_child(nodes)

	await RenderingServer.frame_post_draw
	var img: Image = viewport.get_texture().get_image()
	nodes.queue_free(); grid.queue_free(); title.queue_free(); viewport.queue_free()
	return img

## --- 2) Relationship Graph: entities as nodes, edges by relationship type
func _render_relationship_graph_to_image() -> Image:
	var viewport := _create_drawing_page()
	var center := Vector2(PAGE_WIDTH/2, PAGE_HEIGHT/2 + 40)
	var radius := min(PAGE_WIDTH, PAGE_HEIGHT) * 0.35
	var entities: Array[String] = []
	for k in world_db.relationships.keys():
		if not entities.has(k):
			entities.append(k)
		if world_db.relationships[k] is Dictionary:
			for r in world_db.relationships[k].keys():
				if not entities.has(r):
					entities.append(r)

	# Node positions around a circle
	var positions := {}
	var count: int = entities.size()
	for i in range(count):
		var ang := TAU * float(i) / float(count)
		positions[entities[i]] = center + Vector2(cos(ang), sin(ang)) * radius

	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(PAGE_WIDTH, PAGE_HEIGHT)
	canvas.draw.connect(func():
		# Edges
		for a in world_db.relationships.keys():
			if world_db.relationships[a] is Dictionary:
				for b in world_db.relationships[a].keys():
					var pa: Vector2 = positions.get(a, center)
					var pb: Vector2 = positions.get(b, center)
					canvas.draw_line(pa, pb, COLOR_EDGE, EDGE_THICKNESS)
		# Nodes and labels
		for e in entities:
			var p: Vector2 = positions[e]
			canvas.draw_circle(p, NODE_RADIUS, COLOR_NODE_FILL)
			canvas.draw_circle(p, NODE_RADIUS, COLOR_NODE, EDGE_THICKNESS)
			# Truncate label to prevent overflow on circular layout
			var label_text := _truncate_label(e, 14)
			canvas.draw_string(ThemeDB.fallback_font, p + Vector2(-NODE_RADIUS, NODE_RADIUS + 12), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 2)
	)
	viewport.add_child(canvas)

	# Title
	var title := Label.new()
	title.text = "Entity Relationships"
	title.add_theme_color_override("font_color", COLOR_TEXT)
	var f := _load_optical_font()
	if f:
		title.add_theme_font_override("font", f)
		title.add_theme_font_size_override("font_size", FONT_SIZE + 4)
	title.position = Vector2(PAGE_MARGIN, PAGE_MARGIN/2)
	viewport.add_child(title)

	await RenderingServer.frame_post_draw
	var img: Image = viewport.get_texture().get_image()
	canvas.queue_free(); title.queue_free(); viewport.queue_free()
	return img

## --- 3) Timeline Strip: recent history as spatial, iconized events
func _render_timeline_strip_to_image() -> Image:
	var viewport := _create_drawing_page()
	var left := PAGE_MARGIN
	var right := PAGE_WIDTH - PAGE_MARGIN
	var top := PAGE_MARGIN + 40
	var bottom := PAGE_HEIGHT - PAGE_MARGIN - 80
	var mid_y: float = lerp(top, bottom, 0.4)

	var line := Control.new()
	line.draw.connect(func():
		line.draw_line(Vector2(left, mid_y), Vector2(right, mid_y), COLOR_EDGE, EDGE_THICKNESS)
	)
	viewport.add_child(line)

	# Collect recent history (reuse MAX_HISTORY)
	var events: Array[Dictionary] = []
	var cap: int = min(MAX_HISTORY, world_db.history.size())
	for i in range(world_db.history.size() - cap, world_db.history.size()):
		events.append(world_db.history[i])

	var n: int = max(events.size(), 1)
	for i in range(n):
		var x: float = lerp(left, right, float(i) / float(max(n-1,1)))
		var e := events[i]
		var glyph := "•"
		match e.get("event",""):
			"scene_enter": glyph = "S"
			"action": glyph = "A"
			"entity_discovery": glyph = "D"
			"entity_change": glyph = "C"
		# tick mark
		var tick := Label.new()
		tick.text = glyph
		if _load_optical_font():
			tick.add_theme_font_override("font", _load_optical_font())
			tick.add_theme_font_size_override("font_size", FONT_SIZE + 6)
		tick.position = Vector2(x - 6, mid_y - 24)
		viewport.add_child(tick)
		# caption
		var caption := Label.new()
		caption.text = e.get("ts","?")
		if _load_optical_font():
			caption.add_theme_font_override("font", _load_optical_font())
			caption.add_theme_font_size_override("font_size", FONT_SIZE - 2)
		caption.position = Vector2(x - 24, mid_y + 8)
		viewport.add_child(caption)

	# Title
	var title := Label.new()
	title.text = "Recent Timeline"
	if _load_optical_font():
		title.add_theme_font_override("font", _load_optical_font())
		title.add_theme_font_size_override("font_size", FONT_SIZE + 4)
	title.position = Vector2(PAGE_MARGIN, PAGE_MARGIN/2)
	viewport.add_child(title)

	await RenderingServer.frame_post_draw
	var img: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	return img
	
## Generate an expanded bundle IN MEMORY: text pages + spatial visualizations
## @param summary_text: Pre-generated summary text to render (ensures consistency with prompts)
## @return Array[Image]: ordered images ready to be encoded/sent to LLMs
func generate_optical_memory_images(summary_text: String) -> Array[Image]:
	var images: Array[Image] = []
	# 1) Text pages (use provided summary text for consistency with prompts)
	var page_images: Array[Image] = await generate_optical_memory_page_images(summary_text)
	images.append_array(page_images)
	# 2) Visual pages (minimap, relationships, timeline)
	var mm := await _render_scene_minimap_to_image()
	images.append(mm)
	var rg := await _render_relationship_graph_to_image()
	images.append(rg)
	var tl := await _render_timeline_strip_to_image()
	images.append(tl)
	return images

# Optional high-contrast, mono font if present (cached to avoid repeated FS access)
func _load_optical_font() -> Font:
	if _cached_font != null:
		return _cached_font
	if ResourceLoader.exists("res://fonts/JetBrainsMono-Regular.ttf"):
		_cached_font = load("res://fonts/JetBrainsMono-Regular.ttf")
		return _cached_font
	return null

## Truncate long labels for visual diagrams to prevent overflow
func _truncate_label(text: String, max_length: int = 16) -> String:
	if text.length() <= max_length:
		return text
	return text.substr(0, max_length - 1) + "…"

## Generates rasterized summary pages (Images in memory) for VLM attachment (optical memory sheets)

var world_db: WorldDB
var _cached_font: Font = null  # Cached mono font to avoid repeated filesystem access

func _init(p_world_db: WorldDB):
	world_db = p_world_db

## Generate a session summary as text (can be rasterized to PNG)
func generate_session_summary(scene_id: String = "", max_length: int = 5000) -> String:
	var summary = ""
	
	# Current scene context
	var current_scene_id = scene_id if scene_id != "" else world_db.flags.get("current_scene", "")
	var scene = world_db.get_scene(current_scene_id)
	
	summary += "[b]SESSION SUMMARY[/b]\n\n"
	
	if scene:
		summary += "Current Scene: " + scene.scene_id + "\n"
		summary += "Description: " + scene.description + "\n\n"
		
		summary += "[b]Entities in Scene[/b]\n"
		for entity in scene.entities:
			summary += "  • " + entity.id + " (" + entity.type_name + ")\n"
			if entity.props.size() > 0:
				for key in entity.props.keys():
					summary += "    - " + key + ": " + str(entity.props[key]) + "\n"
	
	summary += "\n[b]RECENT HISTORY[/b]\n\n"
	
	# Get last N history entries
	var recent_history: Array = []
	var cap: int = min(MAX_HISTORY, world_db.history.size())
	for i in range(world_db.history.size() - 1, world_db.history.size() - cap - 1, -1):
		recent_history.append(world_db.history[i])
	
	for entry in recent_history:
		var event_type = entry.get("event", "unknown")
		var timestamp = entry.get("ts", "unknown")
		summary += "[" + timestamp + "] " + event_type.upper() + "\n"
		
		match event_type:
			"scene_enter":
				summary += "  Entered: " + entry.get("scene", "") + "\n"
			"action":
				summary += "  Actor: " + entry.get("actor", "") + " | "
				summary += "Verb: " + entry.get("verb", "") + " | "
				summary += "Target: " + entry.get("target", "") + "\n"
			"entity_discovery":
				summary += "  Entity: " + entry.get("entity_id", "") + " discovered by " + entry.get("actor", "") + "\n"
			"entity_change":
				summary += "  Entity: " + entry.get("entity_id", "") + " | "
				summary += "Change: " + entry.get("change_type", "") + " at " + entry.get("path", "") + "\n"
		
		summary += "\n"
	
	summary += "\n[b]ENTITY DISCOVERY TRACKING[/b]\n\n"
	
	# List discovered entities
	var discovered_entities = world_db.get_entities_discovered_by("player")
	if discovered_entities.size() > 0:
		summary += "Discovered by Player:\n"
		for entity_id in discovered_entities:
			summary += "  • " + entity_id + "\n"
			var entity_history = world_db.get_entity_history(entity_id)
			if entity_history.size() > 0:
				var first_discovery = entity_history[-1]  # Oldest entry
				if first_discovery.get("type") == "discovery":
					summary += "    First seen: " + first_discovery.get("timestamp", "unknown") + "\n"
	
	summary += "\n[b]RELATIONSHIPS[/b]\n\n"
	
	# Entity relationships
	if world_db.relationships.size() > 0:
		for entity_id in world_db.relationships.keys():
			if world_db.relationships[entity_id] is Dictionary:
				for related_id in world_db.relationships[entity_id].keys():
					var rel_type = world_db.relationships[entity_id][related_id]
					summary += "  " + entity_id + " → " + rel_type + " → " + related_id + "\n"
	
	# Truncate if too long
	if summary.length() > max_length:
		summary = summary.substr(0, max_length) + "\n\n...[truncated]"
	
	return summary

## Create a SubViewport page with high-contrast settings and return (viewport, label)
func _create_optical_page() -> Array:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(PAGE_WIDTH, PAGE_HEIGHT)
	viewport.transparent_bg = false
	add_child(viewport)

	# White background to maximize OCR contrast
	var bg := ColorRect.new()
	bg.color = Color.WHITE
	bg.size = Vector2(PAGE_WIDTH, PAGE_HEIGHT)
	bg.position = Vector2.ZERO
	viewport.add_child(bg)

	# Text label configured for OCR-friendly layout
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.size = Vector2(PAGE_WIDTH - PAGE_MARGIN * 2, PAGE_HEIGHT - PAGE_MARGIN * 2)
	label.position = Vector2(PAGE_MARGIN, PAGE_MARGIN)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.scroll_active = false
	label.visible_characters_behavior = TextServer.VC_CHARS_BEFORE_SHAPING
	# Godot 4: use theme constant 'line_separation' instead of a line_spacing property
	label.add_theme_constant_override("line_separation", int((LINE_SPACING - 1.0) * FONT_SIZE))

	# Apply mono font if available
	var f := _load_optical_font()
	if f:
		label.add_theme_font_override("normal_font", f)
		label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
		# Already set above; calling again is harmless but redundant

	viewport.add_child(label)
	return [viewport, label]

## Measure how many paragraphs fit on a page and split text into pages.
## Returns an Array of page strings.
func _paginate_text(input_text: String) -> Array:
	var paras: Array = input_text.split("\n\n")
	var pages: Array = []
	var idx := 0
	while idx < paras.size():
		var page_text := ""
		var test_label := RichTextLabel.new()
		test_label.bbcode_enabled = true
		test_label.fit_content = true
		test_label.size = Vector2(PAGE_WIDTH - PAGE_MARGIN * 2, PAGE_HEIGHT - PAGE_MARGIN * 2)
		test_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var f := _load_optical_font()
		if f:
			test_label.add_theme_font_override("normal_font", f)
			test_label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
			test_label.add_theme_constant_override("line_separation", int((LINE_SPACING - 1.0) * FONT_SIZE))

		# Greedily add paragraphs until overflow
		var added := 0
		while idx + added < paras.size():
			var candidate := page_text
			if candidate != "":
				candidate += "\n\n"
			candidate += paras[idx + added]
			test_label.clear()
			test_label.text = candidate
			# Use an offscreen measurement via minimum size
			var content_h := test_label.get_content_height()
			if content_h <= PAGE_HEIGHT - PAGE_MARGIN * 2:
				page_text = candidate
				added += 1
			else:
				break

		if page_text == "":
			# Fallback: force-split an oversized paragraph by lines
			var lines: Array = paras[idx].split("\n")
			var forced := ""
			for line in lines:
				var trytxt: String = forced + ("\n" if forced != "" else "") + line
				test_label.clear()
				test_label.text = trytxt
				if test_label.get_content_height() <= PAGE_HEIGHT - PAGE_MARGIN * 2:
					forced = trytxt
				else:
					break
			page_text = forced
			# Keep the remainder of the paragraph for next page
			paras[idx] = paras[idx].substr(forced.length()).lstrip() 
			added = 0
		else:
			idx += added

		pages.append(page_text)
		# Avoid infinite loops
		if added == 0 and page_text.length() == 0:
			break
		test_label.queue_free()
	return pages

## Render a single page string into an Image
func _render_page_to_image(page_text: String) -> Image:
	var pair := _create_optical_page()
	var viewport: SubViewport = pair[0]
	var label: RichTextLabel = pair[1]
	label.text = page_text
	await RenderingServer.frame_post_draw
	var img: Image = viewport.get_texture().get_image()
	label.queue_free()
	viewport.queue_free()
	return img

## Helper: load a portrait/icon for an entity.
## Looks in props: `portrait` (path), `icon` (path), or `thumbnail` (path).
## Returns Texture2D or null if not found.
func _get_entity_texture(entity) -> Texture2D:
	var keys := ["portrait", "icon", "thumbnail"]
	for k in keys:
		if entity.props.has(k):
			var v = entity.props.get(k)
			if typeof(v) == TYPE_STRING and v != "":
				if ResourceLoader.exists(v):
					var tex: Texture2D = load(v)
					if tex: return tex
	return null

## Render a grid of entity portrait cards (name + optional type + portrait)
func _render_entity_portraits_to_image() -> Image:
	var viewport := _create_drawing_page()

	# Title
	var title := Label.new()
	title.text = "Scene Portraits"
	var f := _load_optical_font()
	if f:
		title.add_theme_font_override("font", f)
		title.add_theme_font_size_override("font_size", FONT_SIZE + 4)
	title.position = Vector2(PAGE_MARGIN, PAGE_MARGIN/2)
	viewport.add_child(title)

	var scene_id = world_db.flags.get("current_scene", "")
	var scene = world_db.get_scene(scene_id)
	if scene == null:
		await RenderingServer.frame_post_draw
		var empty_img: Image = viewport.get_texture().get_image()
		title.queue_free(); viewport.queue_free()
		return empty_img

	# Grid origin (below title)
	var origin := Vector2(PAGE_MARGIN, PAGE_MARGIN + 40)
	var usable_w := PAGE_WIDTH - PAGE_MARGIN * 2
	var cols: int = max(PORTRAIT_COLS, 1)
	var col_w := PORTRAIT_SLOT_W
	var row_h := PORTRAIT_SLOT_H
	var x := 0
	var y := 0

	for i in range(scene.entities.size()):
		var e = scene.entities[i]
		var cx := int(i % cols)
		var cy := int(i / cols)
		var card_pos := origin + Vector2(cx * (col_w + PORTRAIT_GAP), cy * (row_h + PORTRAIT_GAP))

		# Card container
		var card := Control.new()
		card.position = card_pos
		card.custom_minimum_size = Vector2(col_w, row_h)
		card.draw.connect(func():
			# rounded rect backdrop
			card.draw_rect(Rect2(Vector2.ZERO, Vector2(col_w, row_h)), PORTRAIT_BG)
			card.draw_rect(Rect2(Vector2.ZERO, Vector2(col_w, row_h)), PORTRAIT_FRAME, false, 2.0)
		)
		viewport.add_child(card)

		# Portrait area (keep-aspect, centered)
		var portrait_tex := _get_entity_texture(e)
		var texrect := TextureRect.new()
		texrect.size = Vector2(col_w - 16, row_h - 80)
		texrect.position = Vector2(8, 8)
		texrect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		texrect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		texrect.texture = portrait_tex
		card.add_child(texrect)

		# If missing texture, show initials block
		if portrait_tex == null:
			var fallback := Label.new()
			fallback.text = e.id.substr(0, 2).to_upper()
			if f:
				fallback.add_theme_font_override("font", f)
				fallback.add_theme_font_size_override("font_size", FONT_SIZE + 12)
			fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			fallback.size = texrect.size
			fallback.position = texrect.position
			card.add_child(fallback)

		# Name label
		var name_lbl := Label.new()
		name_lbl.text = e.id
		if f:
			name_lbl.add_theme_font_override("font", f)
			name_lbl.add_theme_font_size_override("font_size", FONT_SIZE)
		name_lbl.position = Vector2(10, row_h - 64)
		card.add_child(name_lbl)

		# Type label (muted)
		var type_lbl := Label.new()
		type_lbl.text = String(e.type_name)
		type_lbl.modulate = Color(0,0,0,0.65)
		if f:
			type_lbl.add_theme_font_override("font", f)
			type_lbl.add_theme_font_size_override("font_size", FONT_SIZE - 2)
		type_lbl.position = Vector2(10, row_h - 36)
		card.add_child(type_lbl)

	# Flush and capture
	await RenderingServer.frame_post_draw
	var img: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	return img

## Generate optical memory page Images by rendering paginated text into Viewports.
## @param summary_text: Pre-generated summary text to render
## @return Array[Image]: in-memory images, no disk writes
func generate_optical_memory_page_images(summary_text: String) -> Array[Image]:
	var pages := _paginate_text(summary_text)
	var images: Array[Image] = []
	for i in range(pages.size()):
		var img := await _render_page_to_image(pages[i])
		images.append(img)
	# Also include a portraits page for quick visual recall
	var pf := await _render_entity_portraits_to_image()
	images.append(pf)
	return images

## Generate a single optical memory Image by rendering text to a Viewport (no disk)
## @param summary_text: Pre-generated summary text to render
## @return Image: in-memory rendered page
func generate_optical_memory_image(summary_text: String) -> Image:
	var pages := _paginate_text(summary_text)
	if pages.size() == 0:
		return await _render_page_to_image("")
	return await _render_page_to_image(pages[0])

## Generate a lightweight text summary (for inclusion in prompts)
func generate_prompt_summary(max_entities: int = 10) -> String:
	var summary = generate_session_summary("", 2000)
	return summary

# Usage tip:
#   var images: Array[Image] = await optical_memory.generate_optical_memory_images(summary_text)
#   # images now contains paginated text images + minimap + relationships + timeline (all in memory)
