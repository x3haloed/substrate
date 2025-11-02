extends Control

@export var link_graph: LinkGraph

var _node_buttons: Dictionary = {} # id -> Button

func set_link_graph(graph: LinkGraph) -> void:
    link_graph = graph
    _rebuild()

func _ready():
    if link_graph != null:
        _rebuild()

func _rebuild():
    # Clear children
    for child in get_children():
        child.queue_free()
    _node_buttons.clear()
    if link_graph == null:
        queue_redraw()
        return
    # Simple circular layout
    var n: int = max(1, link_graph.nodes.size())
    var center: Vector2 = get_size() * 0.5
    var radius: float = min(center.x, center.y) - 80.0
    var i := 0
    for node in link_graph.nodes:
        var id := str(node.get("id", ""))
        var label := id
        var t := str(node.get("type", ""))
        if t == "open_area":
            label = "[OA] " + str(node.get("ref_id", id))
        var angle := (TAU * float(i)) / float(n)
        var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
        var btn := Button.new()
        btn.text = label
        btn.position = pos - Vector2(80, 20)
        btn.custom_minimum_size = Vector2(160, 40)
        add_child(btn)
        _node_buttons[id] = btn
        i += 1
    queue_redraw()

func _draw():
    if link_graph == null:
        return
    # Draw edges between centers
    for e in link_graph.edges:
        var from_id := str(e.get("from", ""))
        var to_id := str(e.get("to", ""))
        if not _node_buttons.has(from_id) or not _node_buttons.has(to_id):
            continue
        var a: Button = _node_buttons[from_id]
        var b: Button = _node_buttons[to_id]
        var p1: Vector2 = a.position + a.size * 0.5
        var p2: Vector2 = b.position + b.size * 0.5
        draw_line(p1, p2, Color(0.8, 0.8, 0.8, 0.6), 2.0)


