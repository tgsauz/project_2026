extends Node
class_name InventoryComponent

# ============================================================
#  CONFIGURATION
# ============================================================

@export_category("Capacity")
@export var base_capacity: float = 20.0
@export var slot_names: PackedStringArray = PackedStringArray([
	"left_hand",
	"right_hand",
	"torso",
	"lower_back",
	"belt",
	"left_pocket",
	"right_pocket",
	"back_mount",
	"shoulder_mount"
])

# ============================================================
#  INTERNAL
# ============================================================

var slot_configs: Dictionary = {}
var slot_state: Dictionary = {}
var item_instances: Dictionary = {}

var total_weight: float = 0.0
var load_factor: float = 0.0

# ============================================================
#  SIGNALS
# ============================================================

signal inventory_updated
signal weight_changed(new_weight: float, load_factor: float)
signal item_visuals_changed(visible_items: Array)
signal equipment_visuals_changed(visible_items: Array)

# ============================================================
#  LIFECYCLE
# ============================================================

func _ready() -> void:
	ItemDefinitionRegistry.initialize()
	slot_configs = _build_slot_configs()
	_initialize_slots()

# ============================================================
#  COMPATIBILITY API
# ============================================================

func add_item(item: ItemResource, quantity: int = 1) -> void:
	if item == null:
		return

	var instance = ItemInstance.create_from_definition(item, quantity)
	store_item_instance_best_effort(instance)

func clear() -> void:
	slot_state.clear()
	item_instances.clear()
	_initialize_slots()
	_recalculate()

func get_items() -> Array:
	var items: Array = []
	for item_id in item_instances.keys():
		var item = item_instances[item_id]
		if item == null:
			continue

		items.append({
			"resource": item.definition,
			"quantity": item.stack_count,
			"instance_id": item.instance_id,
			"slot": item.owning_slot,
			"container_id": item.parent_instance_id
		})
	return items

# ============================================================
#  STORAGE API
# ============================================================

func can_store_item(item, target_slot: String) -> bool:
	if item == null or item.definition == null:
		return false
	if not slot_state.has(target_slot):
		return false
	if not str(slot_state[target_slot].get("item_id", "")).is_empty():
		return false

	var config: Dictionary = slot_configs.get(target_slot, {})
	var accepted_categories: PackedStringArray = config.get("accepted_categories", PackedStringArray())
	if not accepted_categories.is_empty() and not accepted_categories.has(str(item.definition.category)):
		return false

	if not item.definition.allowed_slots.is_empty() and not item.definition.allowed_slots.has(target_slot):
		return false

	return true

func store_item_in_slot(item, target_slot: String) -> bool:
	if not can_store_item(item, target_slot):
		return false

	if str(item.instance_id).is_empty():
		item.instance_id = ItemInstance.create_from_definition(item.definition, item.stack_count).instance_id

	item_instances[item.instance_id] = item
	_detach_item(item.instance_id)
	item.owning_slot = target_slot
	item.parent_instance_id = ""
	slot_state[target_slot]["item_id"] = item.instance_id
	_restore_embedded_contents(item)
	_recalculate()
	return true

func store_item_in_container(item, target_container_id: String) -> bool:
	if item == null or item.definition == null:
		return false
	if target_container_id.is_empty() or not item_instances.has(target_container_id):
		return false

	var container = item_instances[target_container_id]
	if not _can_container_accept_item(container, item):
		return false

	if str(item.instance_id).is_empty():
		item.instance_id = ItemInstance.create_from_definition(item.definition, item.stack_count).instance_id

	item_instances[item.instance_id] = item
	_detach_item(item.instance_id)
	item.owning_slot = ""
	item.parent_instance_id = target_container_id

	var contents := Array(container.contained_item_ids)
	contents.append(item.instance_id)
	container.contained_item_ids = PackedStringArray(contents)
	_restore_embedded_contents(item)
	_recalculate()
	return true

