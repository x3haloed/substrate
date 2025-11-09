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

## Internal page-image cache (PNG bytes), keyed by stable hashes
var _page_cache: Dictionary = {}

## Create a generic drawing viewport with a white background
func _create_drawing_page() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(PAGE_WIDTH, PAGE_HEIGHT)
	viewport.transparent_bg = false
	# Ensure at least one render before readback (fixes blank images)
	viewport.set_update_mode(SubViewport.UPDATE_ONCE)
	add_child(viewport)
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(PAGE_WIDTH, PAGE_HEIGHT)
	bg.position = Vector2.ZERO
	viewport.add_child(bg)
	return viewport

## --- 1) Scene Minimap: top-down spatial snapshot of entities
## entities: Array[Dictionary] with { "id": String, "pos": Vector2 or [x, y] }
func render_scene_minimap_to_image(entities: Array) -> Image:
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
		for entity in entities:
			var pos := Vector2(PAGE_WIDTH/2, PAGE_HEIGHT/2) # default center
			if entity is Dictionary and entity.has("pos"):
				var p = entity.get("pos")
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
			var label_text := _truncate_label(str(entity.get("id", "")), 12)
			nodes.draw_string(ThemeDB.fallback_font, pos + Vector2(-NODE_RADIUS, NODE_RADIUS + 16), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 2)
	)
	viewport.add_child(nodes)

	await RenderingServer.frame_post_draw
	var img: Image = viewport.get_texture().get_image()
	nodes.queue_free(); grid.queue_free(); title.queue_free(); viewport.queue_free()
	return img

## --- 2) Relationship Graph: entities as nodes, edges by relationship type
## relationships: Dictionary { id: { related_id: relationship_type } }
func render_relationship_graph_to_image(relationships: Dictionary) -> Image:
	var viewport := _create_drawing_page()
	var center := Vector2(PAGE_WIDTH/2, PAGE_HEIGHT/2 + 40)
	var radius := min(PAGE_WIDTH, PAGE_HEIGHT) * 0.35
	var entities: Array[String] = []
	for k in relationships.keys():
		if not entities.has(String(k)):
			entities.append(String(k))
		if relationships[k] is Dictionary:
			for r in relationships[k].keys():
				var rid := String(r)
				if not entities.has(rid):
					entities.append(rid)

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
		for a in relationships.keys():
			if relationships[a] is Dictionary:
				for b in relationships[a].keys():
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
## events: Array[Dictionary] with { "event": String, "ts": String, "glyph"?: String }
## glyph_map: Dictionary mapping event kind -> glyph (e.g., { "scene_enter": "S" })
func render_timeline_strip_to_image(events: Array, glyph_map: Dictionary = {}) -> Image:
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

	var n: int = events.size()
	for i in range(n):
		var x: float = lerp(left, right, float(i) / float(max(n-1,1)))
		var e: Dictionary = events[i] if (i < events.size() and events[i] is Dictionary) else {}
		# Choose glyph by priority:
		# 1) explicit e["glyph"]; 2) glyph_map[event_kind]; 3) first letter of event; 4) bullet
		var glyph := String(e.get("glyph", ""))
		if glyph == "":
			var kind := String(e.get("event",""))
			if kind != "" and glyph_map.has(kind):
				glyph = String(glyph_map.get(kind))
			elif kind != "":
				glyph = kind.substr(0, 1).to_upper()
			else:
				glyph = "•"
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
		caption.text = String(e.get("ts","?"))
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
## visuals: {
##   "minimap_entities": Array[Dictionary],
##   "relationships": Dictionary,
##   "timeline_events": Array[Dictionary],
##   "portrait_entities": Array[Dictionary]
## }
func generate_optical_memory_images(summary_text: String, visuals: Dictionary = {}) -> Array[Image]:
	var images: Array[Image] = []
	# 1) Text pages (use provided summary text for consistency with prompts)
	var page_images: Array[Image] = await generate_optical_memory_page_images(summary_text)
	images.append_array(page_images)
	# 2) Visual pages (minimap, relationships, timeline)
	if visuals.has("minimap_entities"):
		var mm := await render_scene_minimap_to_image(visuals.get("minimap_entities", []))
		images.append(mm)
	if visuals.has("relationships"):
		var rg := await render_relationship_graph_to_image(visuals.get("relationships", {}))
		images.append(rg)
	if visuals.has("timeline_events"):
		var tl := await render_timeline_strip_to_image(visuals.get("timeline_events", []))
		images.append(tl)
	if visuals.has("portrait_entities"):
		var pf := await render_entity_portraits_to_image(visuals.get("portrait_entities", []))
		images.append(pf)
	return images

