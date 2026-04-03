extends Node
class_name InventoryComponent

# ============================================================
#  CONFIGURATION
# ============================================================

@export_category("Capacity")
@export var base_capacity: float = 20.0
@export var slot_names: PackedStringArray = PackedStringArray()

# ============================================================
#  INTERNAL
# ============================================================

var attachment_graph := RuntimeAttachmentGraph.new()
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
	slot_names = _resolve_root_node_ids()
	_initialize_attachment_graph()
	_recalculate()

# ============================================================
#  COMPATIBILITY API
# ============================================================

func add_item(item: ItemResource, quantity: int = 1) -> void:
	if item == null:
		return

	var instance = ItemInstance.create_from_definition(item, quantity)
	store_item_instance_best_effort(instance)

func clear() -> void:
	item_instances.clear()
	_initialize_attachment_graph()
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
#  ATTACHMENT GRAPH API
# ============================================================

func get_attachment_node(node_id: String) -> Dictionary:
	var node := attachment_graph.get_node(node_id)
	if node == null:
		return {}

	var data := node.to_dictionary()
	if not node.occupant_item_id.is_empty() and item_instances.has(node.occupant_item_id):
		var occupant = item_instances[node.occupant_item_id]
		data["item"] = occupant
		data["definition"] = occupant.definition
	return data

func get_attachment_children(node_id: String) -> Array[Dictionary]:
	var children: Array[Dictionary] = []
	for child in attachment_graph.get_children(node_id):
		children.append(get_attachment_node(child.node_id))
	return children

func get_available_attachment_nodes(include_hidden: bool = false) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	for node in attachment_graph.get_all_nodes_sorted():
		if node == null:
			continue
		if not include_hidden and node.definition != null and not node.definition.visible:
			continue
		nodes.append(get_attachment_node(node.node_id))
	return nodes

func can_attach_item(item, node_id: String) -> bool:
	if item == null or item.definition == null:
		return false

	var node := attachment_graph.get_node(node_id)
	if node == null or node.definition == null:
		return false
	if not node.occupant_item_id.is_empty():
		return false

	if not item.definition.allowed_slots.is_empty() and not item.definition.allowed_slots.has(node_id):
		return false
	if not node.definition.accepted_categories.is_empty() and not node.definition.accepted_categories.has(str(item.definition.category)):
		return false
	if not node.definition.accepted_item_tags.is_empty():
		if item.definition.attachment_tags.is_empty():
			return false
		var matches_tag := false
		for tag in item.definition.attachment_tags:
			if node.definition.accepted_item_tags.has(tag):
				matches_tag = true
				break
		if not matches_tag:
			return false
	if not str(item.instance_id).is_empty() and _would_create_attachment_cycle(item.instance_id, node_id):
		push_warning("InventoryComponent: Rejected attachment move that would create a dependency cycle. item=%s node=%s" % [item.instance_id, node_id])
		return false

	return true

func attach_item(item, node_id: String) -> bool:
	if str(item.instance_id).is_empty():
		item.instance_id = ItemInstance.create_from_definition(item.definition, item.stack_count).instance_id
	if not can_attach_item(item, node_id):
		return false

	item_instances[item.instance_id] = item
	_detach_item(item.instance_id)

	var node := attachment_graph.get_node(node_id)
	node.occupant_item_id = item.instance_id
	item.owning_slot = node_id
	item.parent_instance_id = ""

	_activate_modifier_nodes_for_item(item)
	_restore_embedded_contents(item)
	_restore_attached_dependents(item)
	_recalculate()
	return true

func detach_item(item_id: String) -> bool:
	var item = get_item_instance(item_id)
	if item == null:
		return false

	var attached_dependents := _extract_attached_dependents(item_id)
	if not attached_dependents.is_empty():
		item.custom_state["attached_instances"] = attached_dependents

	_detach_item(item_id)
	item.owning_slot = ""
	item.parent_instance_id = ""
	_recalculate()
	return true

# ============================================================
#  STORAGE API
# ============================================================

func can_store_item(item, target_slot: String) -> bool:
	return can_attach_item(item, target_slot)

