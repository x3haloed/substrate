extends RefCounted
class_name CampaignValidator

## Validate a world database and return a list of issue dictionaries
## Issue: { type: String, message: String, data: Dictionary }
func validate_world(world: WorldDB) -> Array[Dictionary]:
    var issues: Array[Dictionary] = []
    if world == null:
        return issues

    # 1) Broken exits: props.leads points to missing scene id
    for sid in world.scenes.keys():
        var scene := world.get_scene(sid)
        if scene == null:
            issues.append({"type": "scene_load_error", "message": "Failed to load scene", "data": {"scene_id": sid}})
            continue
        for e in scene.entities:
            if e.type_name == "exit":
                var leads := str(e.props.get("leads", ""))
                if leads == "":
                    issues.append({"type": "exit_missing_target", "message": "Exit missing props.leads", "data": {"scene_id": sid, "entity_id": e.id}})
                elif not world.scenes.has(leads):
                    issues.append({"type": "exit_broken_link", "message": "Exit leads to missing scene", "data": {"scene_id": sid, "entity_id": e.id, "leads": leads}})

    # 2) Missing characters referenced by NPC entities (by id)
    for sid2 in world.scenes.keys():
        var sc := world.get_scene(sid2)
        if sc == null:
            continue
        for en in sc.entities:
            if en.type_name == "npc":
                if not world.characters.has(en.id):
                    issues.append({"type": "missing_character", "message": "NPC entity has no CharacterProfile in world.characters", "data": {"scene_id": sid2, "npc_id": en.id}})

    # 3) Unreachable scenes from initial_scene_id via exits
    var start := str(world.flags.get("initial_scene_id", ""))
    if start != "":
        var reachable := _reachable_scenes_via_exits(world, start)
        for sid3 in world.scenes.keys():
            if not (sid3 in reachable):
                issues.append({"type": "unreachable_scene", "message": "Scene is not reachable from initial_scene_id via exits", "data": {"scene_id": sid3}})

    return issues

func _reachable_scenes_via_exits(world: WorldDB, start: String) -> Array[String]:
    var visited: Dictionary = {}
    var queue: Array[String] = [start]
    while not queue.is_empty():
        var sid: String = queue.pop_front()
        if visited.has(sid):
            continue
        visited[sid] = true
        var sc := world.get_scene(sid)
        if sc == null:
            continue
        for e in sc.entities:
            if e.type_name == "exit":
                var leads := str(e.props.get("leads", ""))
                if leads != "" and world.scenes.has(leads) and not visited.has(leads):
                    queue.append(leads)
    return visited.keys()