## Build a compact chat transcript string from world history without timestamps.
## Lines:
## - Player: "You: text"
## - NPC narration with speaker: "Speaker: text"
## - World narration: "Narrator: text"
## - Scene changes as section headers
func build_chat_transcript_text(history: Array, max_events: int = 1000) -> String:
	var lines: Array[String] = []
	if history == null or not (history is Array):
		return ""
	var n: int = history.size()
	var start: int = max(0, n - max_events)
	for i in range(start, n):
		var e = history[i]
		if not (e is Dictionary):
			continue
		var kind := str(e.get("event",""))
		match kind:
			"scene_enter":
				var sid := str(e.get("scene",""))
				if sid != "":
					lines.append("[b]— Enter scene: %s —[/b]" % sid)
			"player_text":
				var pt := str(e.get("text","")).strip_edges()
				if pt != "":
					lines.append("You: " + pt)
			"narration":
				var speaker := str(e.get("speaker",""))
				var style := str(e.get("style","world"))
				var speaker_name := speaker if speaker != "" else ("Narrator" if style == "world" else "NPC")
				var t := str(e.get("text","")).strip_edges()
				if t == "":
					continue
				lines.append(speaker_name + ": " + t)
			_:
				# Skip other events in the chat transcript
				pass
	return "\n".join(lines)

## Render arbitrary text into pages with caching and page fiducials.
## - kind: label for cache key and header, e.g., "ChatTranscript"
## - max_pages: cap number of rendered pages
## - cache_store: Dictionary mapping cacheKey -> PackedByteArray (PNG); optional
## - fiducials: { "scene_id": String }
func render_text_pages_with_cache(kind: String, text: String, max_pages: int = 2, cache_store: Dictionary = {}, fiducials: Dictionary = {}) -> Array[Image]:
	var pages: Array = _paginate_text(text)
	var total: int = pages.size()
	if max_pages > 0:
		total = min(total, max_pages)
	var out: Array[Image] = []
	var scene_id := str(fiducials.get("scene_id", ""))
	# Choose a cache store (fallback to internal)
	var store := cache_store if (cache_store != null and cache_store.size() > 0) else _page_cache
	for i in range(total):
		var header := "[[PAGE: %s %d/%d%s]]\n" % [kind, i + 1, pages.size(), (" | Scene=" + scene_id) if scene_id != "" else ""]
		var page_text: String = header + String(pages[i])
		# Compute stable key
		var key := "%s:%d" % [kind, hash(page_text)]
		var used_cache := false
		if store != null and store.has(key) and store.get(key) is PackedByteArray:
			var bytes: PackedByteArray = store.get(key)
			var img := Image.new()
			var err := img.load_png_from_buffer(bytes)
			if err == OK:
				out.append(img)
				used_cache = true
		if not used_cache:
			var img2 := await _render_page_to_image(page_text)
			out.append(img2)
			if store != null:
				var png_bytes := img2.save_png_to_buffer()
				store[key] = png_bytes
	return out

## Compose a mosaic page from multiple full pages, downscaled to a grid.
func _compose_mosaic_page(tiles: Array[Image], rows: int = 3, cols: int = 2, title: String = "Compressed Transcript") -> Image:
	var viewport := _create_drawing_page()
	# Title
	var title_lbl := Label.new()
	title_lbl.text = title
	var f := _load_optical_font()
	if f:
		title_lbl.add_theme_font_override("font", f)
		title_lbl.add_theme_font_size_override("font_size", FONT_SIZE + 2)
	title_lbl.position = Vector2(PAGE_MARGIN, PAGE_MARGIN/2)
	viewport.add_child(title_lbl)
	# Grid geometry
	var gap := 16
	var origin := Vector2(PAGE_MARGIN, PAGE_MARGIN + 40)
	var grid_w := PAGE_WIDTH - PAGE_MARGIN * 2
	var grid_h := PAGE_HEIGHT - PAGE_MARGIN * 2 - 40
	var tile_w := int((grid_w - (cols - 1) * gap) / cols)
	var tile_h := int((grid_h - (rows - 1) * gap) / rows)
	# Add tiles
	for i in range(min(tiles.size(), rows * cols)):
		var r := int(i / cols)
		var c := int(i % cols)
		var x := origin.x + c * (tile_w + gap)
		var y := origin.y + r * (tile_h + gap)
		var tex := ImageTexture.create_from_image(tiles[i])
		var rect := TextureRect.new()
		rect.texture = tex
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size = Vector2(tile_w, tile_h)
		rect.position = Vector2(x, y)
		viewport.add_child(rect)
	# Flush
	await RenderingServer.frame_post_draw
	var img: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	return img

