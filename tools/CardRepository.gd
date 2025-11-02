extends RefCounted
class_name CardRepository

## Manages the user's character card collections under user://, with separate
## namespaces for player and editor workflows.

const BUILTIN_CHAR_DIR: String = "res://data/characters/"

enum StoreKind { PLAYER, EDITOR }

const PLAYER_REPO_DIR: String = "user://player/characters/"
const EDITOR_REPO_DIR: String = "user://editor/characters/"

static func get_repo_dir(kind: int = StoreKind.PLAYER) -> String:
    return PLAYER_REPO_DIR if kind == StoreKind.PLAYER else EDITOR_REPO_DIR

static func ensure_repo_dir(kind: int = StoreKind.PLAYER) -> void:
    # Create the repo directory if it doesn't exist
    var repo_dir := get_repo_dir(kind)
    if not DirAccess.dir_exists_absolute(repo_dir):
        # Make parent (user://) and nested path as needed
        var mk_err := DirAccess.make_dir_recursive_absolute(repo_dir)
        if mk_err != OK:
            push_error("Failed to create card repository directory: " + repo_dir)

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

static func _index_repo_keys(kind: int = StoreKind.PLAYER) -> Dictionary:
    # key => filename (not full path)
    var index: Dictionary = {}
    var repo_dir := get_repo_dir(kind)
    var dir := DirAccess.open(repo_dir)
    if dir:
        dir.list_dir_begin()
        var fn := dir.get_next()
        while fn != "":
            if not dir.current_is_dir() and fn.ends_with(".tres"):
                var full := repo_dir + fn
                var res := load(full)
                if res is CharacterProfile:
                    var key := _card_key(res)
                    index[key] = fn
            fn = dir.get_next()
        dir.list_dir_end()
    return index

static func list_card_paths(kind: int = StoreKind.PLAYER) -> Array[String]:
    ensure_repo_dir(kind)
    var paths: Array[String] = []
    var repo_dir := get_repo_dir(kind)
    var dir := DirAccess.open(repo_dir)
    if dir:
        dir.list_dir_begin()
        var fn := dir.get_next()
        while fn != "":
            if not dir.current_is_dir() and fn.ends_with(".tres"):
                paths.append(repo_dir + fn)
            fn = dir.get_next()
        dir.list_dir_end()
    return paths

static func load_cards(kind: int = StoreKind.PLAYER) -> Array[CharacterProfile]:
    var cards: Array[CharacterProfile] = []
    for path in list_card_paths(kind):
        var res := load(path)
        if res is CharacterProfile:
            cards.append(res)
    return cards

static func find_in_repo(name: String, character_version: String, kind: int = StoreKind.PLAYER) -> String:
    var repo_dir := get_repo_dir(kind)
    var dir := DirAccess.open(repo_dir)
    if not dir:
        return ""
    dir.list_dir_begin()
    var fn := dir.get_next()
    while fn != "":
        if not dir.current_is_dir() and fn.ends_with(".tres"):
            var full := repo_dir + fn
            var res := load(full)
            if res is CharacterProfile:
                if res.name == name and res.character_version == character_version:
                    dir.list_dir_end()
                    return full
        fn = dir.get_next()
    dir.list_dir_end()
    return ""

static func _unique_filename(base_name: String, version: String, kind: int = StoreKind.PLAYER) -> String:
    var slug := _slugify(base_name)
    var stem := "%s--v%s" % [slug, version]
    var candidate := "%s.tres" % stem
    var idx := 2
    var repo_dir := get_repo_dir(kind)
    while FileAccess.file_exists(repo_dir + candidate):
        candidate = "%s-%d.tres" % [stem, idx]
        idx += 1
    return candidate

static func add_card_to_repo(profile: CharacterProfile, kind: int = StoreKind.PLAYER) -> String:
    ensure_repo_dir(kind)
    var existing := find_in_repo(profile.name, profile.character_version, kind)
    if existing != "":
        return existing
    var filename := _unique_filename(profile.name, profile.character_version, kind)
    var repo_dir := get_repo_dir(kind)
    var dest := repo_dir + filename
    var err := ResourceSaver.save(profile, dest)
    if err != OK:
        push_error("Failed to save character to repo: %s (err=%d)" % [dest, err])
        return ""
    return dest

static func sync_builtin_cards_to_repo(kind: int = StoreKind.PLAYER) -> void:
    ensure_repo_dir(kind)
    var repo_index := _index_repo_keys(kind)
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
                    add_card_to_repo(res, kind)
        fn = src_dir.get_next()
    src_dir.list_dir_end()