func store_item_in_slot(item, target_slot: String) -> bool:
	return attach_item(item, target_slot)

func can_store_item_in_storage(item, target_container_id: String) -> bool:
	if item == null or item.definition == null:
		return false
	if target_container_id.is_empty() or not item_instances.has(target_container_id):
		return false

	var container = item_instances[target_container_id]
	if container == null or container.definition == null:
		return false
	if not _can_container_accept_item(container, item):
		return false
	return true

func store_item_in_container(item, target_container_id: String) -> bool:
	if not can_store_item_in_storage(item, target_container_id):
		return false

	var container = item_instances[target_container_id]
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

func get_storage_usage(container_id: String) -> int:
	var container = get_item_instance(container_id)
	if container == null:
		return 0
	return _get_container_contents_size(container)

func get_storage_capacity(container_id: String) -> int:
	var container = get_item_instance(container_id)
	if container == null or container.definition == null:
		return 0
	return container.definition.get_storage_capacity()

func store_item_instance_best_effort(item) -> bool:
	if item == null or item.definition == null:
		return false
	if str(item.instance_id).is_empty():
		item.instance_id = ItemInstance.create_from_definition(item.definition, item.stack_count).instance_id

	for node_id in _get_attachment_candidate_order(item.definition):
		if attach_item(item, node_id):
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
		return attach_item(item, target_slot)
	if not target_container_id.is_empty():
		return store_item_in_container(item, target_container_id)
	return false

func equip_item(item_id: String, target_slot: String) -> bool:
	return move_item(item_id, target_slot, "")

func unequip_item(item_id: String) -> bool:
	var item = get_item_instance(item_id)
	if item == null:
		return false

	for node_id in _get_auto_stow_slots_for_item(item, item.owning_slot):
		if attach_item(item, node_id):
			return true

	for container_id in item_instances.keys():
		if store_item_in_container(item, str(container_id)):
			return true

	return false

func move_item_to_hand(item_id: String) -> bool:
	var item = get_item_instance(item_id)
	if item == null:
		return false

	for node_id in _get_hand_slot_order(item.definition):
		if can_attach_item(item, node_id):
			return attach_item(item, node_id)
		if _try_free_node_for_item(item, node_id):
			return attach_item(item, node_id)

	return false

func drop_item(item_id: String):
	var item = get_item_instance(item_id)
	if item == null:
		return null

	var nested_items: Array = _collect_nested_items(item)
	if not nested_items.is_empty():
		item.custom_state["contained_instances"] = nested_items
		item.contained_item_ids = PackedStringArray()

	var attached_dependents := _extract_attached_dependents(item_id)
	if not attached_dependents.is_empty():
		item.custom_state["attached_instances"] = attached_dependents

	_detach_item(item_id)
	item_instances.erase(item_id)
	for nested_item in nested_items:
		item_instances.erase(str(nested_item.instance_id))
	for dependent in attached_dependents:
		var dependent_item = dependent.get("item", null)
		if dependent_item != null:
			item_instances.erase(str(dependent_item.instance_id))

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
	state["items"] = []

	if not item_id.is_empty() and item_instances.has(item_id):
		var item = item_instances[item_id]
		state["item"] = item
		state["definition"] = item.definition
		state["items"].append(item)
	return state

func get_visible_equipment() -> Array:
	return get_equipped_visuals()

func get_equipped_visuals() -> Array:
	var visible_items: Array = []
	var visited := {}
	for node in attachment_graph.get_all_nodes_sorted():
		if node == null or node.occupant_item_id.is_empty():
			continue
		var item = get_item_instance(node.occupant_item_id)
		_collect_visible_items_recursive(item, node.node_id, visible_items, visited)
	return visible_items