## Generic text+tiles renderer: render N full pages and 1 mosaic (rows x cols) of subsequent pages.
## - kind: cache/prefix label, e.g., "ChatTranscript" or "LoreBook"
## - text: already-assembled corpus (chat transcript, lore corpus, etc.)
## - full_pages: number of full-size pages to render before tiling the next pages
## - mosaic_rows, mosaic_cols: grid for compressed pages in the final tile
## - cache_store, fiducials: pass-through to render_text_pages_with_cache for stable caching
func render_text_with_mosaic(kind: String, text: String, full_pages: int = 1, mosaic_rows: int = 3, mosaic_cols: int = 2, cache_store: Dictionary = {}, fiducials: Dictionary = {}) -> Array[Image]:
	var corpus := String(text)
	var all_pages: Array = _paginate_text(corpus)
	if all_pages.is_empty():
		return [await _render_page_to_image("")]
	# Render newest 'full_pages' pages at full resolution
	var full_images: Array[Image] = await render_text_pages_with_cache(kind, corpus, max(full_pages, 0), cache_store, fiducials)
	# If there are no additional pages beyond full_pages, return the full pages only
	if all_pages.size() <= full_pages:
		return full_images
	# Build images for the next chunk to tile
	var tiles_needed: int = max(0, mosaic_rows * mosaic_cols)
	var tile_pages: Array = []
	for i in range(full_pages, min(all_pages.size(), full_pages + tiles_needed)):
		tile_pages.append(all_pages[i])
	# Render each tile page (with lightweight headers)
	var tile_images: Array[Image] = []
	var tile_kind := kind + "Tile"
	for j in range(tile_pages.size()):
		var header := "[[PAGE: %s %d/%d (tile)]]\n" % [kind, full_pages + j + 1, all_pages.size()]
		var ptext := header + String(tile_pages[j])
		var imgs := await render_text_pages_with_cache(tile_kind, ptext, 1, cache_store, fiducials)
		if imgs.size() > 0:
			tile_images.append(imgs[0])
	# Compose mosaic final page
	var title := "Compressed " + kind
	var mosaic := await _compose_mosaic_page(tile_images, mosaic_rows, mosaic_cols, title)
	var out: Array[Image] = []
	out.append_array(full_images)
	out.append(mosaic)
	return out
 

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

var _cached_font: Font = null  # Cached mono font to avoid repeated filesystem access

## Create a SubViewport page with high-contrast settings and return (viewport, label)
func _create_optical_page() -> Array:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(PAGE_WIDTH, PAGE_HEIGHT)
	viewport.transparent_bg = false
	# Ensure the viewport renders at least once so we can read back the image
	viewport.set_update_mode(SubViewport.UPDATE_ONCE)
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
	# Ensure high-contrast dark text regardless of global theme
	label.add_theme_color_override("default_color", COLOR_TEXT) # black
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
			paras[idx] = paras[idx].substr(forced.length()).strip_edges(true, false)
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

## Render a grid of entity portrait cards (name + optional type + portrait)
## entities: Array[Dictionary] with { "id": String, "type_name": String, "texture": Texture2D? }
func render_entity_portraits_to_image(entities: Array) -> Image:
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

	# Grid origin (below title)
	var origin := Vector2(PAGE_MARGIN, PAGE_MARGIN + 40)
	var _usable_w := PAGE_WIDTH - PAGE_MARGIN * 2
	var cols: int = max(PORTRAIT_COLS, 1)
	var col_w := PORTRAIT_SLOT_W
	var row_h := PORTRAIT_SLOT_H
	var _x := 0
	var _y := 0

	for i in range(entities.size()):
		var e = entities[i]
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

		# Portrait area (keep-aspect, centered). Expect a Texture2D in "texture" if provided.
		var portrait_tex: Texture2D = null
		if e is Dictionary and e.has("texture") and e.get("texture") is Texture2D:
			portrait_tex = e.get("texture")
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
			var eid := String(e.get("id",""))
			fallback.text = eid.substr(0, 2).to_upper()
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
		name_lbl.text = String(e.get("id",""))
		if f:
			name_lbl.add_theme_font_override("font", f)
			name_lbl.add_theme_font_size_override("font_size", FONT_SIZE)
		name_lbl.position = Vector2(10, row_h - 64)
		card.add_child(name_lbl)

		# Type label (muted)
		var type_lbl := Label.new()
		type_lbl.text = String(e.get("type_name",""))
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
	return images

## Generate a single optical memory Image by rendering text to a Viewport (no disk)
## @param summary_text: Pre-generated summary text to render
## @return Image: in-memory rendered page
func generate_optical_memory_image(summary_text: String) -> Image:
	var pages := _paginate_text(summary_text)
	if pages.size() == 0:
		return await _render_page_to_image("")
	return await _render_page_to_image(pages[0])
