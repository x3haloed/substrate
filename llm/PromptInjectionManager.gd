# New file: res://llm/PromptInjectionManager.gd
extends RefCounted
class_name PromptInjectionManager

enum Position { BEFORE_SYSTEM, AFTER_SYSTEM, IN_CHAT }

class LayerDef:
	var id: String
	var scope: String            # "narrator" | "director" | "npc" | "freeform" | "all"
	var position: int            # Position.*
	var role: String = "system"  # "system" | "user" | "assistant"
	var priority: int = 0        # lower runs first within the same position
	var anchor_index: int = -1   # for IN_CHAT: -1 = prepend to turns, large = append
	var enabled: bool = true
	var content: Variant         # String | Callable(context) -> Dictionary|String

func _to_msg(role: String, content: Variant, context: Dictionary) -> Dictionary:
	var txt := ""
	if typeof(content) == TYPE_STRING:
		txt = str(content)
	elif typeof(content) == TYPE_CALLABLE:
		var v = content.call(context)
		if typeof(v) == TYPE_DICTIONARY: # full multimodal msg already
			return v
		txt = str(v)
	return {"role": role, "content": txt}

func apply_layers(scope: String, base_messages: Array[Dictionary], context: Dictionary, layers: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var before := []
	var after := []
	var in_chat := []
	for l in layers:
		if not l.enabled: continue
		if l.scope != "all" and l.scope != scope: continue
		match l.position:
			Position.BEFORE_SYSTEM: before.append(l)
			Position.AFTER_SYSTEM: after.append(l)
			Position.IN_CHAT: in_chat.append(l)
	before.sort_custom(func(a, b): return a.priority < b.priority)
	after.sort_custom(func(a, b): return a.priority < b.priority)
	in_chat.sort_custom(func(a, b): return a.priority < b.priority)

	# inject before: ahead of the first message
	for l in before:
		result.append(_to_msg(l.role, l.content, context))
	result.append_array(base_messages)

	# inject after: immediately after the first system (or at the start if none)
	if after.size() > 0:
		var inserted: Array[Dictionary] = []
		for l in after:
			inserted.append(_to_msg(l.role, l.content, context))
		var first_system_idx := -1
		for i in result.size():
			if str(result[i].get("role", "")) == "system":
				first_system_idx = i
				break
		if first_system_idx == -1:
			# no system in base; treat as head insertion after pre-injected
			var new_result: Array[Dictionary] = []
			new_result.append_array(inserted)
			new_result.append_array(result)
			result = new_result
		else:
			var new_result2: Array[Dictionary] = []
			new_result2.append_array(result.slice(0, first_system_idx + 1))
			new_result2.append_array(inserted)
			new_result2.append_array(result.slice(first_system_idx + 1))
			result = new_result2

	# inject in-chat: relative to non-system turns
	if in_chat.size() > 0:
		var head: Array[Dictionary] = []
		var tail: Array[Dictionary] = []
		# split: everything up to the first non-system is head
		var split_idx := result.size()
		for i in result.size():
			if str(result[i].get("role", "")) != "system":
				split_idx = i
				break
		head.clear()
		head.append_array(result.slice(0, split_idx))
		tail.clear()
		tail.append_array(result.slice(split_idx, result.size()))

		var inserted_turns: Array[Dictionary] = []
		for l in in_chat:
			var m = _to_msg(l.role, l.content, context)
			inserted_turns.append(m)
		if inserted_turns.size() > 0:
			if in_chat[0].anchor_index <= 0:
				var new_tail: Array[Dictionary] = []
				new_tail.append_array(inserted_turns)
				new_tail.append_array(tail)
				tail = new_tail
			else:
				var idx = min(in_chat[0].anchor_index, tail.size())
				var new_tail2: Array[Dictionary] = []
				new_tail2.append_array(tail.slice(0, idx))
				new_tail2.append_array(inserted_turns)
				new_tail2.append_array(tail.slice(idx, tail.size()))
				tail = new_tail2
		var combined: Array[Dictionary] = []
		combined.append_array(head)
		combined.append_array(tail)
		result = combined

	return result
