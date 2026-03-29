extends Area3D
class_name MountedItemInteractable

@export var slot_name: String = ""

var inventory: InventoryComponent

func configure(new_inventory: InventoryComponent, new_slot_name: String) -> void:
	inventory = new_inventory
	slot_name = new_slot_name

func is_slot_active() -> bool:
	if inventory == null:
		return false
	var state: Dictionary = inventory.get_slot_state(slot_name)
	return not state.get("item_id", "").is_empty()

func get_interaction_prompt_data() -> Dictionary:
	if inventory == null:
		return {}

	var slot_state: Dictionary = inventory.get_slot_state(slot_name)
	var item_id: String = str(slot_state.get("item_id", ""))
	if item_id.is_empty():
		return {}

	var item: ItemInstance = inventory.get_item_instance(item_id) as ItemInstance
	if item == null or item.definition == null:
		return {}

	return {
		"target_id": item.instance_id,
		"title": item.get_display_name(),
		"tooltip": item.definition.tooltip_text,
		"interact_label": "Actions [%s]" % item.definition.interaction_key_hint,
		"quick_action_label": "",
		"interact_key_hint": item.definition.interaction_key_hint,
		"category": item.definition.category,
		"actions": get_interaction_actions(null)
	}

func get_interaction_actions(_actor: Node) -> Array[Dictionary]:
	if inventory == null:
		return []

	var slot_state: Dictionary = inventory.get_slot_state(slot_name)
	var item_id: String = str(slot_state.get("item_id", ""))
	if item_id.is_empty():
		return []

	return inventory.get_item_actions(item_id)

func interact(actor: Node) -> void:
	if actor != null and actor.has_method("open_quick_actions_for_target"):
		actor.open_quick_actions_for_target(self)

func perform_interaction_action(actor: Node, action_id: String) -> void:
	if inventory == null or actor == null:
		return

	var slot_state: Dictionary = inventory.get_slot_state(slot_name)
	var item_id: String = str(slot_state.get("item_id", ""))
	if item_id.is_empty():
		return

	if actor.has_method("perform_physical_inventory_action"):
		actor.perform_physical_inventory_action(item_id, action_id)