func store_item_instance_best_effort(item) -> bool:
	if item == null or item.definition == null:
		return false
	if str(item.instance_id).is_empty():
		item.instance_id = ItemInstance.create_from_definition(item.definition, item.stack_count).instance_id

	for slot_name in _get_preferred_slots(item.definition):
		if store_item_in_slot(item, slot_name):
			return true

	for item_id in item_instances.keys():
		if store_item_in_container(item, str(item_id)):
			return true

	return false

func pickup_item_instance(item, prefer_equipment: bool = true, allow_fallback_storage: bool = true) -> bool:
	if item == null or item.definition == null:
		return false

	if prefer_equipment and _pickup_to_preferred_equipment_slot(item):
		return true

	if allow_fallback_storage:
		return store_item_instance_best_effort(item)

	return false

func move_item(item_id: String, target_slot: String = "", target_container_id: String = "") -> bool:
	var item = get_item_instance(item_id)
	if item == null:
		return false
	if not target_slot.is_empty():
		return store_item_in_slot(item, target_slot)
	if not target_container_id.is_empty():
		return store_item_in_container(item, target_container_id)
	return false

func equip_item(item_id: String, target_slot: String) -> bool:
	return move_item(item_id, target_slot, "")

func unequip_item(item_id: String) -> bool:
	var item = get_item_instance(item_id)
	if item == null:
		return false

	for slot_name in ["left_pocket", "right_pocket", "belt", "left_hand", "right_hand"]:
		if can_store_item(item, slot_name):
			return store_item_in_slot(item, slot_name)

	for container_id in item_instances.keys():
		if store_item_in_container(item, str(container_id)):
			return true

	return false

func move_item_to_hand(item_id: String) -> bool:
	var item = get_item_instance(item_id)
	if item == null:
		return false

	for slot_name in _get_hand_slot_order(item.definition):
		if can_store_item(item, slot_name):
			return store_item_in_slot(item, slot_name)
		if _try_free_slot_for_item(item, slot_name):
			return store_item_in_slot(item, slot_name)

	return false

func drop_item(item_id: String):
	var item = get_item_instance(item_id)
	if item == null:
		return null

	var nested_items: Array = _collect_nested_items(item)
	if not nested_items.is_empty():
		item.custom_state["contained_instances"] = nested_items
		item.contained_item_ids = PackedStringArray()

	_detach_item(item_id)
	item_instances.erase(item_id)
	for nested_item in nested_items:
		item_instances.erase(str(nested_item.instance_id))
	item.owning_slot = ""
	item.parent_instance_id = ""
	_recalculate()
	return item

func get_item_actions(item_id: String) -> Array[Dictionary]:
	var item = get_item_instance(item_id)
	if item == null:
		return []

	var actions: Array[Dictionary] = []
	if item.owning_slot != "right_hand" and item.owning_slot != "left_hand":
		actions.append({"id": "move_to_hand", "label": "Move To Hand"})
	if not str(item.owning_slot).is_empty() and item.owning_slot != "left_pocket" and item.owning_slot != "right_pocket":
		actions.append({"id": "unequip", "label": "Stow"})
	actions.append({"id": "drop", "label": "Drop"})
	actions.append({"id": "inspect", "label": "Inspect"})
	return actions

# ============================================================
#  GETTERS
# ============================================================

func get_item_instance(item_id: String):
	if not item_instances.has(item_id):
		return null
	return item_instances[item_id]

func get_total_weight() -> float:
	return total_weight

func get_load_factor() -> float:
	return load_factor

func get_main_hand_item():
	var state := get_slot_state("right_hand")
	return state.get("item", null)

func get_slot_state(target_slot: String) -> Dictionary:
	if not slot_state.has(target_slot):
		return {}

	var state: Dictionary = slot_state[target_slot].duplicate(true)
	var item_id: String = str(state.get("item_id", ""))
	if not item_id.is_empty() and item_instances.has(item_id):
		var item = item_instances[item_id]
		state["item"] = item
		state["definition"] = item.definition
	return state

