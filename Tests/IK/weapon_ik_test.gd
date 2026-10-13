extends Node3D

# ============================================================
# WEAPON / IK TEST HARNESS  (permanent, reusable)
# ============================================================
# Loads the player and equips a weapon at startup so weapon
# attachment and the arm IK can be inspected WITHOUT manually
# walking to a pickup.
#
# Usage:
#   - Open/run res://Tests/IK/weapon_ik_test.tscn.
#   - Press J for the live IK reach diagnostic (debug_ik_reach).
#   - Press F3 to toggle FPS/TPS (toggle_camera).
#   - Change "Weapon Definition" in the Inspector to test others.
#
# This scene intentionally mirrors testing_world's world (ground +
# environment + light + UIRoot) so results reflect the real game.
# ============================================================

@export var player_path: NodePath = NodePath("CharacterBody3D")
@export var weapon_definition: ItemDefinition
@export var weapon_slot: String = "right_hand"
## Start in third-person so the whole body, arms and weapon are visible.
@export var start_third_person: bool = true
## Print the FullBodyIKController reach diagnostic shortly after equipping.
@export var print_ik_diagnostic: bool = true
## Enables an isolated test layer: WeaponRoot copies ik_hand_gun exactly.
## Aim-layer composition is also removed for this socket-only test.
@export var experimental_socket_pose: bool = false
## Isolated transform audit: evaluates each weapon/grip basis and positional candidate.
@export var run_transform_audit: bool = false
## Test-only mode: parent the weapon under a BoneAttachment3D on ik_hand_gun.
## WeaponController processing is disabled so the engine alone supplies its transform.
@export var direct_socket_bone_attachment: bool = false

func _ready() -> void:
	call_deferred("_setup_harness")

func _input(event: InputEvent) -> void:
	if direct_socket_bone_attachment and event.is_action_pressed("debug_spine_weapon_align"):
		call_deferred("_print_direct_attachment_state")

func _print_direct_attachment_state() -> void:
	var player: Node = get_node_or_null(player_path)
	var controller: WeaponController = player.get_node_or_null("WeaponRoot/WeaponController") as WeaponController if player != null else null
	if controller == null:
		return
	var attachment: BoneAttachment3D = controller._skeleton.get_node_or_null("DirectIKHandGunAttachment") as BoneAttachment3D if controller._skeleton != null else null
	var weapon_visual: Node3D = controller._get_weapon_visual()
	if attachment == null or weapon_visual == null:
		return
	var relative: Transform3D = attachment.global_transform.affine_inverse() * weapon_visual.global_transform
	var weapon_forward: Vector3 = -weapon_visual.global_basis.z.normalized()
	var weapon_pitch: float = rad_to_deg(asin(clampf(weapon_forward.y, -1.0, 1.0)))
	print("[DIRECT_ATTACHMENT] parent=", weapon_visual.get_parent().get_path(), " weapon_pitch=", weapon_pitch, "deg relative_to_bone=", relative)

	var aim_controller: AimController = player.get_node_or_null("AimController") as AimController
	var aim_state: AimState = aim_controller.get_aim_state() if aim_controller != null else null
	if aim_state != null and aim_state.is_valid:
		var muzzle: Node3D = weapon_visual.find_child("MUZZLE", true, false) as Node3D
		var rgrip: Node3D = weapon_visual.find_child("RGRIP", true, false) as Node3D
		if muzzle != null and rgrip != null:
			var muzzle_axis: Vector3 = -muzzle.global_basis.z.normalized()
			var muzzle_dot: float = muzzle_axis.dot(aim_state.aim_direction.normalized())
			var grip_to_muzzle: Vector3 = (muzzle.global_position - rgrip.global_position).normalized()
			var sight_back: Node3D = weapon_visual.find_child("SIGHT_BACK", true, false) as Node3D
			var sight_front: Node3D = weapon_visual.find_child("SIGHT_FRONT", true, false) as Node3D
			var sight_axis: Vector3 = (sight_front.global_position - sight_back.global_position).normalized() if sight_back != null and sight_front != null else Vector3.ZERO
			print("[MUZZLE_AIM] pitch=", rad_to_deg(aim_state.look_pitch), " aim_dir=", aim_state.aim_direction, " muzzle_-Z=", muzzle_axis, " muzzle_angle=", rad_to_deg(acos(clampf(muzzle_dot, -1.0, 1.0))), " RGRIP_to_muzzle=", grip_to_muzzle, " sight_axis=", sight_axis)
		else:
			print("[MUZZLE_AIM] Missing MUZZLE or RGRIP marker on equipped visual.")

	var skeleton: Skeleton3D = controller._skeleton
	var spine_controller: SpineLookAtController = skeleton.get_node_or_null("SpineLookAtController") as SpineLookAtController
	var look_target: Node3D = skeleton.get_node_or_null("LookAtTarget") as Node3D
	var pelvis_index: int = skeleton.find_bone("pelvis")
	if spine_controller != null and look_target != null and pelvis_index >= 0:
		var pelvis_pose: Transform3D = skeleton.get_bone_global_pose(pelvis_index)
		var pelvis_world: Vector3 = skeleton.global_transform * pelvis_pose.origin
		var target_delta: Vector3 = look_target.global_position - pelvis_world
		print("[SPINE_TARGET_VECTOR] influence=", spine_controller._current_influence, " target_delta=", target_delta, " len=", target_delta.length())

