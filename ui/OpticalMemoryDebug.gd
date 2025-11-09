extends Control
class_name OpticalMemoryDebug

## Debug viewer for OpticalMemory rendering (live preview)

@onready var vbox_container: VBoxContainer = %VBoxContainer
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
	mode_option.add_item("Chat Transcript Only", 5)
	mode_option.add_item("Lorebook Only", 6)
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
	
	_clear_vbox_content()
	
	# Build memory context (local equivalent of build_prompt_memory)
	var memory_context: Dictionary = _build_prompt_memory_local([])
	var history_text: String = str(memory_context.get("history_text", ""))
	var lore_text: String = str(memory_context.get("lore_text", ""))
	var full_summary_text := history_text
	if lore_text != "":
		full_summary_text += "\n\n[b]LORE DATABASE[/b]\n\n" + lore_text
	
	# Render based on selected mode
	var mode: int = mode_option.selected
	match mode:
		0:  # Full bundle
			await _render_full_bundle(full_summary_text)
		1:  # Minimap
			await _render_single_visual("minimap")
		2:  # Relationships
			await _render_single_visual("relationships")
		3:  # Timeline
			await _render_single_visual("timeline")
		4:  # Portraits
			await _render_single_visual("portraits")
		5:  # Chat transcript
			await _render_single_visual("chat")
		6:  # Lorebook
			await _render_single_visual("lore")
	
	status_label.text = "Done! VBoxContainer updated."
	generate_button.disabled = false

func _clear_vbox_content() -> void:
	for child in vbox_container.get_children():
		child.queue_free()

func _render_full_bundle(summary_text: String) -> void:
	# Render a vertical stack: text pages + visuals
	var vbox := vbox_container
	_clear_vbox_content()
	
	# Generate images in memory
	var visuals := _build_visuals_payload()
	var images: Array[Image] = await optical_memory.generate_optical_memory_images(summary_text, visuals)
	
	for img in images:
		var tex := ImageTexture.create_from_image(img)
		var rect := TextureRect.new()
		rect.texture = tex
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		rect.custom_minimum_size = Vector2(0, 400)
		vbox.add_child(rect)
	
	status_label.text = "Rendered %d images in viewport" % images.size()

func _render_single_visual(visual_type: String) -> void:
	var img: Image
	_clear_vbox_content()
	match visual_type:
		"minimap":
			var data := _build_minimap_entities()
			img = await optical_memory.render_scene_minimap_to_image(data)
		"relationships":
			var rel := _build_relationships()
			img = await optical_memory.render_relationship_graph_to_image(rel)
		"timeline":
			var events := _build_timeline_events()
			# Provide a minimal glyph map for nicer visualization in debug
			var glyphs := {
				"scene_enter": "S",
				"action": "A",
				"entity_discovery": "D",
				"entity_change": "C",
				"freeform_input": "F",
				"player_text": "F"
			}
			img = await optical_memory.render_timeline_strip_to_image(events, glyphs)
		"portraits":
			var ents := _build_portrait_entities()
			img = await optical_memory.render_entity_portraits_to_image(ents)
		"chat":
			# Build transcript and render pages with compressed mosaic; preview all
			var transcript := optical_memory.build_chat_transcript_text(world_db.history, 1000)
			var ctx := {"scene_id": world_db.flags.get("current_scene", "")}
			var images: Array[Image] = await optical_memory.render_text_with_mosaic("ChatTranscript", transcript, 1, 3, 2, world_db.flags.get("om_cache", {}), ctx)
			for im in images:
				var t := ImageTexture.create_from_image(im)
				var r := TextureRect.new()
				r.texture = t
				r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				r.size_flags_vertical = Control.SIZE_EXPAND_FILL
				vbox_container.add_child(r)
			# We've already added all images; skip generic single add below
			img = null
		"lore":
			if world_db and world_db.lore_db:
				var corpus_text := _build_lore_corpus_text_local()
				var ctx2 := {"scene_id": world_db.flags.get("current_scene", "")}
				var limages: Array[Image] = await optical_memory.render_text_with_mosaic("LoreBook", corpus_text, 1, 3, 2, world_db.flags.get("om_cache", {}), ctx2)
				for limg in limages:
					var lt := ImageTexture.create_from_image(limg)
					var lr := TextureRect.new()
					lr.texture = lt
					lr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					lr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					lr.size_flags_vertical = Control.SIZE_EXPAND_FILL
					vbox_container.add_child(lr)
				img = null
	
	if img:
		var tex := ImageTexture.create_from_image(img)
		var rect := TextureRect.new()
		rect.texture = tex
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox_container.add_child(rect)
		status_label.text = "Rendered %s" % visual_type

func _build_visuals_payload() -> Dictionary:
	var payload := {}
	payload["minimap_entities"] = _build_minimap_entities()
	payload["relationships"] = _build_relationships()
	payload["timeline_events"] = _build_timeline_events()
	payload["portrait_entities"] = _build_portrait_entities()
	return payload

func _build_minimap_entities() -> Array:
	var out: Array = []
	if world_db == null:
		return out
	var scene_id = world_db.flags.get("current_scene", "")
	var scene = world_db.get_scene(scene_id)
	if scene == null:
		return out
	for e in scene.entities:
		var pos := Vector2(0, 0)
		if e.props.has("pos"):
			var p = e.props.get("pos")
			if typeof(p) == TYPE_VECTOR2:
				pos = p
			elif typeof(p) == TYPE_ARRAY and p.size() >= 2:
				pos = Vector2(float(p[0]), float(p[1]))
		out.append({
			"id": e.id,
			"pos": pos
		})
	return out