func get_visible_equipment() -> Array:
	return get_equipped_visuals()

func get_equipped_visuals() -> Array:
	var visible_items: Array = []
	for slot_name in slot_names:
		var state: Dictionary = get_slot_state(slot_name)
		var item = state.get("item", null)
		if item == null or item.definition == null:
			continue
		if not item.definition.should_show_in_slot(slot_name):
			continue
		var config: Dictionary = slot_configs.get(slot_name, {})
		if not bool(config.get("visible", false)):
			continue

		var profile: ItemVisualAttachmentProfile = item.definition.get_attachment_profile(slot_name)

		visible_items.append({
			"slot_name": slot_name,
			"item_id": item.instance_id,
			"definition": item.definition,
			"display_name": item.get_display_name(),
			"attachment_profile": profile,
			"visual_state": item.definition.get_visual_state_for_slot(slot_name),
			"secondary_slot_name": _get_secondary_slot_name(item, slot_name),
			"equipped_visual_scene": item.definition.equipped_visual_scene,
			"visual_profile_id": item.definition.visual_profile_id
		})
	return visible_items

# ============================================================
#  CORE
# ============================================================

func _initialize_slots() -> void:
	for slot_name in slot_names:
		slot_state[slot_name] = {
			"item_id": "",
			"display_name": slot_configs.get(slot_name, {}).get("display_name", slot_name)
		}

func _recalculate() -> void:
	var new_weight := 0.0
	for item_id in item_instances.keys():
		var item = item_instances[item_id]
		if item == null:
			continue
		new_weight += float(item.get_total_weight())

	total_weight = new_weight
	load_factor = total_weight / base_capacity
	load_factor = max(load_factor, 0.0)

	emit_signal("inventory_updated")
	emit_signal("weight_changed", total_weight, load_factor)
	var equipped_visuals := get_equipped_visuals()
	emit_signal("item_visuals_changed", equipped_visuals)
	emit_signal("equipment_visuals_changed", equipped_visuals)

# ============================================================
#  SERIALIZATION
# ============================================================

func serialize() -> Dictionary:
	var serialized_items: Dictionary = {}
	for item_id in item_instances.keys():
		var item = item_instances[item_id]
		if item == null or item.definition == null:
			continue
		serialized_items[str(item_id)] = {
			"definition_id": item.definition.id,
			"stack_count": item.stack_count,
			"condition": item.condition,
			"owning_slot": item.owning_slot,
			"parent_instance_id": item.parent_instance_id,
			"contained_item_ids": Array(item.contained_item_ids),
			"custom_state": item.custom_state.duplicate(true)
		}
	
	var serialized_slots: Dictionary = {}
	for slot_name in slot_names:
		var state = slot_state.get(slot_name, {})
		serialized_slots[slot_name] = str(state.get("item_id", ""))
	
	return {
		"slot_state": serialized_slots,
		"items": serialized_items
	}

func deserialize(data: Dictionary) -> void:
	clear()
	
	var items_data: Dictionary = data.get("items", {})
	var slots_data: Dictionary = data.get("slot_state", {})
	
	# Pass 1: Recreate all ItemInstance objects
	for item_id in items_data.keys():
		var item_data: Dictionary = items_data[item_id]
		var def_id: String = item_data.get("definition_id", "")
		var definition = ItemDefinitionRegistry.find_by_id(def_id)
		if definition == null:
			push_warning("InventoryComponent.deserialize: Unknown definition '%s', skipping." % def_id)
			continue
		
		var instance = ItemInstance.new()
		instance.instance_id = str(item_id)
		instance.definition = definition
		instance.stack_count = int(item_data.get("stack_count", 1))
		instance.condition = float(item_data.get("condition", 1.0))
		instance.owning_slot = str(item_data.get("owning_slot", ""))
		instance.parent_instance_id = str(item_data.get("parent_instance_id", ""))
		instance.custom_state = item_data.get("custom_state", {}).duplicate(true)
		
		var contained: Array = item_data.get("contained_item_ids", [])
		var packed := PackedStringArray()
		for cid in contained:
			packed.append(str(cid))
		instance.contained_item_ids = packed
		
		item_instances[str(item_id)] = instance
	
	# Pass 2: Restore slot occupancy
	for slot_name in slots_data.keys():
		var occupant_id: String = str(slots_data[slot_name])
		if slot_state.has(slot_name):
			slot_state[slot_name]["item_id"] = occupant_id
	
	_recalculate()
	print("[InventoryComponent] Deserialized %d items across %d slots." % [item_instances.size(), slot_names.size()])