func _setup_harness() -> void:
	var player := get_node_or_null(player_path)
	if player == null:
		push_error("[WeaponIKTest] Player not found at '%s'." % str(player_path))
		return

	if start_third_person:
		_apply_third_person(player)

	if experimental_socket_pose:
		if direct_socket_bone_attachment:
			_set_crosshair_mouse_passthrough(player)
		else:
			_configure_experimental_pose(player)

	_equip_weapon(player)

	if direct_socket_bone_attachment:
		_configure_direct_socket_attachment(player)

	if run_transform_audit:
		await get_tree().create_timer(0.3).timeout
		_run_transform_audit(player)

	if print_ik_diagnostic:
		# Let a few frames pass so IK weights and targets settle.
		await get_tree().create_timer(0.25).timeout
		_print_ik_diagnostic(player)

func _set_crosshair_mouse_passthrough(player: Node) -> void:
	var crosshair: Control = player.get_node_or_null("UIRoot/GameplayLayer/HUD/Crosshair") as Control
	if crosshair == null:
		push_warning("[WeaponIKTest] Crosshair not found; experimental mouse passthrough was not applied.")
		return
	_set_control_tree_mouse_filter(crosshair)
	print("[WeaponIKTest] EXPERIMENT mouse fix: crosshair visuals ignore mouse input so RMB can reach gameplay.")

