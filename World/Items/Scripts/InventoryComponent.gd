extends Node
class_name InventoryComponent

# ============================================================
#  CONFIG
# ============================================================

@export_category("Capacity")
@export var base_capacity: float = 20.0  # kg equivalent

# ============================================================
#  INTERNAL
# ============================================================

var items: Array = []  # Array of dictionaries {resource, quantity}

var total_weight: float = 0.0
var load_factor: float = 0.0

# ============================================================
#  SIGNALS (CRITICAL FOR MODULARITY)
# ============================================================

signal inventory_updated
signal weight_changed(new_weight: float, load_factor: float)

# ============================================================
#  PUBLIC API
# ============================================================

func add_item(item: ItemResource, quantity: int = 1) -> void:
	
	if item == null:
		return
	
	items.append({
		"resource": item,
		"quantity": quantity
	})
	
	_recalculate()

func remove_item(index: int) -> void:
	
	if index < 0 or index >= items.size():
		return
	
	items.remove_at(index)
	_recalculate()

func clear():
	items.clear()
	_recalculate()

# ============================================================
#  CORE LOGIC
# ============================================================

func _recalculate():
	
	var new_weight := 0.0
	
	for entry in items:
		var item: ItemResource = entry["resource"]
		var quantity: int = entry["quantity"]
		
		new_weight += item.weight * quantity
	
	total_weight = new_weight
	
	load_factor = total_weight / base_capacity
	load_factor = max(load_factor, 0.0)  # no upper clamp (important!)
	
	emit_signal("inventory_updated")
	emit_signal("weight_changed", total_weight, load_factor)

# ============================================================
#  GETTERS
# ============================================================

func get_items() -> Array:
	return items

func get_total_weight() -> float:
	return total_weight

func get_load_factor() -> float:
	return load_factor
