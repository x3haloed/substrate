extends Control
class_name ActionQueuePanel

## Displays the action queue showing who's up next

@onready var current_label: Label = $VBox/CurrentLabel
@onready var queue_label: Label = $VBox/QueueLabel

func _ready():
	# Hide by default, will be shown when queue updates
	visible = false

func update_queue(queue_preview: Array[String], current_actor: String):
	if queue_preview.is_empty():
		visible = false
		return
	
	visible = true
	
	# Format current actor
	var current_display = current_actor.capitalize()
	if current_actor == "player":
		current_display = "Your Turn"
	current_label.text = "Current: " + current_display
	
	# Format queue preview
	var queue_text = "Up Next: "
	var queue_items: Array[String] = []
	for i in range(1, queue_preview.size()):
		var actor = queue_preview[i]
		if actor == "player":
			queue_items.append("You")
		else:
			queue_items.append(actor.capitalize())
	
	if queue_items.size() > 0:
		queue_label.text = queue_text + ", ".join(queue_items)
	else:
		queue_label.text = ""