func _collect_visible_items_recursive(item, node_id: String, out_list: Array, visited: Dictionary) -> void:
	if item == null or item.definition == null:
		return
	if visited.has(item.instance_id):
		push_warning("InventoryComponent: Prevented recursive visual traversal cycle at item '%s'." % item.instance_id)
		return
	visited[item.instance_id] = true

	var node := attachment_graph.get_node(node_id)
	if item.definition.should_show_in_slot(node_id):
		var is_visible := node.definition.visible if node != null and node.definition != null else true
		if is_visible:
			var profile: ItemVisualAttachmentProfile = item.definition.get_attachment_profile(node_id)
			var node_data := get_attachment_node(node_id)
			out_list.append({
				"slot_name": node_id,
				"item_id": item.instance_id,
				"definition": item.definition,
				"display_name": item.get_display_name(),
				"attachment_profile": profile,
				"visual_state": item.definition.get_visual_state_for_slot(node_id),
				"secondary_slot_name": _get_secondary_slot_name(item, node_id),
				"equipped_visual_scene": item.definition.equipped_visual_scene,
				"visual_profile_id": item.definition.visual_profile_id,
				"node_data": node_data
			})

	if item.is_container():
		for nested_id in item.contained_item_ids:
			var nested = get_item_instance(str(nested_id))
			_collect_visible_items_recursive(nested, node_id, out_list, visited)

	visited.erase(item.instance_id)

# ============================================================
#  CORE
# ============================================================

func _initialize_attachment_graph() -> void:
	attachment_graph.clear()
	var layout := AttachmentLayoutLibrary.get_default_layout()
	if layout != null:
		for point in layout.attachment_points:
			_add_attachment_node_from_definition(point)
	_sync_compatibility_views()

func _add_attachment_node_from_definition(point: AttachmentPointDefinition, source_item_id: String = "") -> void:
	if point == null or point.node_id.is_empty():
		return
	if attachment_graph.has_node(point.node_id):
		return

	var runtime_node := RuntimeAttachmentNode.new()
	runtime_node.node_id = point.node_id
	runtime_node.definition = point
	runtime_node.parent_node_id = point.parent_node_id
	runtime_node.source_item_id = source_item_id
	attachment_graph.add_node(runtime_node)

func _sync_compatibility_views() -> void:
	slot_configs.clear()
	slot_state.clear()
	slot_names = _resolve_root_node_ids()

	for node in attachment_graph.get_all_nodes_sorted():
		if node == null or node.definition == null:
			continue
		slot_configs[node.node_id] = {
			"display_name": node.definition.get_display_name_or_default(),
			"accepted_categories": node.definition.accepted_categories,
			"visible": node.definition.visible
		}
		slot_state[node.node_id] = {
			"item_id": node.occupant_item_id,
			"display_name": node.definition.get_display_name_or_default(),
			"parent_node_id": node.parent_node_id,
			"source_item_id": node.source_item_id
		}

func _recalculate() -> void:
	_sync_compatibility_views()

	var new_weight := 0.0
	for item_id in item_instances.keys():
		var item = item_instances[item_id]
		if item == null:
			continue
		new_weight += float(item.get_total_weight())

	total_weight = new_weight
	load_factor = max(total_weight / base_capacity, 0.0)

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

	var serialized_nodes: Dictionary = {}
	for node in attachment_graph.get_all_nodes_sorted():
		serialized_nodes[node.node_id] = node.occupant_item_id

	return {
		"slot_state": serialized_nodes,
		"items": serialized_items
	}

func deserialize(data: Dictionary) -> void:
	clear()

	var items_data: Dictionary = data.get("items", {})
	var slots_data: Dictionary = data.get("slot_state", {})

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

	var pending_attachment_items: Array[ItemInstance] = []
	for item in item_instances.values():
		var attachment_item := item as ItemInstance
		if attachment_item == null:
			continue
		if not attachment_item.parent_instance_id.is_empty():
			continue
		if not attachment_item.owning_slot.is_empty():
			pending_attachment_items.append(attachment_item)

	var progress := true
	while not pending_attachment_items.is_empty() and progress:
		progress = false
		for i in range(pending_attachment_items.size() - 1, -1, -1):
			var item = pending_attachment_items[i]
			var target_node_id = item.owning_slot
			if attachment_graph.has_node(target_node_id):
				_attach_existing_item_to_node(item, target_node_id, false)
				pending_attachment_items.remove_at(i)
				progress = true

	for item in pending_attachment_items:
		push_warning("InventoryComponent.deserialize: Could not restore node '%s' for item '%s'; falling back to best effort storage." % [item.owning_slot, item.instance_id])
		item.owning_slot = ""
		store_item_instance_best_effort(item)

	for legacy_node_id in slots_data.keys():
		if attachment_graph.has_node(str(legacy_node_id)):
			var occupant_id := str(slots_data[legacy_node_id])
			var node := attachment_graph.get_node(str(legacy_node_id))
			if node != null and not occupant_id.is_empty():
				node.occupant_item_id = occupant_id

	_recalculate()

