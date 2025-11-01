extends Resource
class_name ItemStack

@export var item: ItemDef
@export var quantity: int = 1

func is_empty() -> bool:
    return item == null or quantity <= 0

func can_merge(other: ItemStack) -> bool:
    if is_empty() or other == null or other.is_empty():
        return false
    if item != other.item:
        return false
    return item.is_stackable()

func merge_from(other: ItemStack) -> int:
    if not can_merge(other):
        return 0
    var max_add := item.max_stack - quantity
    var moved := int(min(max_add, other.quantity))
    quantity += moved
    other.quantity -= moved
    return moved

func split(amount: int) -> ItemStack:
    if amount <= 0 or amount > quantity:
        return ItemStack.new() # empty
    var out := ItemStack.new()
    out.item = item
    out.quantity = amount
    quantity -= amount
    return out

func total_weight_kg() -> float:
    if item == null:
        return 0.0
    return float(quantity) * item.weight_kg


