extends RigidBody3D
class_name WorldItem

@export var item_definition: ItemDefinition
@export var prompt_title: String = ""
@export var consume_on_interact: bool = true

var item_instance: ItemInstance

func _ready() -> void:
	_ensure_runtime_instance()

func get_display_title() -> String:
	if not prompt_title.is_empty():
		return prompt_title
	if item_instance != null:
		return item_instance.get_display_name()
	return "Item"

func get_interaction_prompt_data() -> Dictionary:
	_ensure_runtime_instance()
	if item_instance == null or item_instance.definition == null:
		return {}

	return {
		"target_id": item_instance.instance_id,
		"title": get_display_title(),
		"tooltip": item_instance.definition.tooltip_text,
		"interact_label": item_instance.definition.get_interaction_label(),
		"quick_action_label": "Hold [%s] Actions" % item_instance.definition.interaction_key_hint,
		"interact_key_hint": item_instance.definition.interaction_key_hint,
		"category": item_instance.definition.category,
		"actions": get_interaction_actions(null)
	}

func get_interaction_actions(_actor: Node) -> Array[Dictionary]:
	return [
		{"id": "pickup", "label": "Pick Up"},
		{"id": "inspect", "label": "Inspect"}
	]

func interact(actor: Node) -> void:
	perform_interaction_action(actor, "pickup")

func perform_interaction_action(actor: Node, action_id: String) -> void:
	if action_id != "pickup":
		return

	_ensure_runtime_instance()
	if item_instance == null or item_instance.definition == null:
		return

	var inventory = _resolve_inventory(actor)
	if inventory == null:
		return
	if not inventory.has_method("store_item_instance_best_effort"):
		return

	var instance_to_store := item_instance.duplicate_instance()
	if not inventory.has_method("pickup_item_instance"):
		return

	if not inventory.pickup_item_instance(instance_to_store, true, true):
		return

	if consume_on_interact:
		queue_free()

func _resolve_inventory(actor: Node) -> Node:
	if actor == null:
		return null

	if actor.has_method("get_inventory_component"):
		var inventory = actor.get_inventory_component()
		if inventory != null:
			return inventory

	return actor.get_node_or_null("InventoryComponent")

func _ensure_runtime_instance() -> void:
	if item_instance != null:
		return
	if item_definition == null:
		return
	item_instance = ItemInstance.create_from_definition(item_definition, 1)
