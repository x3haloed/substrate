extends Resource
class_name LoreEntry

## Canonical lore article backing the Lore Panel and prompt helpers.

const VISIBILITY_ALWAYS := "always"
const VISIBILITY_DISCOVERED := "discovered"
const VISIBILITY_HIDDEN := "hidden"

@export var entry_id: String = ""
@export var title: String = ""
@export var category: String = ""  # npc, item, faction, location, etc.
@export var summary: String = ""
@export var article: String = ""  # Full BBCode-capable body text
@export var related_entity_ids: Array[String] = []  # Entities that link to this entry
@export var default_visibility: String = VISIBILITY_DISCOVERED
@export var unlock_conditions: Array[String] = []  # e.g. ["discover:barkeep", "flag:quest.intro_complete"]
@export var tags: Array[String] = []
@export var notes: Array[String] = []  # Author-facing notes/change log

## Determine whether this lore entry should be visible to the player.
## Accepts optional actor context for future per-party gating.
func is_unlocked(world_db: WorldDB, actor_id: String = "player") -> bool:
	if world_db == null:
		return default_visibility == VISIBILITY_ALWAYS
	
	match default_visibility:
		VISIBILITY_ALWAYS:
			return true
		VISIBILITY_HIDDEN:
			return false
		VISIBILITY_DISCOVERED:
			if unlock_conditions.is_empty():
				# Fall back to basic discovery check: if any related entity is known.
				for entity_id in related_entity_ids:
					if world_db.has_entity_been_discovered(entity_id):
						return true
				# If nothing is linked, treat the entry itself as the key.
				if entry_id != "":
					return world_db.has_entity_been_discovered(entry_id)
				return false
	
	# Evaluate explicit unlock conditions when provided.
	for token in unlock_conditions:
		if _evaluate_condition(token, world_db, actor_id):
			return true
	return false

## Build a minimal prompt-friendly payload for the entry.
func to_prompt_block() -> Dictionary:
	return {
		"id": entry_id,
		"title": title,
		"category": category,
		"summary": summary,
		"article": article,
		"tags": tags.duplicate()
	}

func _evaluate_condition(raw_condition: String, world_db: WorldDB, actor_id: String) -> bool:
	var condition := raw_condition.strip_edges()
	if condition == "":
		return false
	
	if ":" in condition:
		var parts := condition.split(":", false, 1)
		if parts.size() != 2:
			return false
		var kind := parts[0].strip_edges().to_lower()
		var value := parts[1].strip_edges()
		match kind:
			"discover":
				return world_db.has_entity_been_discovered(value)
			"flag":
				return world_db.flags.get(value, false)
			"lore":
				var entry := world_db.get_lore_entry(value)
				return entry != null and entry.is_unlocked(world_db, actor_id)
			"actor":
				return actor_id == value
		return false
	
	# Bare entity id fallback.
	return world_db.has_entity_been_discovered(condition)
