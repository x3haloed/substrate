extends Node
class_name OpticalMemory

## Generates rasterized summary pages for VLM attachment (optical memory sheets)

var world_db: WorldDB

func _init(p_world_db: WorldDB):
	world_db = p_world_db

## Generate a session summary as text (can be rasterized to PNG)
func generate_session_summary(scene_id: String = "", max_length: int = 5000) -> String:
	var summary = ""
	
	# Current scene context
	var current_scene_id = scene_id if scene_id != "" else world_db.flags.get("current_scene", "")
	var scene = world_db.get_scene(current_scene_id)
	
	summary += "=== SESSION SUMMARY ===\n\n"
	
	if scene:
		summary += "Current Scene: " + scene.scene_id + "\n"
		summary += "Description: " + scene.description + "\n\n"
		
		summary += "Entities in Scene:\n"
		for entity in scene.entities:
			summary += "  • " + entity.id + " (" + entity.type_name + ")\n"
			if entity.props.size() > 0:
				for key in entity.props.keys():
					summary += "    - " + key + ": " + str(entity.props[key]) + "\n"
	
	summary += "\n=== RECENT HISTORY ===\n\n"
	
	# Get last 20 history entries
	var recent_history = []
	for i in range(world_db.history.size() - 1, max(0, world_db.history.size() - 20) - 1, -1):
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
	
	summary += "\n=== ENTITY DISCOVERY TRACKING ===\n\n"
	
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
	
	summary += "\n=== RELATIONSHIPS ===\n\n"
	
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

## Generate an optical memory sheet by rendering text to a Viewport and saving as PNG
## Returns the path to the saved PNG file
func generate_optical_memory_png(output_dir: String, filename: String = "memory_sheet.png") -> String:
	var summary_text = generate_session_summary()
	
	# Create a temporary viewport to render the text (SubViewport in Godot 4)
	var viewport = SubViewport.new()
	viewport.size = Vector2i(1024, 2048)  # Memory sheet size
	viewport.transparent_background = true
	viewport.update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	
	# Create a label with the summary
	var label = RichTextLabel.new()
	label.size = Vector2(1024, 2048)
	label.fit_content = true
	label.bbcode_enabled = false  # Plain text for memory sheets
	label.text = summary_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	viewport.add_child(label)
	
	# Force render
	await RenderingServer.frame_post_draw
	viewport.update_mode = SubViewport.UPDATE_ONCE
	
	# Get the image
	var image = viewport.get_texture().get_image()
	
	# Ensure output directory exists
	var dir = DirAccess.open("user://")
	if not dir.dir_exists(output_dir):
		dir.make_dir_recursive(output_dir)
	
	# Save PNG
	var output_path = output_dir + "/" + filename
	var error = image.save_png(output_path)
	
	# Cleanup
	label.queue_free()
	viewport.queue_free()
	
	if error != OK:
		push_error("Failed to save optical memory sheet: " + str(error))
		return ""
	
	print("Optical memory sheet saved to: " + output_path)
	return output_path

## Generate a lightweight text summary (for inclusion in prompts)
func generate_prompt_summary(max_entities: int = 10) -> String:
	var summary = generate_session_summary("", 2000)
	return summary