# ============================================================
#  HELPERS
# ============================================================

func _build_slot_configs() -> Dictionary:
	return {
		"left_hand": {
			"display_name": "Left Hand",
			"accepted_categories": PackedStringArray(["weapon", "ammo", "medical", "equipment", "clothing"]),
			"visible": true
		},
		"right_hand": {
			"display_name": "Right Hand",
			"accepted_categories": PackedStringArray(["weapon", "ammo", "medical", "equipment", "clothing"]),
			"visible": true
		},
		"torso": {
			"display_name": "Torso",
			"accepted_categories": PackedStringArray(["equipment", "clothing", "medical"]),
			"visible": true
		},
		"lower_back": {
			"display_name": "Lower Back",
			"accepted_categories": PackedStringArray(["equipment", "weapon"]),
			"visible": true
		},
		"belt": {
			"display_name": "Belt",
			"accepted_categories": PackedStringArray(["equipment", "medical", "ammo"]),
			"visible": true
		},
		"left_pocket": {
			"display_name": "Left Pocket",
			"accepted_categories": PackedStringArray(["ammo", "medical", "equipment"]),
			"visible": false
		},
		"right_pocket": {
			"display_name": "Right Pocket",
			"accepted_categories": PackedStringArray(["ammo", "medical", "equipment"]),
			"visible": false
		},
		"back_mount": {
			"display_name": "Back Mount",
			"accepted_categories": PackedStringArray(["equipment", "weapon"]),
			"visible": true
		},
		"shoulder_mount": {
			"display_name": "Shoulder Mount",
			"accepted_categories": PackedStringArray(["equipment", "weapon"]),
			"visible": true
		}
	}

func _detach_item(item_id: String) -> void:
	for slot_name in slot_names:
		if str(slot_state[slot_name].get("item_id", "")) == item_id:
			slot_state[slot_name]["item_id"] = ""

	for existing_id in item_instances.keys():
		var existing = item_instances[existing_id]
		if existing == null or existing.contained_item_ids.is_empty():
			continue

		var contents := Array(existing.contained_item_ids)
		if contents.has(item_id):
			contents.erase(item_id)
			existing.contained_item_ids = PackedStringArray(contents)

func _can_container_accept_item(container, item) -> bool:
	if container == null or item == null:
		return false
	if not container.is_container():
		return false
	if container.instance_id == item.instance_id:
		return false
	if container.definition.container_capacity > 0 and container.contained_item_ids.size() >= container.definition.container_capacity:
		return false
	if container.definition.container_max_weight > 0.0 and _get_container_contents_weight(container) + float(item.get_total_weight()) > container.definition.container_max_weight:
		return false
	return container.definition.can_store_category(str(item.definition.category))

func _get_container_contents_weight(container) -> float:
	var total := 0.0
	for item_id in container.contained_item_ids:
		var item = get_item_instance(str(item_id))
		if item != null:
			total += float(item.get_total_weight())
	return total

