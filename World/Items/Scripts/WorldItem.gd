@tool
extends RigidBody3D
class_name WorldItem

@export var item_definition: ItemDefinition:
	set(value):
		item_definition = value
		if Engine.is_editor_hint() and is_inside_tree():
			_update_editor_representation()

@export var prompt_title: String = ""
@export var consume_on_interact: bool = true

var item_instance: ItemInstance

func _ready() -> void:
	if Engine.is_editor_hint():
		# Hide the physical setup in editor until the definition is set
		_update_editor_representation()
		return
		
	_ensure_runtime_instance()
	_apply_world_visual()
	mass = item_definition.weight if item_definition != null else 1.0

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

# ============================================================
#  WORLD VISUAL
# ============================================================

## Spawns the data-driven world mesh if item_definition.world_visual_scene is
## set. This separates the floor-pickup representation (physics RigidBody +
## simple mesh) from the equipped representation (skeleton, IK grips, etc.)
##
## If world_visual_scene is null the function is a no-op: any child nodes
## placed in the editor scene are used as-is, preserving backward compatibility.
func _apply_world_visual() -> void:
	if get_meta("world_visual_applied", false):
		return
	if item_definition == null or item_definition.world_visual_scene == null:
		return

	var visual_instance := item_definition.world_visual_scene.instantiate() as Node3D
	if visual_instance == null:
		push_warning("[WorldItem] world_visual_scene for '%s' did not instantiate as Node3D." % item_definition.id)
		return

	add_child(visual_instance)
	set_meta("world_visual_applied", true)

	if item_definition.world_collision_mode != "manual":
		_generate_collision_shape(visual_instance)

# ============================================================
#  EDITOR TOOLING (SMART PREFAB)
# ============================================================

func _update_editor_representation() -> void:
	if not Engine.is_editor_hint():
		return
		
	# 1. Clean up generated visuals/collisions
	for child in get_children():
		if child.has_meta("generated_by_world_item"):
			child.queue_free()
			
	set_meta("world_visual_applied", false)
	
	if item_definition == null:
		return
		
	# 2. Update basic rigid body properties based on definition
	mass = item_definition.weight
	
	# 3. Instantiate visual scene if available
	if item_definition.world_visual_scene != null:
		var visual_instance = item_definition.world_visual_scene.instantiate() as Node3D
		if visual_instance:
			visual_instance.set_meta("generated_by_world_item", true)
			add_child(visual_instance)
			
			if item_definition.world_collision_mode != "manual":
				_generate_collision_shape(visual_instance, true)

func _generate_collision_shape(visual_node: Node3D, is_editor: bool = false) -> void:
	if item_definition == null:
		return
		
	var shape := CollisionShape3D.new()
	if is_editor:
		shape.set_meta("generated_by_world_item", true)
		
	var mode = item_definition.world_collision_mode
	
	if mode == "auto_convex":
		var meshes := _find_all_meshes(visual_node)
		if not meshes.is_empty():
			# For simplicity, combine points into one convex hull if multiple meshes
			# Or just take the first/largest one. Using the first one for now.
			var target_mesh = meshes[0].mesh
			if target_mesh:
				shape.shape = target_mesh.create_convex_shape(true, true)
	elif mode == "box" or mode == "sphere":
		var meshes := _find_all_meshes(visual_node)
		if not meshes.is_empty():
			var aabb := AABB()
			var first = true
			for mi in meshes:
				if not mi.mesh: continue
				var local_aabb = mi.mesh.get_aabb()
				# Transform AABB into local space of the WorldItem
				# This is a bit simplified, ideally we'd apply relative transforms
				var space_aabb = AABB(mi.transform * local_aabb.position, local_aabb.size * mi.scale)
				if first:
					aabb = space_aabb
					first = false
				else:
					aabb = aabb.merge(space_aabb)
			
			if mode == "box":
				var box = BoxShape3D.new()
				box.size = aabb.size + Vector3.ONE * item_definition.world_collision_margin
				shape.shape = box
				shape.position = aabb.get_center()
			elif mode == "sphere":
				var sphere = SphereShape3D.new()
				sphere.radius = (aabb.size.length() / 2.0) + item_definition.world_collision_margin
				shape.shape = sphere
				shape.position = aabb.get_center()
				
	if shape.shape != null:
		add_child(shape)

func _find_all_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_meshes(child))
	return result