# ============================================================
#  HELPERS
# ============================================================

func _resolve_root_node_ids() -> PackedStringArray:
	var default_root_ids := AttachmentLayoutLibrary.get_default_root_node_ids()
	if slot_names.is_empty():
		return default_root_ids

	var resolved := PackedStringArray()
	for node_id in slot_names:
		if default_root_ids.has(node_id):
			resolved.append(node_id)
		else:
			push_warning("InventoryComponent: Unknown root node override '%s' ignored." % node_id)

	if resolved.is_empty():
		return default_root_ids
	return resolved

func _attach_existing_item_to_node(item: ItemInstance, node_id: String, emit_recalculate: bool = true) -> void:
	var node := attachment_graph.get_node(node_id)
	if node == null:
		return
	node.occupant_item_id = item.instance_id
	item.owning_slot = node_id
	item.parent_instance_id = ""
	_activate_modifier_nodes_for_item(item)
	if emit_recalculate:
		_recalculate()

func _detach_item(item_id: String) -> void:
	for node in attachment_graph.get_all_nodes_sorted():
		if node.occupant_item_id == item_id:
			node.occupant_item_id = ""

	_remove_modifier_nodes_for_item(item_id)

	for existing_id in item_instances.keys():
		var existing = item_instances[existing_id]
		if existing == null or existing.contained_item_ids.is_empty():
			continue

		var contents := Array(existing.contained_item_ids)
		if contents.has(item_id):
			contents.erase(item_id)
			existing.contained_item_ids = PackedStringArray(contents)

func _remove_modifier_nodes_for_item(item_id: String) -> void:
	var node_ids_to_remove: Array[String] = []
	for node in attachment_graph.get_all_nodes_sorted():
		if node.source_item_id == item_id:
			node_ids_to_remove.append(node.node_id)
	node_ids_to_remove.reverse()
	for node_id in node_ids_to_remove:
		attachment_graph.remove_node(node_id)

func _activate_modifier_nodes_for_item(item: ItemInstance) -> void:
	if item == null or item.definition == null:
		return
	var modifier := item.definition.attachment_modifier
	if modifier == null:
		return
	if modifier.host_node_id != item.owning_slot:
		return

	for point in modifier.attachment_points:
		_add_attachment_node_from_definition(point, item.instance_id)

func _can_container_accept_item(container, item) -> bool:
	if container == null or item == null or container.definition == null:
		return false
	if not container.is_container():
		return false
	if container.instance_id == item.instance_id:
		return false
	if _would_create_storage_cycle(container.instance_id, item.instance_id):
		push_warning("InventoryComponent: Rejected storage move that would create a cycle. container=%s item=%s" % [container.instance_id, item.instance_id])
		return false
	if container.definition.get_storage_capacity() > 0 and _get_container_contents_size(container) + item.definition.get_storage_item_size() > container.definition.get_storage_capacity():
		return false
	if container.definition.container_max_weight > 0.0 and _get_container_contents_weight(container) + float(item.get_total_weight()) > container.definition.container_max_weight:
		return false
	if not container.definition.can_store_in_storage(item.definition):
		return false
	return container.definition.can_store_category(str(item.definition.category))

func _get_container_contents_weight(container) -> float:
	var total := 0.0
	for item_id in container.contained_item_ids:
		var item = get_item_instance(str(item_id))
		if item != null:
			total += float(item.get_total_weight())
	return total

func _get_container_contents_size(container) -> int:
	var total := 0
	for item_id in container.contained_item_ids:
		var item = get_item_instance(str(item_id))
		if item != null and item.definition != null:
			total += item.definition.get_storage_item_size()
	return total

