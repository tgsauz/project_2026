extends Node
class_name VisualsComponent

signal equipped_visual_attached(slot_name: String, item_id: String, visual: Node3D, entry: Dictionary)
signal equipped_visual_detached(slot_name: String, item_id: String)

@export_category("Tilt")
@export var tilt_strength: float = 0.08
@export var tilt_smoothing: float = 6.0
@export var max_tilt_angle: float = 0.35

@export_category("Helpers")
@export var gun_support_bone_name: String = "ik_hand_gun"
@export var attachment_content_scale_compensation: float = 1.0
@export var fps_hidden_bone_names: PackedStringArray = PackedStringArray(["head", "Head"])
@export var fps_hidden_bone_scale: Vector3 = Vector3(0.01, 0.01, 0.01)

@export_category("Debug")
@export var show_attachment_debug_gizmos: bool = false
@export var attachment_debug_gizmo_size: float = 0.06

var skeleton: Skeleton3D
var bone_idx: int = -1
var attachment_roots: Dictionary = {}
var attachment_content_roots: Dictionary = {}
var equipped_visuals: Dictionary = {}
var equipped_visual_entries: Dictionary = {}
var mounted_interactables: Dictionary = {}
var attachment_debug_gizmos: Dictionary = {}
var attachment_node_data: Dictionary = {}
var tuner_attachment_points: Dictionary = {}
var bound_inventory: InventoryComponent
var tuner_host_root: Node3D
var tuner_skeleton_path: NodePath = NodePath()
var _fps_hidden_bone_indices: Array[int] = []
var _fps_head_hidden: bool = false

var tilt: Vector2 = Vector2.ZERO

func _ready():
	skeleton = _resolve_tuner_skeleton()
	
	if skeleton == null:
		push_error("[VisualsComponent] Could not resolve Skeleton3D in configured host subtree.")
		return

	var spine_slot := AttachmentLayoutLibrary.get_default_point("back_mount")
	var tilt_bone_name := spine_slot.anchor_bone_name if spine_slot != null else "spine_02"
	bone_idx = skeleton.find_bone(tilt_bone_name)
	if bone_idx == -1:
		push_warning("VisualsComponent could not find bone '%s'." % tilt_bone_name)

	_ensure_attachment_roots()
	_refresh_fps_hidden_bone_cache()
	_refresh_attachment_debug_gizmos()

func _process(_delta: float) -> void:
	_refresh_dynamic_equipped_visual_transforms()

func configure_tuner_context(host_root: Node3D, skeleton_path: NodePath = NodePath()) -> void:
	tuner_host_root = host_root
	tuner_skeleton_path = skeleton_path

func refresh_tuner_context() -> void:
	skeleton = _resolve_tuner_skeleton()
	if skeleton == null:
		push_warning("[VisualsComponent] refresh_tuner_context failed: skeleton unresolved.")
		return
	_ensure_attachment_roots()
	_refresh_fps_hidden_bone_cache()
	_refresh_attachment_debug_gizmos()

func set_first_person_head_hidden(hidden: bool) -> void:
	_fps_head_hidden = hidden
	_apply_first_person_head_visibility()

func _resolve_tuner_skeleton() -> Skeleton3D:
	var host: Node = tuner_host_root
	if host == null:
		var rig = get_node_or_null("Rig") as Node3D
		if rig != null:
			host = rig
		else:
			host = self

	if not tuner_skeleton_path.is_empty():
		var explicit := host.get_node_or_null(tuner_skeleton_path) as Skeleton3D
		if explicit != null:
			return explicit
		push_warning("[VisualsComponent] skeleton_path could not be resolved: %s" % str(tuner_skeleton_path))

	var found := _find_skeleton_recursive(host)
	if found != null:
		return found

	if host != self:
		found = _find_skeleton_recursive(self)
		if found != null:
			push_warning("[VisualsComponent] Falling back to self subtree skeleton discovery.")
			return found
	return null

