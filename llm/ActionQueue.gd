extends RefCounted
class_name ActionQueue

## Manages initiative order and action queue for turn-based play

class QueuedAction:
	var actor_id: String
	var priority: int  # Lower = earlier
	var can_interject: bool
	
	func _init(p_actor_id: String, p_priority: int = 0, p_can_interject: bool = false):
		actor_id = p_actor_id
		priority = p_priority
		can_interject = p_can_interject

var queue: Array[QueuedAction] = []
var current_turn: int = 0

func add_actor(actor_id: String, priority: int = 0, can_interject: bool = false):
	# Remove if already exists
	remove_actor(actor_id)
	queue.append(QueuedAction.new(actor_id, priority, can_interject))
	_sort_queue()

func set_actor_priority(actor_id: String, priority: int):
	# Update priority for existing actor
	for action in queue:
		if action.actor_id == actor_id:
			action.priority = priority
			_sort_queue()
			return
	# If not found, add with new priority
	add_actor(actor_id, priority, false)

func remove_actor(actor_id: String):
	for i in range(queue.size() - 1, -1, -1):
		if queue[i].actor_id == actor_id:
			queue.remove_at(i)

func clear():
	queue.clear()
	current_turn = 0

func get_next_actor() -> String:
	if queue.is_empty():
		return ""
	
	var idx = current_turn % queue.size()
	return queue[idx].actor_id

func advance_turn():
	if not queue.is_empty():
		current_turn += 1

func get_queue_preview(count: int = 3) -> Array[String]:
	# Returns preview of next N actors
	var result: Array[String] = []
	if queue.is_empty():
		return result
	
	var start_idx = current_turn % queue.size()
	for i in range(count):
		var idx = (start_idx + i) % queue.size()
		result.append(queue[idx].actor_id)
	
	return result

func get_interjecting_actors() -> Array[String]:
	# Returns actors who can interject before the current turn
	var result: Array[String] = []
	var current_idx = current_turn % queue.size() if not queue.is_empty() else 0
	
	for i in range(queue.size()):
		if i != current_idx and queue[i].can_interject:
			result.append(queue[i].actor_id)
	
	return result

func _sort_queue():
	# Sort by priority (lower priority = earlier in queue)
	queue.sort_custom(func(a, b): return a.priority < b.priority)

