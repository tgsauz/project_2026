extends Node
class_name VisualsComponent

@export_category("Tilt")
@export var tilt_strength: float = 0.08
@export var tilt_smoothing: float = 6.0
@export var max_tilt_angle: float = 0.35

@export_category("Anchor Bones")
@export var bone_name: String = "Spine"
@export var lower_back_bone_name: String = "pelvis"
@export var right_hand_bone_name: String = "hand_r"
@export var left_hand_bone_name: String = "hand_l"
@export var gun_support_bone_name: String = "ik_hand_gun"
@export var left_shoulder_bone_name: String = "clavicle_l"
@export var attachment_content_scale_compensation: float = 0.01

@export_category("Debug")
@export var show_attachment_debug_gizmos: bool = false
@export var attachment_debug_gizmo_size: float = 0.06

var skeleton: Skeleton3D
var bone_idx: int = -1
var attachment_roots: Dictionary = {}
var attachment_content_roots: Dictionary = {}
var equipped_visuals: Dictionary = {}
var mounted_interactables: Dictionary = {}
var attachment_debug_gizmos: Dictionary = {}

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
	_refresh_attachment_debug_gizmos()

func update_tilt(delta: float, velocity: Vector3, target_velocity: Vector3, global_basis: Basis):
	var accel = target_velocity - velocity
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
	if not inventory.equipment_visuals_changed.is_connected(_on_equipment_visuals_changed):
		inventory.equipment_visuals_changed.connect(_on_equipment_visuals_changed)
	_on_equipment_visuals_changed(inventory.get_equipped_visuals())

func _on_equipment_visuals_changed(visible_items: Array) -> void:
	_ensure_attachment_roots()

	var active_slots: Dictionary = {}
	for entry in visible_items:
		var slot_name: String = entry.get("slot_name", "")
		var definition: ItemDefinition = entry.get("definition", null)
		if slot_name.is_empty() or definition == null:
			continue

		active_slots[slot_name] = true
		_update_equipped_visual(slot_name, entry)
		_update_slot_interactable(slot_name, entry)

	for slot_name in equipped_visuals.keys():
		if active_slots.has(slot_name):
			continue
		var visual := equipped_visuals[slot_name] as Node3D
		if is_instance_valid(visual):
			visual.queue_free()
		equipped_visuals.erase(slot_name)

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

	_ensure_attachment_root("lower_back", lower_back_bone_name, Vector3(0.0, -0.0012, 0.002), Vector3(0.0, PI, 0.0))
	_ensure_attachment_root("right_hand", right_hand_bone_name, Vector3.ZERO, Vector3.ZERO)
	_ensure_attachment_root("left_hand", left_hand_bone_name, Vector3.ZERO, Vector3.ZERO)
	_ensure_attachment_root("gun_support", gun_support_bone_name, Vector3.ZERO, Vector3.ZERO)
	_refresh_attachment_debug_gizmos()

func _ensure_attachment_root(slot_name: String, bone_name_value: String, local_position: Vector3, local_rotation: Vector3) -> void:
	if attachment_roots.has(slot_name):
		return

	var attachment := BoneAttachment3D.new()
	attachment.name = "%sAttachment" % slot_name.capitalize().replace("_", "")
	attachment.bone_name = bone_name_value
	attachment.position = local_position
	attachment.rotation = local_rotation
	skeleton.add_child(attachment)
	attachment_roots[slot_name] = attachment

	var content_root := Node3D.new()
	content_root.name = "%sContentRoot" % slot_name.capitalize().replace("_", "")
	content_root.scale = Vector3.ONE * attachment_content_scale_compensation
	attachment.add_child(content_root)
	attachment_content_roots[slot_name] = content_root

func _refresh_attachment_debug_gizmos() -> void:
	for slot_name in attachment_content_roots.keys():
		var anchor := attachment_content_roots[slot_name] as Node3D
		if anchor == null:
			continue

		if show_attachment_debug_gizmos:
			_ensure_attachment_debug_gizmo(str(slot_name), anchor)
		else:
			_remove_attachment_debug_gizmo(str(slot_name))