func _find_skeleton_recursive(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found = _find_skeleton_recursive(child)
		if found:
			return found
	return null

func _refresh_fps_hidden_bone_cache() -> void:
	_fps_hidden_bone_indices.clear()
	if skeleton == null:
		return

	for bone_name in fps_hidden_bone_names:
		var candidate := str(bone_name)
		if candidate.is_empty():
			continue
		var bone_idx_candidate := skeleton.find_bone(candidate)
		if bone_idx_candidate == -1:
			continue
		_fps_hidden_bone_indices.append(bone_idx_candidate)

	_apply_first_person_head_visibility()

func _apply_first_person_head_visibility() -> void:
	if skeleton == null:
		return

	var target_scale := fps_hidden_bone_scale if _fps_head_hidden else Vector3.ONE
	for bone_idx_candidate in _fps_hidden_bone_indices:
		skeleton.set_bone_pose_scale(bone_idx_candidate, target_scale)

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
#  TUNER API
# ============================================================

func set_runtime_visual(slot_name: String, entry: Dictionary) -> Node3D:
	# This allows the tuner to force an item into a slot manually
	_ensure_attachment_roots()
	# Ensure the specific slot has an attachment root for tuner use cases
	_ensure_attachment_root_for_tuner(slot_name)
	_update_equipped_visual(slot_name, entry)
	return get_active_visual(slot_name, str(entry.get("item_id", "")))

func clear_runtime_visual(slot_name: String) -> void:
	var keys_to_remove = []
	for visual_key in equipped_visuals.keys():
		if visual_key.begins_with(slot_name + "_"):
			keys_to_remove.append(visual_key)
			
	for visual_key in keys_to_remove:
		var visual = equipped_visuals[visual_key]
		var removed_entry: Dictionary = equipped_visual_entries.get(visual_key, {}) as Dictionary
		var removed_item_id: String = str(removed_entry.get("item_id", ""))
		if is_instance_valid(visual):
			visual.queue_free()
		equipped_visuals.erase(visual_key)
		equipped_visual_entries.erase(visual_key)
		emit_signal("equipped_visual_detached", slot_name, removed_item_id)
		_remove_slot_interactable(slot_name)

func get_active_visual(slot_name: String, item_id: String = "") -> Node3D:
	var visual_key = slot_name
	if not item_id.is_empty():
		visual_key = slot_name + "_" + item_id
	else:
		# Search for first one if ID is empty
		for k in equipped_visuals.keys():
			if k.begins_with(slot_name + "_"):
				visual_key = k
				break
				
	return equipped_visuals.get(visual_key, null)

func get_active_visual_entry(slot_name: String, item_id: String = "") -> Dictionary:
	var visual_key: String = slot_name
	if not item_id.is_empty():
		visual_key = slot_name + "_" + item_id
	else:
		for k in equipped_visual_entries.keys():
			if k.begins_with(slot_name + "_"):
				visual_key = k
				break

	var entry: Dictionary = equipped_visual_entries.get(visual_key, {}) as Dictionary
	return entry.duplicate(true)

func register_tuner_attachment_points(points: Array[AttachmentPointDefinition]) -> void:
	tuner_attachment_points.clear()
	for point in points:
		if point == null or point.node_id.is_empty():
			continue
		tuner_attachment_points[point.node_id] = point

# ============================================================
#  EQUIPMENT VISUALS
# ============================================================

func bind_inventory(inventory: InventoryComponent) -> void:
	if inventory == null:
		return
	bound_inventory = inventory
	if not inventory.inventory_updated.is_connected(_on_inventory_layout_changed):
		inventory.inventory_updated.connect(_on_inventory_layout_changed)
	if not inventory.equipment_visuals_changed.is_connected(_on_equipment_visuals_changed):
		inventory.equipment_visuals_changed.connect(_on_equipment_visuals_changed)
	_on_inventory_layout_changed()
	_on_equipment_visuals_changed(inventory.get_equipped_visuals())

func _on_inventory_layout_changed() -> void:
	if bound_inventory == null:
		return
	_ensure_attachment_roots_for_nodes(bound_inventory.get_available_attachment_nodes(true))

func _on_equipment_visuals_changed(visible_items: Array) -> void:
	_ensure_attachment_roots()

	var active_visual_keys: Dictionary = {}
	for entry in visible_items:
		var slot_name: String = entry.get("slot_name", "")
		var item_id: String = str(entry.get("item_id", ""))
		var definition: ItemDefinition = entry.get("definition", null)
		if slot_name.is_empty() or definition == null:
			continue
		
		var visual_key: String = "%s_%s" % [slot_name, item_id]
		active_visual_keys[visual_key] = true
		
		print_debug("[VisualsComponent] Processing item: %s (%s) in slot: %s" % [definition.display_name, item_id, slot_name])
		_update_equipped_visual(slot_name, entry)
		_update_slot_interactable(slot_name, entry)

	# Clean up visuals that are no longer active
	var keys_to_remove = []
	for visual_key in equipped_visuals.keys():
		if not active_visual_keys.has(visual_key):
			keys_to_remove.append(visual_key)
			
	for visual_key in keys_to_remove:
		var visual := equipped_visuals[visual_key] as Node3D
		var removed_entry: Dictionary = equipped_visual_entries.get(visual_key, {}) as Dictionary
		var removed_slot_name: String = str(removed_entry.get("slot_name", ""))
		var removed_item_id: String = str(removed_entry.get("item_id", ""))
		if is_instance_valid(visual):
			print_debug("[VisualsComponent] Removing visual for key: %s" % visual_key)
			visual.queue_free()
		equipped_visuals.erase(visual_key)
		equipped_visual_entries.erase(visual_key)
		emit_signal("equipped_visual_detached", removed_slot_name, removed_item_id)

	# Clean up interactables that are no longer active (using same logic)
	var interactable_keys_to_remove = []
	for slot_name in mounted_interactables.keys():
		# Note: interactables are still mapped by slot_name for now as they are per-mount
		var has_active_item_in_slot = false
		for k in active_visual_keys.keys():
			if k.begins_with(slot_name + "_"):
				has_active_item_in_slot = true
				break
		
		if not has_active_item_in_slot:
			interactable_keys_to_remove.append(slot_name)
			
	for slot_name in interactable_keys_to_remove:
		var interactable := mounted_interactables[slot_name] as Area3D
		if is_instance_valid(interactable):
			interactable.queue_free()
		mounted_interactables.erase(slot_name)

func _ensure_attachment_root_for_tuner(slot_name: String) -> void:
	if skeleton == null or slot_name.is_empty():
		return
	
	# Skip if already created
	if attachment_roots.has(slot_name):
		return
	
	# Resolve from explicitly injected tuner points first.
	var point := tuner_attachment_points.get(slot_name, null) as AttachmentPointDefinition
	if point == null and attachment_node_data.has(slot_name):
		var node_data := attachment_node_data[slot_name] as Dictionary
		var bone_name := str(node_data.get("anchor_bone_name", ""))
		if bone_name.is_empty():
			push_warning("[VisualsComponent] Missing anchor bone for tuner slot '%s'." % slot_name)
			return
		_ensure_attachment_root(
			slot_name,
			bone_name,
			node_data.get("anchor_local_position", Vector3.ZERO),
			node_data.get("anchor_local_rotation", Vector3.ZERO)
		)
		return
	if point == null:
		point = AttachmentLayoutLibrary.get_default_point(slot_name)
	if point == null:
		push_warning("[VisualsComponent] Could not resolve tuner attachment point for slot '%s'." % slot_name)
		return
	
	# Create the attachment root for this slot
	_ensure_attachment_root(slot_name, point.anchor_bone_name, point.anchor_local_position, point.anchor_local_rotation)

func _ensure_attachment_roots() -> void:
	if skeleton == null:
		return

	var nodes := []
	if bound_inventory != null:
		nodes = bound_inventory.get_available_attachment_nodes(true)
	_ensure_attachment_roots_for_nodes(nodes)

func _ensure_attachment_roots_for_nodes(nodes: Array) -> void:
	if skeleton == null:
		return

	for node_data in nodes:
		var node_id := str(node_data.get("node_id", ""))
		var bone_name := str(node_data.get("anchor_bone_name", ""))
		if node_id.is_empty() or bone_name.is_empty():
			continue
		attachment_node_data[node_id] = node_data.duplicate(true)
		_ensure_attachment_root(node_id, bone_name, node_data.get("anchor_local_position", Vector3.ZERO), node_data.get("anchor_local_rotation", Vector3.ZERO))
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
	if attachment_node_data.has(slot_name):
		return attachment_node_data[slot_name].get("debug_color", Color.WHITE)

	match slot_name:
		"gun_support":
			return Color(0.7, 0.7, 0.7, 1.0)
		_:
			return Color(1.0, 1.0, 1.0, 1.0)

func _update_equipped_visual(slot_name: String, entry: Dictionary) -> void:
	var item_id: String = str(entry.get("item_id", ""))
	var definition: ItemDefinition = entry.get("definition", null)
	var is_skinned: bool = definition.is_skinned_mesh if definition != null else false

	var anchor: Node3D = skeleton if is_skinned else _get_slot_anchor(slot_name)
	if anchor == null:
		print_debug("[VisualsComponent] WARNING: No anchor found for slot: %s" % slot_name)
		return

	# Use a unique key combining slot and item_id to allow multiple items per slot (e.g. backpack + items on it)
	var visual_key: String = "%s_%s" % [slot_name, item_id]
	var visual := equipped_visuals.get(visual_key, null) as Node3D
	var desired_scene: PackedScene = entry.get("equipped_visual_scene", null)

	if visual == null or not _matches_equipped_scene(visual, desired_scene):
		if is_instance_valid(visual):
			visual.queue_free()

		visual = _instantiate_equipped_visual(entry)
		if visual == null:
			print_debug("[VisualsComponent] ERROR: Failed to instantiate visual for %s" % item_id)
			return

		# Apply handle-socket alignment before adding to the tree so the node
		# joins at the correct local offset (no frame delay, no global-transform
		# dependency). The profile offset is applied on top afterward.
		_apply_handle_alignment(visual, definition)

		anchor.add_child(visual)
		equipped_visuals[visual_key] = visual

		if is_skinned:
			_fix_skinned_visuals(visual)

	visual.visible = true
	_apply_visual_profile(visual, entry)
	equipped_visual_entries[visual_key] = entry.duplicate(true)
	emit_signal("equipped_visual_attached", slot_name, item_id, visual, equipped_visual_entries[visual_key].duplicate(true))

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

func _refresh_dynamic_equipped_visual_transforms() -> void:
	for visual_key_variant in equipped_visuals.keys():
		var visual_key: String = str(visual_key_variant)
		var visual: Node3D = equipped_visuals.get(visual_key, null) as Node3D
		if visual == null or not is_instance_valid(visual):
			continue

		var entry: Dictionary = equipped_visual_entries.get(visual_key, {}) as Dictionary
		if entry.is_empty():
			continue

		_apply_visual_profile(visual, entry)

# ============================================================
#  HANDLE ALIGNMENT
# ============================================================

## Offsets the visual root so that the semantic "Handle" node inside it sits
## at the bone attachment origin instead of the scene's geometric origin.
##
## Rationale: A weapon's GLB origin may not coincide with the grip — this is
## common when artists export at world-space coordinates. By declaring a child
## node named `handle_node_name` at the intended grip position, we can
## compute its local offset and invert it onto the root, eliminating the need
## to edit the .glb file or use large counter-offsets in the profile.
##
## Composition order:
##   handle_alignment_offset (this function) ← applied first at instantiation
##   + profile_offset (_apply_visual_profile) ← applied on top each frame
##
## If no Handle node is found the root transform is left at identity, which
## reproduces the original origin-based behavior exactly.
func _apply_handle_alignment(visual: Node3D, definition: ItemDefinition) -> void:
	if definition == null or definition.handle_node_name.is_empty():
		return

	# We search WITHOUT requiring ownership so the node can be any depth inside
	# the scene, matching the convention used by LeftHandIKComponent for LGRIP.
	var handle := visual.find_child(definition.handle_node_name, true, false) as Node3D
	if handle == null:
		# No handle node declared — origin-based attachment is intentional.
		return

	# Compute the handle's local transform relative to the visual root.
	# Inverting it shifts the root so the handle lands exactly at (0,0,0)
	# of the parent bone attachment, which is what "grip at bone" means.
	var handle_local: Transform3D = handle.transform
	var parent: Node3D = handle.get_parent() as Node3D
	while parent != null and parent != visual:
		handle_local = parent.transform * handle_local
		parent = parent.get_parent() as Node3D

	visual.transform = handle_local.affine_inverse()
	visual.set_meta("handle_alignment_applied", true)

func _apply_visual_profile(visual: Node3D, entry: Dictionary) -> void:
	var profile: ItemVisualAttachmentProfile = entry.get("attachment_profile", null)

	# If a handle alignment was applied, the profile offset layers on top of it.
	# We must restore the alignment base first, then add the profile delta so
	# that repeated calls to _apply_visual_profile remain idempotent.
	var has_handle: bool = visual.get_meta("handle_alignment_applied", false)
	if has_handle:
		var definition: ItemDefinition = entry.get("definition", null)
		_apply_handle_alignment(visual, definition)

	if profile == null:
		# No profile: leave the current transform (handle-aligned or origin-based).
		return

	if has_handle:
		# Compose: apply profile as an additional local offset on the aligned root.
		visual.position += visual.basis * profile.position
		# Use Basis math instead of adding Euler angles to avoid Gimbal Lock and offset swizzling.
		var profile_rot := Basis.from_euler(Vector3(
			deg_to_rad(profile.rotation_degrees.x),
			deg_to_rad(profile.rotation_degrees.y),
			deg_to_rad(profile.rotation_degrees.z)
		))
		visual.basis = visual.basis * profile_rot
		visual.scale *= profile.scale
	else:
		# Legacy path: profile fully overrides the transform (original behavior).
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

func _fix_skinned_visuals(root: Node) -> void:
	if skeleton == null:
		return
	if root is MeshInstance3D:
		root.skeleton = root.get_path_to(skeleton)
	for child in root.get_children():
		_fix_skinned_visuals(child)
