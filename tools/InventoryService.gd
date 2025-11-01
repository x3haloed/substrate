extends Node
class_name InventoryService

func transfer_between_inventories(source: Inventory, target: Inventory, item: ItemDef, amount: int) -> bool:
    if source == null or target == null or item == null or amount <= 0:
        return false
    # Peek available
    var available := 0
    for idx in source.find_stack_indices(item):
        available += source.slots[idx].quantity
        if available >= amount:
            break
    if available <= 0:
        return false
    var to_move := int(min(available, amount))
    var temp := ItemStack.new()
    temp.item = item
    temp.quantity = to_move
    if not target.can_accept(temp):
        return false
    var removed := source.remove_item(item, to_move)
    if removed <= 0:
        return false
    var moved_stack := ItemStack.new()
    moved_stack.item = item
    moved_stack.quantity = removed
    var ok := target.try_add_stack(moved_stack)
    if not ok:
        # best-effort rollback
        source.try_add_stack(moved_stack)
        return false
    return true

func try_use_item(inventory: Inventory, stack: ItemStack) -> bool:
    if inventory == null or stack == null or stack.is_empty():
        return false
    inventory.emit_signal("item_used", stack)
    return true


