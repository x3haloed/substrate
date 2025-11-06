extends Resource
class_name LoreSection

## A progressive subsection of a lore entry with independent unlock conditions.

const VISIBILITY_ALWAYS := "always"
const VISIBILITY_DISCOVERED := "discovered"
const VISIBILITY_HIDDEN := "hidden"

@export var section_id: String = ""
@export var title: String = ""
@export var body: String = ""  # BBCode-capable text
@export var default_visibility: String = VISIBILITY_DISCOVERED
@export var unlock_conditions: Array[String] = []  # e.g. ["discover:barkeep", "flag:quest.intro_complete"]
@export var tags: Array[String] = []

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
                return true
    for token in unlock_conditions:
        if _evaluate_condition(token, world_db, actor_id):
            return true
    return false

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
    return world_db.has_entity_been_discovered(condition)


