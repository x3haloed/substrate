extends RefCounted
class_name CardRepository

## Manages the user's character card collection under user://

const BUILTIN_CHAR_DIR: String = "res://data/characters/"
const REPO_DIR: String = "user://characters/"

static func get_repo_dir() -> String:
    return REPO_DIR

static func ensure_repo_dir() -> void:
    # Create the repo directory if it doesn't exist
    if not DirAccess.dir_exists_absolute(REPO_DIR):
        # Make parent (user://) and nested path as needed
        var mk_err := DirAccess.make_dir_recursive_absolute(REPO_DIR)
        if mk_err != OK:
            push_error("Failed to create card repository directory: " + REPO_DIR)

static func _slugify(text: String) -> String:
    var s := text.to_lower()
    var rx := RegEx.new()
    rx.compile("[^a-z0-9]+")
    s = rx.sub(s, "_", true)
    # Trim underscores
    while s.begins_with("_"):
        s = s.substr(1)
    while s.ends_with("_") and s.length() > 0:
        s = s.left(s.length() - 1)
    if s == "":
        s = "card"
    return s

static func _card_key(profile: CharacterProfile) -> String:
    return "%s|%s" % [profile.name, profile.character_version]

static func _index_repo_keys() -> Dictionary:
    # key => filename (not full path)
    var index: Dictionary = {}
    var dir := DirAccess.open(REPO_DIR)
    if dir:
        dir.list_dir_begin()
        var fn := dir.get_next()
        while fn != "":
            if not dir.current_is_dir() and fn.ends_with(".tres"):
                var full := REPO_DIR + fn
                var res := load(full)
                if res is CharacterProfile:
                    var key := _card_key(res)
                    index[key] = fn
            fn = dir.get_next()
        dir.list_dir_end()
    return index

static func list_card_paths() -> Array[String]:
    ensure_repo_dir()
    var paths: Array[String] = []
    var dir := DirAccess.open(REPO_DIR)
    if dir:
        dir.list_dir_begin()
        var fn := dir.get_next()
        while fn != "":
            if not dir.current_is_dir() and fn.ends_with(".tres"):
                paths.append(REPO_DIR + fn)
            fn = dir.get_next()
        dir.list_dir_end()
    return paths

static func load_cards() -> Array[CharacterProfile]:
    var cards: Array[CharacterProfile] = []
    for path in list_card_paths():
        var res := load(path)
        if res is CharacterProfile:
            cards.append(res)
    return cards

static func find_in_repo(name: String, character_version: String) -> String:
    var dir := DirAccess.open(REPO_DIR)
    if not dir:
        return ""
    dir.list_dir_begin()
    var fn := dir.get_next()
    while fn != "":
        if not dir.current_is_dir() and fn.ends_with(".tres"):
            var full := REPO_DIR + fn
            var res := load(full)
            if res is CharacterProfile:
                if res.name == name and res.character_version == character_version:
                    dir.list_dir_end()
                    return full
        fn = dir.get_next()
    dir.list_dir_end()
    return ""

static func _unique_filename(base_name: String, version: String) -> String:
    var slug := _slugify(base_name)
    var stem := "%s--v%s" % [slug, version]
    var candidate := "%s.tres" % stem
    var idx := 2
    while FileAccess.file_exists(REPO_DIR + candidate):
        candidate = "%s-%d.tres" % [stem, idx]
        idx += 1
    return candidate

static func add_card_to_repo(profile: CharacterProfile) -> String:
    ensure_repo_dir()
    var existing := find_in_repo(profile.name, profile.character_version)
    if existing != "":
        return existing
    var filename := _unique_filename(profile.name, profile.character_version)
    var dest := REPO_DIR + filename
    var err := ResourceSaver.save(profile, dest)
    if err != OK:
        push_error("Failed to save character to repo: %s (err=%d)" % [dest, err])
        return ""
    return dest

static func sync_builtin_cards_to_repo() -> void:
    ensure_repo_dir()
    var repo_index := _index_repo_keys()
    var src_dir := DirAccess.open(BUILTIN_CHAR_DIR)
    if not src_dir:
        return
    src_dir.list_dir_begin()
    var fn := src_dir.get_next()
    while fn != "":
        if not src_dir.current_is_dir() and fn.ends_with(".tres"):
            var full := BUILTIN_CHAR_DIR + fn
            var res := load(full)
            if res is CharacterProfile:
                var key := _card_key(res)
                if not repo_index.has(key):
                    add_card_to_repo(res)
        fn = src_dir.get_next()
    src_dir.list_dir_end()


