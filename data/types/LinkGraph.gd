extends Resource
class_name LinkGraph

@export var nodes: Array[Dictionary] = [] # { id: String, type: "scene"|"open_area", ref_id: String }
@export var edges: Array[Dictionary] = [] # { from: String, to: String, label: String }

func add_scene_node(scene_id: String) -> void:
    _add_node({"id": scene_id, "type": "scene", "ref_id": scene_id})

func add_open_area_node(area_id: String) -> void:
    _add_node({"id": "oa_" + area_id, "type": "open_area", "ref_id": area_id})

func link(from_id: String, to_id: String, label: String = "") -> void:
    edges.append({"from": from_id, "to": to_id, "label": label})

func _add_node(n: Dictionary) -> void:
    # Avoid duplicates by id
    for existing in nodes:
        if str(existing.get("id", "")) == str(n.get("id", "")):
            return
    nodes.append(n)

func get_neighbors(id: String) -> Array[String]:
    var result: Array[String] = []
    for e in edges:
        if e.get("from", "") == id:
            result.append(str(e.get("to", "")))
    return result


