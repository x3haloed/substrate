extends HBoxContainer
class_name TypingIndicator

## Animated three-dot typing indicator with a speaker label

@onready var dot_1: Panel = $Dots/Dot1
@onready var dot_2: Panel = $Dots/Dot2
@onready var dot_3: Panel = $Dots/Dot3
@onready var label: Label = $Label

var _tween: Tween

func _ready():
	visible = false
	_apply_dot_styles()

func start(source: String, name_hint: String = "") -> void:
	var who := _resolve_label(source, name_hint)
	label.text = who + " is typing…"
	visible = true
	_start_animation()

func stop() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	visible = false

func _resolve_label(source: String, name_hint: String) -> String:
	match source:
		"narrator":
			return "Narrator"
		"director":
			return "Director"
		"npc":
			if name_hint != "":
				return name_hint
			return "NPC"
		_:
			return "System"

func _apply_dot_styles() -> void:
	# Create circular style boxes for each dot
	for p in [dot_1, dot_2, dot_3]:
		if p == null:
			continue
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.78, 0.80, 0.86, 1)
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		p.add_theme_stylebox_override("panel", sb)

func _start_animation() -> void:
	if _tween:
		_tween.kill()
	# Pulse the alpha of the dots with slight phase offsets
	_tween = create_tween()
	_tween.set_loops()
	_tween.tween_property(dot_1, "modulate:a", 0.25, 0.35).from(1.0)
	_tween.parallel().tween_property(dot_2, "modulate:a", 0.25, 0.35).from(0.6).set_delay(0.12)
	_tween.parallel().tween_property(dot_3, "modulate:a", 0.25, 0.35).from(0.4).set_delay(0.24)
	_tween.tween_interval(0.15)
	_tween.tween_property(dot_1, "modulate:a", 1.0, 0.35).from(0.25)
	_tween.parallel().tween_property(dot_2, "modulate:a", 1.0, 0.35).from(0.25).set_delay(0.12)
	_tween.parallel().tween_property(dot_3, "modulate:a", 1.0, 0.35).from(0.25).set_delay(0.24)
