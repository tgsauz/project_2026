extends RigidBody3D
class_name WorldItem

@export var item_resource: ItemResource
@export var prompt_title: String = ""
@export var prompt_text: String = "Pick up"
@export var consume_on_interact: bool = true

func get_display_title() -> String:
	if not prompt_title.is_empty():
		return prompt_title
	if item_resource != null and not item_resource.display_name.is_empty():
		return item_resource.display_name
	return "Item"

func get_prompt_text() -> String:
	return prompt_text

func interact(actor: Node) -> void:
	if item_resource == null:
		return

	var inventory = _resolve_inventory(actor)
	if inventory == null:
		return
	if not inventory.has_method("add_item"):
		return

	inventory.add_item(item_resource, 1)

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
