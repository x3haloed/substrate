extends Control
class_name ChoicePanel

## Auto-generated action buttons from scene verbs

signal action_selected(verb: String, target: String)

@onready var choice_container: VBoxContainer = $VBox/ScrollContainer/ChoiceContainer

func clear_choices():
	for child in choice_container.get_children():
		child.queue_free()

func set_choices(choices: Array[UIChoice]):
	clear_choices()
	
	for choice in choices:
		var button = Button.new()
		button.text = choice.get_display_label()
		button.pressed.connect(func(): action_selected.emit(choice.verb, choice.target))
		choice_container.add_child(button)