func _would_create_storage_cycle(container_id: String, item_id: String) -> bool:
	if container_id.is_empty() or item_id.is_empty():
		return false
	if container_id == item_id:
		return true
	return _is_instance_reachable_in_storage(item_id, container_id, {})

func _would_create_attachment_cycle(item_id: String, target_node_id: String) -> bool:
	if item_id.is_empty() or target_node_id.is_empty():
		return false
	var target_node := attachment_graph.get_node(target_node_id)
	if target_node == null or target_node.source_item_id.is_empty():
		return false
	if target_node.source_item_id == item_id:
		return true
	return _is_item_reachable_via_attachment_sources(item_id, target_node.source_item_id, {})

func _is_instance_reachable_in_storage(start_item_id: String, target_item_id: String, visited: Dictionary) -> bool:
	if start_item_id.is_empty() or target_item_id.is_empty():
		return false
	if start_item_id == target_item_id:
		return true
	if visited.has(start_item_id):
		return false
	visited[start_item_id] = true

	var item = get_item_instance(start_item_id)
	if item == null:
		return false

	for nested_id in item.contained_item_ids:
		if _is_instance_reachable_in_storage(str(nested_id), target_item_id, visited):
			return true
	return false

func _is_item_reachable_via_attachment_sources(start_item_id: String, target_item_id: String, visited: Dictionary) -> bool:
	if start_item_id.is_empty() or target_item_id.is_empty():
		return false
	if start_item_id == target_item_id:
		return true
	if visited.has(start_item_id):
		return false
	visited[start_item_id] = true

	for node in attachment_graph.get_all_nodes_sorted():
		if node == null or node.source_item_id != start_item_id or node.occupant_item_id.is_empty():
			continue
		if _is_item_reachable_via_attachment_sources(node.occupant_item_id, target_item_id, visited):
			return true
	return false

func _get_attachment_candidate_order(definition: ItemDefinition) -> PackedStringArray:
	var ordered := PackedStringArray()
	if definition == null:
		return ordered

	if not str(definition.preferred_slot).is_empty() and attachment_graph.has_node(definition.preferred_slot):
		ordered.append(definition.preferred_slot)

	for node in attachment_graph.get_all_nodes_sorted():
		if node == null:
			continue
		if ordered.has(node.node_id):
			continue
		if can_attach_item(ItemInstance.create_from_definition(definition, 1), node.node_id):
			ordered.append(node.node_id)
	return ordered

func _pickup_to_preferred_equipment_slot(item) -> bool:
	if item == null or item.definition == null:
		return false
	if not item.definition.supports_hand_slot():
		return false

	for node_id in _get_hand_slot_order(item.definition):
		if can_attach_item(item, node_id):
			return attach_item(item, node_id)
		if _try_free_node_for_item(item, node_id):
			return attach_item(item, node_id)

	return false

func _get_hand_slot_order(definition) -> PackedStringArray:
	var ordered_slots := PackedStringArray()
	if definition == null:
		return ordered_slots

	if definition.preferred_slot == "right_hand" or definition.preferred_slot == "left_hand":
		ordered_slots.append(definition.preferred_slot)

	for node_id in ["right_hand", "left_hand"]:
		if attachment_graph.has_node(node_id) and definition.allowed_slots.has(node_id) and not ordered_slots.has(node_id):
			ordered_slots.append(node_id)
		elif attachment_graph.has_node(node_id) and definition.allowed_slots.is_empty() and not ordered_slots.has(node_id):
			ordered_slots.append(node_id)

	return ordered_slots

func _try_free_node_for_item(_new_item, node_id: String) -> bool:
	var node := attachment_graph.get_node(node_id)
	if node == null:
		return false

	var occupant_id := node.occupant_item_id
	if occupant_id.is_empty():
		return true

	var occupant = get_item_instance(occupant_id)
	if occupant == null or occupant.definition == null:
		return false

	for candidate_node_id in _get_auto_stow_slots_for_item(occupant, node_id):
		if can_attach_item(occupant, candidate_node_id):
			return attach_item(occupant, candidate_node_id)

	for container_id in item_instances.keys():
		if str(container_id) == occupant.instance_id:
			continue
		if store_item_in_container(occupant, str(container_id)):
			return true

	return false

