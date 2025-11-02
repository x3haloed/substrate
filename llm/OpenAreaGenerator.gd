extends RefCounted
class_name OpenAreaGenerator

var prompt_engine: PromptEngine
var world_db: WorldDB

func _init(p_prompt_engine: PromptEngine, p_world_db: WorldDB):
    prompt_engine = p_prompt_engine
    world_db = p_world_db

## Generate a concrete SceneGraph for an OpenAreaDef and persist/register it.
## Returns the generated scene_id or "" on failure.
func generate(def: OpenAreaDef, cartridge_id: String = "default", seed_value: String = "") -> String:
    if def == null or not def.is_valid():
        push_error("OpenAreaGenerator: invalid OpenAreaDef")
        return ""
    var scene_json: Dictionary = await _request_generation(def, seed_value) as Dictionary
    if scene_json == null:
        return ""
    var sg := _scene_graph_from_json(scene_json)
    if sg == null:
        return ""
    # Deterministic id
    var sid := _derive_scene_id(def, seed_value)
    sg.scene_id = sid
    # Persist
    var save_path := _persist_scenegraph(sg, cartridge_id)
    if save_path == "":
        return ""
    # Register
    world_db.register_generated_scene(sid, save_path)
    return sid

func _request_generation(def: OpenAreaDef, seed_value: String):
    var world_context := {
        "flags": world_db.flags,
        "recent": world_db.history.slice(max(0, world_db.history.size() - 8), world_db.history.size())
    }
    var instruction := """
You are a scene designer. Produce a single JSON object describing a concrete SceneGraph for an open area.

Fields:
- scene_id: string (slug)
- description: string (2-4 sentences atmospheric)
- entities: array of entities; each:
  { id: string, type_name: "npc"|"item"|"exit"|"portal"|..., verbs: string[], tags: string[], props: object, state: object, contents: string[] }

Rules:
- Include at least 4 entities; include at least one meaningful interactable and one potential obstacle.
- Do NOT invent characters outside the cartridge unless plausible. Prefer items/exits.
- If this open area should complete on discovery/interaction, include an entity that satisfies the completion condition.
- Exits: use type_name "exit" with verbs including "move" and props.leads if known.
- Portals to open areas: type_name "portal" with props.kind="open_area" and props.area_id.
- IDs must be slugs (a-z, underscores).
"""
    var user := {
        "open_area": {
            "area_id": def.area_id,
            "title": def.title,
            "design_brief": def.design_brief,
            "constraints": def.constraints,
            "completion": def.completion
        },
        "world": world_context,
        "seed": seed_value
    }
    var msgs := [
        {"role": "system", "content": instruction},
        {"role": "user", "content": JSON.stringify(user, "\t")}
    ]
    var schema := {
        "type": "object",
        "properties": {
            "scene_id": {"type": "string"},
            "description": {"type": "string"},
            "entities": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "string"},
                        "type_name": {"type": "string"},
                        "verbs": {"type": "array", "items": {"type": "string"}},
                        "tags": {"type": "array", "items": {"type": "string"}},
                        "props": {"type": "object"},
                        "state": {"type": "object"},
                        "contents": {"type": "array", "items": {"type": "string"}}
                    },
                    "required": ["id", "type_name", "verbs", "props", "state", "contents"],
                    "additionalProperties": true
                }
            }
        },
        "required": ["description", "entities"],
        "additionalProperties": true
    }
    var text := await prompt_engine.llm_client.make_request(msgs, "", schema, {"source": "director"})
    if text == "":
        return null
    var parser := JSON.new()
    if parser.parse(text) != OK or not (parser.data is Dictionary):
        return null
    return parser.data

func _scene_graph_from_json(data: Dictionary) -> SceneGraph:
    var sg := SceneGraph.new()
    sg.scene_id = str(data.get("scene_id", ""))
    sg.description = str(data.get("description", ""))
    sg.entities = []
    var ents = data.get("entities", [])
    if ents is Array:
        for e in ents:
            if not (e is Dictionary):
                continue
            var ent := Entity.new()
            ent.id = str(e.get("id", ""))
            ent.type_name = str(e.get("type_name", ""))
            ent.verbs = []
            var v = e.get("verbs", [])
            if v is Array:
                for s in v:
                    ent.verbs.append(str(s))
            var tags = e.get("tags", [])
            if tags is Array:
                ent.tags = tags.duplicate()
            var props = e.get("props", {})
            if props is Dictionary:
                ent.props = props.duplicate(true)
            var state = e.get("state", {})
            if state is Dictionary:
                ent.state = state.duplicate(true)
            var contents = e.get("contents", [])
            if contents is Array:
                ent.contents = contents.duplicate()
            sg.entities.append(ent)
    return sg

func _persist_scenegraph(sg: SceneGraph, cartridge_id: String) -> String:
    var base := "user://campaigns/%s/generated" % cartridge_id
    DirAccess.make_dir_recursive_absolute(base)
    var path := "%s/%s.tres" % [base, sg.scene_id]
    var err := ResourceSaver.save(sg, path)
    if err != OK:
        push_error("OpenAreaGenerator: failed to save scene to " + path)
        return ""
    return path

func _derive_scene_id(def: OpenAreaDef, seed_value: String) -> String:
    var s := def.area_id + "|" + JSON.stringify(world_db.flags) + "|" + seed_value
    var ctx := HashingContext.new()
    ctx.start(HashingContext.HASH_SHA256)
    ctx.update(s.to_utf8_buffer())
    var h: PackedByteArray = ctx.finish()
    var hex := h.hex_encode().substr(0, 8)
    return "oa.%s.%s" % [def.area_id, hex]