## Local equivalent of WorldDB.build_prompt_memory to decouple debug viewer
func _build_prompt_memory_local(target_entity_ids: Array[String]) -> Dictionary:
	var ids: Array[String] = []
	# Include party if available
	if world_db and world_db.party is Array:
		for p in world_db.party:
			if typeof(p) == TYPE_STRING:
				var pid := str(p)
				if not ids.has(pid):
					ids.append(pid)
	# Include targets
	for t in target_entity_ids:
		if typeof(t) == TYPE_STRING and not ids.has(t):
			ids.append(str(t))
	return {
		"history_text": _build_full_chat_log_text_local(1000),
		"lore_text": _build_lore_corpus_text_local(),
		"character_cards": _build_character_cards_local(ids)
	}

func _build_full_chat_log_text_local(max_events: int) -> String:
	if world_db == null or not (world_db.history is Array):
		return ""
	var lines: Array[String] = []
	var n: int = world_db.history.size()
	var start: int = max(0, n - max_events)
	for i in range(start, n):
		var e := world_db.history[i]
		if not (e is Dictionary):
			continue
		var ts: String = str(e.get("ts", ""))
		var kind: String = str(e.get("event", ""))
		if kind == "":
			lines.append(ts)
			continue
		match kind:
			"scene_enter":
				lines.append("[b][%s][/b] Enter scene: %s" % [ts, e.get("scene", "?")])
			"action":
				lines.append("[b][%s][/b] %s → %s [%s]" % [ts, e.get("actor","?"), e.get("target","?"), e.get("verb","?")])
			"freeform_input", "player_text":
				lines.append("[b][%s][/b] Player: %s" % [ts, e.get("text","...")])
			"character_stat_change":
				lines.append("[b][%s][/b] %s.stat %s := %s" % [ts, e.get("character_id","?"), e.get("key", e.get("path","/stats")), str(e.get("value","?"))])
			"entity_discovery":
				lines.append("[b][%s][/b] Discovered %s by %s" % [ts, e.get("entity_id","?"), e.get("actor","?")])
			"entity_change":
				lines.append("[b][%s][/b] %s %s %s" % [ts, e.get("entity_id","?"), e.get("change_type",""), e.get("path","")])
			"lore_unlock":
				lines.append("[b][%s][/b] Lore unlocked: %s" % [ts, e.get("entry_id","?")])
			_:
				lines.append("[b][%s][/b] %s" % [ts, kind])
	return "\n".join(lines)

func _build_lore_corpus_text_local() -> String:
	# Try to use lore_db if available
	if world_db == null or world_db.lore_db == null:
		return ""
	var out: Array[String] = []
	var ldb = world_db.lore_db
	if not ldb.has_method("list_entries"):
		return ""
	var entries = ldb.list_entries()
	for entry in entries:
		if entry == null:
			continue
		# Show ALL entries (ignore unlocks since this is the debugger)
		var title := str(entry.title) if "title" in entry else ""
		var category := str(entry.category) if "category" in entry else ""
		var summary := str(entry.summary) if "summary" in entry else ""
		out.append("[b]%s[/b]%s%s" % [
			title,
			(" (" + category + ")") if category != "" else "",
			("\n" + summary) if summary.strip_edges() != "" else ""
		])
		# Prefer sections if present; include all sections regardless of locks
		if "sections" in entry and entry.sections is Array and entry.sections.size() > 0:
			for s in entry.sections:
				if s:
					var stitle := str(s.title) if "title" in s else ""
					var sbody := str(s.body) if "body" in s else ""
					out.append("[i]%s[/i]\n%s" % [stitle, sbody])
		else:
			# Fallback to article
			if "article" in entry:
				var article := str(entry.article)
				if article.strip_edges() != "":
					out.append(article)
	return "\n\n".join(out)

func _build_character_cards_local(ids: Array[String]) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	if world_db == null:
		return cards
	for cid in ids:
		var card := {}
		card["id"] = str(cid)
		if world_db.has_method("get_character"):
			var ch = world_db.get_character(str(cid))
			if ch:
				card["name"] = ch.name if "name" in ch else ""
				card["description"] = ch.description if "description" in ch else ""
				card["personality"] = ch.personality if "personality" in ch else {}
				card["style"] = ch.style.duplicate() if "style" in ch else {}
				card["traits"] = ch.traits.duplicate() if "traits" in ch else {}
				if world_db.has_method("get_character_stats"):
					card["stats"] = world_db.get_character_stats(str(cid))
				card["first_mes"] = ch.first_mes if "first_mes" in ch else ""
				card["mes_example"] = ch.mes_example if "mes_example" in ch else ""
		cards.append(card)
	return cards

func _build_relationships() -> Dictionary:
	if world_db == null:
		return {}
	# Duplicate to avoid mutating world_db
	var rel_out := {}
	for a in world_db.relationships.keys():
		if world_db.relationships[a] is Dictionary:
			rel_out[a] = world_db.relationships[a].duplicate()
	return rel_out

func _build_timeline_events() -> Array:
	var events: Array = []
	if world_db == null:
		return events
	var cap: int = min(20, world_db.history.size())
	for i in range(world_db.history.size() - cap, world_db.history.size()):
		events.append(world_db.history[i])
	return events

func _build_portrait_entities() -> Array:
	var out: Array = []
	if world_db == null:
		return out
	var scene_id = world_db.flags.get("current_scene", "")
	var scene = world_db.get_scene(scene_id)
	if scene == null:
		return out
	for e in scene.entities:
		out.append({
			"id": e.id,
			"type_name": e.type_name
			# Optional: you can add "texture": Texture2D here if available
		})
	return out
