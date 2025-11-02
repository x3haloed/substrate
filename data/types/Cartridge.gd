extends Resource
class_name Cartridge

# Portable campaign manifest metadata (mirrors manifest.json in .scrt)

@export var id: String = ""
@export var name: String = ""
@export var version: String = "1.0.0"
@export var spec_version: String = "1.0"
@export var engine_version: String = ""
@export var initial_scene_id: String = ""
@export var description: String = ""
@export var author: String = ""

# Contents listed by ids
@export var scenes: Array[String] = []
@export var characters: Array[String] = []
@export var lore_entries: Array[String] = []

# Optional link graph resource path inside the cartridge
@export var links_path: String = ""

# Thumbnail map (size -> path inside archive, e.g., previews/thumbnail_512.png)
@export var thumbnails: Dictionary = {}

func _init():
    if engine_version == "":
        # Best effort default from project settings
        var v = ProjectSettings.get_setting("application/config/version", "")
        engine_version = str(v if v != null else "")

# Construct from a parsed manifest.json dictionary
static func from_manifest_dict(manifest: Dictionary) -> Cartridge:
    var c := Cartridge.new()
    c.id = str(manifest.get("id", ""))
    c.name = str(manifest.get("name", ""))
    c.version = str(manifest.get("version", "1.0.0"))
    c.spec_version = str(manifest.get("spec_version", "1.0"))
    c.engine_version = str(manifest.get("engine_version", c.engine_version))
    c.initial_scene_id = str(manifest.get("initial_scene_id", ""))
    c.description = str(manifest.get("description", ""))
    c.author = str(manifest.get("author", ""))

    # contents.scenes / contents.characters
    var contents = manifest.get("contents", {})
    if contents is Dictionary:
        var s = contents.get("scenes", [])
        if s is Array:
            c.scenes = []
            for sid in s:
                c.scenes.append(str(sid))
        var ch = contents.get("characters", [])
        if ch is Array:
            c.characters = []
            for cid in ch:
                c.characters.append(str(cid))
        var lore_list = contents.get("lore", [])
        if lore_list is Array:
            c.lore_entries = []
            for entry_id in lore_list:
                c.lore_entries.append(str(entry_id))

    # Optional hints
    c.links_path = str(manifest.get("links_path", c.links_path))

    # Optional thumbnails block (non-standard; may be added by exporter)
    var thumbs = manifest.get("thumbnails", {})
    if thumbs is Dictionary:
        c.thumbnails = thumbs.duplicate(true)

    return c

# Serialize back to a manifest.json-compatible structure
func to_manifest_dict() -> Dictionary:
    var contents := {
        "scenes": scenes.duplicate(),
        "characters": characters.duplicate()
    }
    if not lore_entries.is_empty():
        contents["lore"] = lore_entries.duplicate()
    var out := {
        "id": id,
        "name": name,
        "version": version,
        "spec_version": spec_version,
        "engine_version": engine_version,
        "initial_scene_id": initial_scene_id,
        "contents": contents,
    }
    if description != "":
        out["description"] = description
    if author != "":
        out["author"] = author
    if links_path != "":
        out["links_path"] = links_path
    if thumbnails is Dictionary and not thumbnails.is_empty():
        out["thumbnails"] = thumbnails.duplicate(true)
    return out

# Minimal validity check for UI enablement/validation
func is_valid() -> bool:
    return id != "" and name != "" and initial_scene_id != ""

# Return the best thumbnail path inside the archive for a requested size
func get_thumbnail_path(preferred_size: int = 512) -> String:
    if not (thumbnails is Dictionary):
        return ""
    var key = "thumbnail_%d.png" % preferred_size
    if thumbnails.has(key):
        return str(thumbnails[key])
    # Fallback ordering
    var prefs = ["thumbnail_512.png", "thumbnail_1024.png", "thumbnail_256.png"]
    for k in prefs:
        if thumbnails.has(k):
            return str(thumbnails[k])
    return ""