func _get_preferred_slots(definition) -> PackedStringArray:
	if definition == null:
		return PackedStringArray()

	if not str(definition.preferred_slot).is_empty():
		var preferred := PackedStringArray([definition.preferred_slot])
		for slot_name in definition.allowed_slots:
			if slot_name != definition.preferred_slot:
				preferred.append(slot_name)
		return preferred

	return definition.allowed_slots

func _pickup_to_preferred_equipment_slot(item) -> bool:
	if item == null or item.definition == null:
		return false
	if not item.definition.supports_hand_slot():
		return false

	for slot_name in _get_hand_slot_order(item.definition):
		if can_store_item(item, slot_name):
			return store_item_in_slot(item, slot_name)
		if _try_free_slot_for_item(item, slot_name):
			return store_item_in_slot(item, slot_name)

	return false

func _get_hand_slot_order(definition) -> PackedStringArray:
	var ordered_slots := PackedStringArray()
	if definition == null:
		return ordered_slots

	if definition.preferred_slot == "right_hand" or definition.preferred_slot == "left_hand":
		ordered_slots.append(definition.preferred_slot)

	for slot_name in ["right_hand", "left_hand"]:
		if definition.allowed_slots.has(slot_name) and not ordered_slots.has(slot_name):
			ordered_slots.append(slot_name)

	return ordered_slots

func _try_free_slot_for_item(_new_item, target_slot: String) -> bool:
	if not slot_state.has(target_slot):
		return false

	var occupant_id := str(slot_state[target_slot].get("item_id", ""))
	if occupant_id.is_empty():
		return true

	var occupant = get_item_instance(occupant_id)
	if occupant == null or occupant.definition == null:
		return false

	for slot_name in _get_auto_stow_slots_for_item(occupant, target_slot):
		if can_store_item(occupant, slot_name):
			return store_item_in_slot(occupant, slot_name)

	for container_id in item_instances.keys():
		if str(container_id) == occupant.instance_id:
			continue
		if store_item_in_container(occupant, str(container_id)):
			return true

	return false

func _get_auto_stow_slots_for_item(item, excluded_slot: String = "") -> PackedStringArray:
	var ordered_slots := PackedStringArray()
	if item == null or item.definition == null:
		return ordered_slots

	for slot_name in _get_preferred_slots(item.definition):
		if slot_name != excluded_slot and not ordered_slots.has(slot_name):
			ordered_slots.append(slot_name)

	for slot_name in [
		"lower_back",
		"back_mount",
		"shoulder_mount",
		"belt",
		"torso",
		"left_pocket",
		"right_pocket",
		"left_hand",
		"right_hand"
	]:
		if slot_name == excluded_slot:
			continue
		if ordered_slots.has(slot_name):
			continue
		if item.definition.allowed_slots.has(slot_name):
			ordered_slots.append(slot_name)

	return ordered_slots

func _get_secondary_slot_name(item, slot_name: String) -> String:
	if item == null or item.definition == null:
		return ""

	var profile: ItemVisualAttachmentProfile = item.definition.get_attachment_profile(slot_name)
	if profile != null and not profile.secondary_slot_name.is_empty():
		return profile.secondary_slot_name

	if item.definition.reserve_secondary_hand:
		return item.definition.secondary_hand_slot

	return ""

func _collect_nested_items(container) -> Array:
	var nested_items: Array = []
	for nested_id in container.contained_item_ids:
		var nested_item = get_item_instance(str(nested_id))
		if nested_item == null:
			continue
		nested_items.append(nested_item)
		nested_items.append_array(_collect_nested_items(nested_item))
	return nested_items

func _restore_embedded_contents(container) -> void:
	if container == null or not container.is_container():
		return
	if not container.custom_state.has("contained_instances"):
		return

	var embedded_items: Array = container.custom_state.get("contained_instances", [])
	container.custom_state.erase("contained_instances")
	for embedded_item in embedded_items:
		if embedded_item != null:
			store_item_in_container(embedded_item, str(container.instance_id))