func _ensure_attachment_debug_gizmo(slot_name: String, anchor: Node3D) -> void:
	var gizmo_root := attachment_debug_gizmos.get(slot_name, null) as Node3D
	if gizmo_root == null:
		gizmo_root = Node3D.new()
		gizmo_root.name = "%sDebugGizmo" % slot_name.capitalize().replace("_", "")
		anchor.add_child(gizmo_root)
		attachment_debug_gizmos[slot_name] = gizmo_root

		var marker := MeshInstance3D.new()
		marker.name = "Marker"
		var box := BoxMesh.new()
		box.size = Vector3.ONE * attachment_debug_gizmo_size
		marker.mesh = box
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = _get_debug_color_for_slot(slot_name)
		marker.material_override = material
		gizmo_root.add_child(marker)

		var x_axis := MeshInstance3D.new()
		x_axis.name = "XAxis"
		var x_box := BoxMesh.new()
		x_box.size = Vector3(attachment_debug_gizmo_size * 1.6, attachment_debug_gizmo_size * 0.18, attachment_debug_gizmo_size * 0.18)
		x_axis.mesh = x_box
		x_axis.position = Vector3(attachment_debug_gizmo_size * 0.8, 0.0, 0.0)
		var x_material := StandardMaterial3D.new()
		x_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		x_material.albedo_color = Color(1.0, 0.2, 0.2, 1.0)
		x_axis.material_override = x_material
		gizmo_root.add_child(x_axis)

		var y_axis := MeshInstance3D.new()
		y_axis.name = "YAxis"
		var y_box := BoxMesh.new()
		y_box.size = Vector3(attachment_debug_gizmo_size * 0.18, attachment_debug_gizmo_size * 1.6, attachment_debug_gizmo_size * 0.18)
		y_axis.mesh = y_box
		y_axis.position = Vector3(0.0, attachment_debug_gizmo_size * 0.8, 0.0)
		var y_material := StandardMaterial3D.new()
		y_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		y_material.albedo_color = Color(0.2, 1.0, 0.2, 1.0)
		y_axis.material_override = y_material
		gizmo_root.add_child(y_axis)

		var z_axis := MeshInstance3D.new()
		z_axis.name = "ZAxis"
		var z_box := BoxMesh.new()
		z_box.size = Vector3(attachment_debug_gizmo_size * 0.18, attachment_debug_gizmo_size * 0.18, attachment_debug_gizmo_size * 1.6)
		z_axis.mesh = z_box
		z_axis.position = Vector3(0.0, 0.0, attachment_debug_gizmo_size * 0.8)
		var z_material := StandardMaterial3D.new()
		z_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		z_material.albedo_color = Color(0.2, 0.55, 1.0, 1.0)
		z_axis.material_override = z_material
		gizmo_root.add_child(z_axis)

	gizmo_root.visible = true

	var marker_mesh := gizmo_root.get_node_or_null("Marker") as MeshInstance3D
	if marker_mesh != null and marker_mesh.mesh is BoxMesh:
		(marker_mesh.mesh as BoxMesh).size = Vector3.ONE * attachment_debug_gizmo_size

func _remove_attachment_debug_gizmo(slot_name: String) -> void:
	var gizmo_root := attachment_debug_gizmos.get(slot_name, null) as Node3D
	if gizmo_root != null and is_instance_valid(gizmo_root):
		gizmo_root.queue_free()
	attachment_debug_gizmos.erase(slot_name)

func _get_debug_color_for_slot(slot_name: String) -> Color:
	match slot_name:
		"right_hand":
			return Color(1.0, 0.75, 0.2, 1.0)
		"left_hand":
			return Color(0.2, 0.9, 1.0, 1.0)
		"lower_back":
			return Color(0.8, 0.35, 1.0, 1.0)
		"gun_support":
			return Color(0.7, 0.7, 0.7, 1.0)
		_:
			return Color(1.0, 1.0, 1.0, 1.0)

func _update_equipped_visual(slot_name: String, entry: Dictionary) -> void:
	var anchor := _get_slot_anchor(slot_name)
	if anchor == null:
		return

	var visual := equipped_visuals.get(slot_name, null) as Node3D
	var desired_scene: PackedScene = entry.get("equipped_visual_scene", null)
	if visual == null or not _matches_equipped_scene(visual, desired_scene):
		if is_instance_valid(visual):
			visual.queue_free()
		visual = _instantiate_equipped_visual(entry)
		if visual == null:
			return
		anchor.add_child(visual)
		equipped_visuals[slot_name] = visual

	_apply_visual_profile(visual, entry)

func _instantiate_equipped_visual(entry: Dictionary) -> Node3D:
	var equipped_scene: PackedScene = entry.get("equipped_visual_scene", null)
	if equipped_scene != null:
		var scene_instance := equipped_scene.instantiate() as Node3D
		if scene_instance != null:
			scene_instance.set_meta("equipped_scene_path", equipped_scene.resource_path)
			return scene_instance

	var definition: ItemDefinition = entry.get("definition", null)
	if definition == null:
		return null

	var visual := MeshInstance3D.new()
	visual.mesh = _build_placeholder_mesh(definition)
	var material := StandardMaterial3D.new()
	material.albedo_color = definition.placeholder_visual_color
	visual.material_override = material
	return visual

func _matches_equipped_scene(visual: Node3D, equipped_scene: PackedScene) -> bool:
	if visual == null:
		return false
	if equipped_scene == null:
		return visual is MeshInstance3D
	return str(visual.get_meta("equipped_scene_path", "")) == equipped_scene.resource_path

func _apply_visual_profile(visual: Node3D, entry: Dictionary) -> void:
	var profile: ItemVisualAttachmentProfile = entry.get("attachment_profile", null)
	if profile == null:
		visual.position = Vector3.ZERO
		visual.rotation = Vector3.ZERO
		visual.scale = Vector3.ONE
		return

	visual.position = profile.position
	visual.rotation_degrees = profile.rotation_degrees
	visual.scale = profile.scale

func _update_slot_interactable(slot_name: String, entry: Dictionary) -> void:
	var inventory := _resolve_inventory()
	if inventory == null:
		return

	var visual_state: String = entry.get("visual_state", "")
	if visual_state == "held":
		_remove_slot_interactable(slot_name)
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

func _remove_slot_interactable(slot_name: String) -> void:
	var interactable := mounted_interactables.get(slot_name, null) as Area3D
	if interactable != null and is_instance_valid(interactable):
		interactable.queue_free()
	mounted_interactables.erase(slot_name)

func _get_slot_anchor(slot_name: String) -> Node3D:
	if attachment_content_roots.has(slot_name):
		return attachment_content_roots[slot_name] as Node3D
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

func get_attachment_point_world_positions() -> Dictionary:
	var positions := {}
	for slot_name in attachment_content_roots.keys():
		var anchor := attachment_content_roots[slot_name] as Node3D
		if anchor != null and is_instance_valid(anchor):
			positions[slot_name] = anchor.global_position
	return positions
