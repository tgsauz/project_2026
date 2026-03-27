extends Node
class_name VisualsComponent

@export_category("Tilt")
@export var tilt_strength: float = 0.08
@export var tilt_smoothing: float = 6.0
@export var max_tilt_angle: float = 0.35

@export var bone_name: String = "Spine"
@export var lower_back_bone_name: String = "pelvis"

var skeleton: Skeleton3D
var bone_idx: int = -1
var lower_back_attachment: BoneAttachment3D
var mounted_visuals: Dictionary = {}
var mounted_interactables: Dictionary = {}

var previous_velocity: Vector3 = Vector3.ZERO
var tilt: Vector2 = Vector2.ZERO

func _ready():
	skeleton = get_node_or_null("Rig/Armature/Skeleton3D") as Skeleton3D
	if skeleton == null:
		push_error("VisualsComponent could not resolve Rig/Armature/Skeleton3D.")
		return

	bone_idx = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		push_warning("VisualsComponent could not find bone '%s'." % bone_name)

	_ensure_attachment_roots()

func update_tilt(delta: float, velocity: Vector3, target_velocity: Vector3, global_basis: Basis):

	var accel = (target_velocity - velocity)  # CLEAN acceleration signal

	var local_accel = global_basis.inverse() * accel

	var target_tilt = Vector2(
		-local_accel.x,
		local_accel.z
	) * tilt_strength

	target_tilt.x = clamp(target_tilt.x, -max_tilt_angle, max_tilt_angle)
	target_tilt.y = clamp(target_tilt.y, -max_tilt_angle, max_tilt_angle)

	tilt = tilt.lerp(target_tilt, tilt_smoothing * delta)

	_apply()

func _apply():

	if skeleton == null or bone_idx == -1:
		return

	var pose = skeleton.get_bone_global_pose(bone_idx)

	var rot = Basis()
	rot = rot.rotated(Vector3.RIGHT, tilt.y)
	rot = rot.rotated(Vector3.FORWARD, tilt.x)

	pose.basis = rot * pose.basis

	skeleton.set_bone_global_pose(bone_idx, pose)

# ============================================================
#  EQUIPMENT VISUALS
# ============================================================

func bind_inventory(inventory: InventoryComponent) -> void:
	if inventory == null:
		return
	if not inventory.item_visuals_changed.is_connected(_on_item_visuals_changed):
		inventory.item_visuals_changed.connect(_on_item_visuals_changed)
	_on_item_visuals_changed(inventory.get_visible_equipment())

func _on_item_visuals_changed(visible_items: Array) -> void:
	_ensure_attachment_roots()

	var active_slots: Dictionary = {}
	for entry in visible_items:
		var slot_name: String = entry.get("slot_name", "")
		var definition: ItemDefinition = entry.get("definition", null)
		if slot_name.is_empty() or definition == null:
			continue

		active_slots[slot_name] = true
		_update_mounted_visual(slot_name, definition, entry.get("display_name", slot_name))
		_update_slot_interactable(slot_name)

	for slot_name in mounted_visuals.keys():
		if active_slots.has(slot_name):
			continue
		var visual := mounted_visuals[slot_name] as Node3D
		if is_instance_valid(visual):
			visual.queue_free()
		mounted_visuals.erase(slot_name)

	for slot_name in mounted_interactables.keys():
		if active_slots.has(slot_name):
			continue
		var interactable := mounted_interactables[slot_name] as Area3D
		if is_instance_valid(interactable):
			interactable.queue_free()
		mounted_interactables.erase(slot_name)

func _ensure_attachment_roots() -> void:
	if skeleton == null:
		return
	if lower_back_attachment != null:
		return

	lower_back_attachment = BoneAttachment3D.new()
	lower_back_attachment.name = "LowerBackAttachment"
	lower_back_attachment.bone_name = lower_back_bone_name
	lower_back_attachment.position = Vector3(0.0, -0.12, 0.2)
	lower_back_attachment.rotation = Vector3(0.0, PI, 0.0)
	skeleton.add_child(lower_back_attachment)

func _update_mounted_visual(slot_name: String, definition: ItemDefinition, display_name: String) -> void:
	var anchor := _get_slot_anchor(slot_name)
	if anchor == null:
		return

	var visual := mounted_visuals.get(slot_name, null) as MeshInstance3D
	if visual == null:
		visual = MeshInstance3D.new()
		visual.name = "%sVisual" % display_name.replace(" ", "")
		anchor.add_child(visual)
		mounted_visuals[slot_name] = visual

	visual.mesh = _build_placeholder_mesh(definition)
	var material := StandardMaterial3D.new()
	material.albedo_color = definition.placeholder_visual_color
	visual.material_override = material

func _update_slot_interactable(slot_name: String) -> void:
	var inventory := _resolve_inventory()
	if inventory == null:
		return

	var anchor := _get_slot_anchor(slot_name)
	if anchor == null:
		return

	var interactable := mounted_interactables.get(slot_name, null) as MountedItemInteractable
	if interactable == null:
		interactable = MountedItemInteractable.new()
		interactable.name = "%sInteractable" % slot_name.capitalize()

		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.35, 0.35, 0.2)
		shape.shape = box
		interactable.add_child(shape)
		anchor.add_child(interactable)
		mounted_interactables[slot_name] = interactable

	interactable.configure(inventory, slot_name)

func _get_slot_anchor(slot_name: String) -> Node3D:
	if slot_name == "lower_back":
		return lower_back_attachment
	return null

func _build_placeholder_mesh(definition: ItemDefinition) -> Mesh:
	var box := BoxMesh.new()
	if definition.placeholder_visual_shape == "pouch":
		box.size = Vector3(0.22, 0.18, 0.08)
	elif definition.placeholder_visual_shape == "long_box":
		box.size = Vector3(0.15, 0.6, 0.1)
	else:
		box.size = definition.placeholder_visual_size
	return box

func _resolve_inventory() -> InventoryComponent:
	var parent := get_parent()
	if parent == null:
		return null
	if parent.has_method("get_inventory_component"):
		return parent.get_inventory_component()
	return parent.get_node_or_null("InventoryComponent") as InventoryComponent
