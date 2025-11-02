extends Control
class_name ChoicePanel

## Auto-generated action buttons from scene verbs

signal action_selected(verb: String, target: String)

@onready var choice_container: GridContainer = $VBox/ScrollContainer/ChoiceContainer
@onready var travel_dropdown: OptionButton = $VBox/TravelRow/TravelDropdown

func clear_choices():
	for child in choice_container.get_children():
		child.queue_free()

func set_choices(choices: Array[UIChoice]):
	clear_choices()

	for choice in choices:
		# Filter out talk actions; chat UI handles conversations
		if choice.verb == "talk":
			continue
		var button = Button.new()
		button.text = choice.get_display_label()
		button.pressed.connect(func(): action_selected.emit(choice.verb, choice.target))
		choice_container.add_child(button)

func set_travel_options(exits: Array[Dictionary]):
	# exits: [{ label: String, target: String }]
	travel_dropdown.clear()
	if exits.is_empty():
		travel_dropdown.visible = false
		return
	for e in exits:
		travel_dropdown.add_item(str(e.get("label", e.get("target", ""))))
		travel_dropdown.set_item_metadata(travel_dropdown.item_count - 1, e.get("target", ""))
	travel_dropdown.visible = true
	# Connect only once
	if not travel_dropdown.is_connected("item_selected", Callable(self, "_on_travel_selected")):
		travel_dropdown.item_selected.connect(_on_travel_selected)

func _on_travel_selected(index: int):
	var target := str(travel_dropdown.get_item_metadata(index))
	if target != "":
		action_selected.emit("move", target)
