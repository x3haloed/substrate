extends Resource
class_name Inventory

signal inv_changed()
signal item_used(item_stack: ItemStack)
signal item_added(item_stack: ItemStack)
signal item_removed(item_stack: ItemStack)

@export var max_slots: int = 24
@export var max_carry_weight_kg: float = 25.0
@export var slots: Array[ItemStack] = []

func get_total_weight_kg() -> float:
    var total := 0.0
    for s in slots:
        if s != null:
            total += s.total_weight_kg()
    return total

func has_free_slot() -> bool:
    return slots.size() < max_slots

func find_stack_indices(item: ItemDef) -> Array[int]:
    var indices: Array[int] = []
    for i in slots.size():
        var s := slots[i]
        if s != null and s.item == item:
            indices.append(i)
    return indices

func try_add_stack(incoming: ItemStack) -> bool:
    if incoming == null or incoming.is_empty():
        return false
    if not can_accept(incoming):
        return false
    # Merge into existing stacks first
    if incoming.item.is_stackable():
        for s in slots:
            if s != null and s.can_merge(incoming):
                s.merge_from(incoming)
                if incoming.is_empty():
                    emit_signal("inv_changed")
                    emit_signal("item_added", s)
                    return true
    # Place leftovers into new slots while capacity allows
    while not incoming.is_empty():
        if not has_free_slot():
            return false
        var to_place := int(min(incoming.quantity, incoming.item.max_stack))
        var new_stack := ItemStack.new()
        new_stack.item = incoming.item
        new_stack.quantity = to_place
        incoming.quantity -= to_place
        slots.append(new_stack)
        emit_signal("item_added", new_stack)
    emit_signal("inv_changed")
    return true

func remove_item(item: ItemDef, amount: int) -> int:
    if amount <= 0:
        return 0
    var removed := 0
    for i in range(slots.size() - 1, -1, -1):
        var s := slots[i]
        if s == null or s.item != item:
            continue
        var take := int(min(amount - removed, s.quantity))
        s.quantity -= take
        removed += take
        if s.quantity <= 0:
            slots.remove_at(i)
        if removed >= amount:
            break
    if removed > 0:
        emit_signal("inv_changed")
    return removed

func can_accept(stack: ItemStack) -> bool:
    if stack == null or stack.is_empty():
        return false
    if get_total_weight_kg() + stack.total_weight_kg() > max_carry_weight_kg:
        return false
    if not has_free_slot():
        # might still merge; do a quick merge feasibility check
        if not stack.item.is_stackable():
            return false
        for s in slots:
            if s != null and s.can_merge(stack) and s.quantity < s.item.max_stack:
                return true
        return false
    return true