func _set_control_tree_mouse_filter(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_set_control_tree_mouse_filter(child as Control)

func _configure_experimental_pose(player: Node) -> void:
	_set_crosshair_mouse_passthrough(player)

	var controller: WeaponController = player.get_node_or_null("WeaponRoot/WeaponController") as WeaponController
	if controller == null or controller._layer_stack == null or controller._base_layer == null:
		push_error("[WeaponIKTest] Cannot enable experimental pose: WeaponController is not initialized.")
		return
	if controller._skeleton == null:
		push_error("[WeaponIKTest] Cannot enable experimental pose: Skeleton3D is unavailable.")
		return

	var experimental_layer := WeaponLayerSocketPositionTest.new(controller._skeleton)
	controller._layer_stack.remove_layer(controller._base_layer)
	controller._base_layer = experimental_layer
	controller._layer_stack.add_layer(experimental_layer)
	if controller._aim_layer != null:
		controller._layer_stack.remove_layer(controller._aim_layer)
	print("[WeaponIKTest] SOCKET-ONLY enabled: WeaponRoot copies ik_hand_gun world transform; no grip offset, roll correction, or aim layer.")

func _configure_direct_socket_attachment(player: Node) -> void:
	var controller: WeaponController = player.get_node_or_null("WeaponRoot/WeaponController") as WeaponController
	if controller == null or controller._skeleton == null:
		push_error("[WeaponIKTest] Direct socket test requires WeaponController and Skeleton3D.")
		return

	var weapon_visual: Node3D = controller._get_weapon_visual()
	if weapon_visual == null:
		push_error("[WeaponIKTest] Direct socket test could not resolve the equipped weapon visual.")
		return

	# Stop the transform-authority script, then let BoneAttachment3D follow
	# ik_hand_gun through Skeleton3D's native bone attachment update.
	controller.set_process(false)
	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = "DirectIKHandGunAttachment"
	attachment.bone_name = "ik_hand_gun"
	controller._skeleton.add_child(attachment)

	var old_parent: Node = weapon_visual.get_parent()
	if old_parent != null:
		old_parent.remove_child(weapon_visual)
	attachment.add_child(weapon_visual)
	weapon_visual.transform = Transform3D.IDENTITY

	print("[WeaponIKTest] DIRECT BONE ATTACHMENT enabled: weapon is child of BoneAttachment3D(ik_hand_gun); WeaponController processing disabled.")

func _equip_weapon(player: Node) -> void:
	if weapon_definition == null:
		push_warning("[WeaponIKTest] No weapon_definition assigned; nothing equipped.")
		return

	var inventory: Node = null
	if player.has_method("get_inventory_component"):
		inventory = player.get_inventory_component()
	if inventory == null:
		inventory = player.get_node_or_null("InventoryComponent")
	if inventory == null:
		push_error("[WeaponIKTest] Player has no InventoryComponent.")
		return
	if not inventory.has_method("attach_item"):
		push_error("[WeaponIKTest] InventoryComponent has no attach_item().")
		return

	var item := ItemInstance.create_from_definition(weapon_definition, 1)
	var ok: bool = inventory.attach_item(item, weapon_slot)
	print("[WeaponIKTest] Equipped '%s' into '%s': %s" % [weapon_definition.display_name, weapon_slot, ok])

func _apply_third_person(player: Node) -> void:
	var camera_controller := player.get_node_or_null("CAMERARIG")
	if camera_controller != null and camera_controller.has_method("_set_camera_mode"):
		camera_controller._set_camera_mode(false)

func _run_transform_audit(player: Node) -> void:
	var controller: WeaponController = player.get_node_or_null("WeaponRoot/WeaponController") as WeaponController
	if controller == null or controller._skeleton == null:
		push_error("[TransformAudit] WeaponController/Skeleton unavailable.")
		return

	var weapon_visual: Node3D = controller._get_weapon_visual()
	if weapon_visual == null:
		push_error("[TransformAudit] Equipped weapon visual unavailable.")
		return

	var skeleton: Skeleton3D = controller._skeleton
	var gun_bone_idx: int = skeleton.find_bone("ik_hand_gun")
	if gun_bone_idx < 0:
		push_error("[TransformAudit] ik_hand_gun bone unavailable.")
		return

	var weapon_xform: Transform3D = controller.weapon_root.global_transform
	var socket_xform: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(gun_bone_idx)
	var socket_forward: Vector3 = -socket_xform.basis.z.normalized()
	var muzz: Node3D = weapon_visual.find_child("MUZZLE", true, false) as Node3D
	var sight_back: Node3D = weapon_visual.find_child("SIGHT_BACK", true, false) as Node3D
	var sight_front: Node3D = weapon_visual.find_child("SIGHT_FRONT", true, false) as Node3D
	var rgrip_pos: Vector3 = (weapon_xform * controller._cached_rgrip_local).origin
	var lgrip_pos: Vector3 = (weapon_xform * controller._cached_lgrip_local).origin
	var muzzle_pos: Vector3 = muzz.global_position if muzz != null else rgrip_pos
	var sight_axis: Vector3 = (sight_front.global_position - sight_back.global_position).normalized() if sight_back != null and sight_front != null else Vector3.ZERO
	var muzzle_axis: Vector3 = (muzzle_pos - rgrip_pos).normalized()
	var rgrip_l: Vector3 = controller._cached_rgrip_local.origin
	var lgrip_l: Vector3 = controller._cached_lgrip_local.origin

	print("===== WEAPON TRANSFORM AUDIT =====")
	print("socket world origin=", socket_xform.origin, " forward(-Z)=", socket_forward, " socket Z=", socket_xform.basis.z.normalized())
	print("weapon root world=", weapon_xform)
	print("RGRIP local=", rgrip_l, " world=", rgrip_pos)
	print("LGRIP local=", lgrip_l, " world=", lgrip_pos, " R-L separation=", rgrip_l.distance_to(lgrip_l))
	print("MUZZLE world=", muzzle_pos, " RGRIP→MUZZLE=", muzzle_axis, " angle to weapon -Z=", rad_to_deg(acos(clampf(muzzle_axis.dot(-weapon_xform.basis.z.normalized()), -1.0, 1.0))))
	if sight_axis != Vector3.ZERO:
		print("SIGHT_BACK→FRONT=", sight_axis, " angle to weapon -Z=", rad_to_deg(acos(clampf(sight_axis.dot(-weapon_xform.basis.z.normalized()), -1.0, 1.0))))
	print("RGRIP basis X/Y/Z=", controller._cached_rgrip_local.basis.x, " / ", controller._cached_rgrip_local.basis.y, " / ", controller._cached_rgrip_local.basis.z)
	print("LGRIP basis X/Y/Z=", controller._cached_lgrip_local.basis.x, " / ", controller._cached_lgrip_local.basis.y, " / ", controller._cached_lgrip_local.basis.z)

	var modifier: TwoBoneIK3D = controller._fullbody_ik._modifiers.get("LeftArmIK") as TwoBoneIK3D if controller._fullbody_ik != null else null
	if modifier != null:
		print("Left IK root/middle/end=", modifier.get_root_bone_name(0), " / ", modifier.get_middle_bone_name(0), " / ", modifier.get_end_bone_name(0), " target=", modifier.get_target_node(0), " pole=", modifier.get_pole_node(0), " influence=", modifier.influence)
	print("==================================")

func _print_ik_diagnostic(player: Node) -> void:
	var fbik := player.get_node_or_null(
		"VisualsComponent/Rig/ImportedModel/Armature/Skeleton3D/FullBodyIKController")
	if fbik != null and fbik.has_method("_debug_print_ik_reach"):
		fbik._debug_print_ik_reach()
	else:
		push_warning("[WeaponIKTest] FullBodyIKController not found for diagnostic.")
