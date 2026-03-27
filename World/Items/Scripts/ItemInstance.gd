extends Resource
class_name ItemInstance

static var _next_runtime_id: int = 1

# ============================================================
#  RUNTIME STATE
# ============================================================

@export var instance_id: String = ""
@export var definition: ItemDefinition
@export var stack_count: int = 1
@export var condition: float = 1.0
@export var custom_state: Dictionary = {}

@export var owning_slot: String = ""
@export var parent_instance_id: String = ""
@export var contained_item_ids: PackedStringArray = PackedStringArray()

# ============================================================
#  FACTORIES
# ============================================================

static func create_from_definition(item_definition: ItemDefinition, count: int = 1) -> ItemInstance:
	var instance := ItemInstance.new()
	instance.instance_id = "item_%d" % _next_runtime_id
	_next_runtime_id += 1
	instance.definition = item_definition
	instance.stack_count = max(count, 1)
	return instance

func duplicate_instance() -> ItemInstance:
	var cloned_instance := ItemInstance.create_from_definition(definition, stack_count)
	cloned_instance.condition = condition
	cloned_instance.custom_state = custom_state.duplicate(true)
	return cloned_instance

# ============================================================
#  HELPERS
# ============================================================

func get_total_weight() -> float:
	if definition == null:
		return 0.0
	return definition.weight * max(stack_count, 1)

func is_container() -> bool:
	return definition != null and definition.is_container

func get_display_name() -> String:
	if definition == null or definition.display_name.is_empty():
		return "Item"
	return definition.display_name