func _get_auto_stow_slots_for_item(item, excluded_node: String = "") -> PackedStringArray:
	var ordered := PackedStringArray()
	if item == null or item.definition == null:
		return ordered

	for node_id in _get_attachment_candidate_order(item.definition):
		if node_id != excluded_node and not ordered.has(node_id):
			ordered.append(node_id)
	return ordered

func _get_secondary_slot_name(item, node_id: String) -> String:
	if item == null or item.definition == null:
		return ""

	var profile: ItemVisualAttachmentProfile = item.definition.get_attachment_profile(node_id)
	if profile != null and not profile.secondary_slot_name.is_empty():
		return profile.secondary_slot_name

	if item.definition.reserve_secondary_hand:
		return item.definition.secondary_hand_slot

	return ""

func _collect_nested_items(container, visited: Dictionary = {}) -> Array:
	var nested_items: Array = []
	if container == null:
		return nested_items
	if visited.has(container.instance_id):
		push_warning("InventoryComponent: Prevented recursive nested-item traversal cycle at '%s'." % container.instance_id)
		return nested_items
	visited[container.instance_id] = true

	for nested_id in container.contained_item_ids:
		var nested_item = get_item_instance(str(nested_id))
		if nested_item == null:
			continue
		nested_items.append(nested_item)
		nested_items.append_array(_collect_nested_items(nested_item, visited))
	visited.erase(container.instance_id)
	return nested_items

func _restore_embedded_contents(container) -> void:
	if container == null or not container.is_container():
		return
	if not container.custom_state.has("contained_instances"):
		return

	var embedded_items: Array = container.custom_state.get("contained_instances", [])
	container.custom_state.erase("contained_instances")
	for embedded_item in embedded_items:
		if embedded_item != null and embedded_item.instance_id != container.instance_id:
			store_item_in_container(embedded_item, str(container.instance_id))

func _extract_attached_dependents(item_id: String, visited: Dictionary = {}) -> Array[Dictionary]:
	var dependents: Array[Dictionary] = []
	if item_id.is_empty():
		return dependents
	if visited.has(item_id):
		push_warning("InventoryComponent: Prevented recursive dependent extraction cycle at '%s'." % item_id)
		return dependents
	visited[item_id] = true

	var source_nodes: Array[String] = []
	for node in attachment_graph.get_all_nodes_sorted():
		if node.source_item_id == item_id:
			source_nodes.append(node.node_id)

	for node_id in source_nodes:
		var node := attachment_graph.get_node(node_id)
		if node == null or node.occupant_item_id.is_empty():
			continue
		var dependent_item = get_item_instance(node.occupant_item_id)
		if dependent_item == null:
			continue
		var nested_dependents := _extract_attached_dependents(dependent_item.instance_id, visited)
		if not nested_dependents.is_empty():
			dependent_item.custom_state["attached_instances"] = nested_dependents
		dependents.append({
			"node_id": node_id,
			"item": dependent_item
		})
		_detach_item(dependent_item.instance_id)

	visited.erase(item_id)
	return dependents

func _restore_attached_dependents(item: ItemInstance, visited: Dictionary = {}) -> void:
	if item == null:
		return
	if visited.has(item.instance_id):
		push_warning("InventoryComponent: Prevented recursive dependent restore cycle at '%s'." % item.instance_id)
		return
	visited[item.instance_id] = true
	if not item.custom_state.has("attached_instances"):
		visited.erase(item.instance_id)
		return

	var attached_instances: Array = item.custom_state.get("attached_instances", [])
	item.custom_state.erase("attached_instances")
	for entry in attached_instances:
		if not (entry is Dictionary):
			continue
		var node_id := str(entry.get("node_id", ""))
		var attached_item = entry.get("item", null)
		if attached_item == null:
			continue
		if attachment_graph.has_node(node_id):
			attach_item(attached_item, node_id)
		else:
			store_item_instance_best_effort(attached_item)
	visited.erase(item.instance_id)
