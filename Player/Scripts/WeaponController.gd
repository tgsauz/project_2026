extends Node
class_name WeaponController

# ============================================================
# WEAPON CONTROLLER
# Orchestrates weapon positioning via WeaponLayerStack.
# Produces GripTarget from WeaponRoot x grip markers.
# NOT a SkeletonModifier3D — runs in _process, independent of
# the skeleton modification pipeline (ADR-3).
# ============================================================

@export var aim_controller_path: NodePath
@export var fullbody_ik_path: NodePath
@export var visuals_component_path: NodePath
@export var character_controller_path: NodePath

var weapon_root: Node3D

var _aim_controller: AimController
var _fullbody_ik: FullBodyIKController
var _visuals_component: VisualsComponent
var _character_controller: CharacterController
var _layer_stack: WeaponLayerStack
var _aim_layer: WeaponLayerAim = null
var _skeleton: Skeleton3D = null
var _base_layer: WeaponLayerBase = null

# Grip marker cache (resolved from weapon visual on equip)
var _cached_rgrip_local: Transform3D = Transform3D.IDENTITY
var _cached_lgrip_local: Transform3D = Transform3D.IDENTITY
var _marker_cache_valid: bool = false
var _rgrip_found: bool = false
var _lgrip_found: bool = false

var _debug_m_pressed: bool = false
var _debug_n_pressed: bool = false
var _debug_force_holster: bool = false
var _debug_o_pressed: bool = false
var _debug_pivot_pressed: bool = false
var _debug_spaces_pressed: bool = false
var _debug_basis_pressed: bool = false

@export var debug_weapon_diagnostic: bool = false
var _diag_logger: WeaponDiagnosticLogger = null
var _diag_bone_data: Array[Dictionary] = []

# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	weapon_root = get_parent() as Node3D

	_aim_controller = get_node_or_null(aim_controller_path) as AimController
	_fullbody_ik = get_node_or_null(fullbody_ik_path) as FullBodyIKController
	_visuals_component = get_node_or_null(visuals_component_path) as VisualsComponent
	_character_controller = get_node_or_null(character_controller_path) as CharacterController

	if _aim_controller == null:
		push_warning("WeaponController: AimController not found. WeaponRoot will not be positioned.")
		set_process(false)
		return

	_layer_stack = WeaponLayerStack.new()

	if debug_weapon_diagnostic:
		_diag_logger = WeaponDiagnosticLogger.new()
		_diag_logger.open()

	if _visuals_component != null:
		var skeleton: Skeleton3D = _visuals_component.skeleton
		if skeleton != null:
			_skeleton = skeleton
			_base_layer = WeaponLayerBase.new(skeleton)
			_layer_stack.add_layer(_base_layer)
			_aim_layer = WeaponLayerAim.new()
			_layer_stack.add_layer(_aim_layer)
		if not _visuals_component.equipped_visual_attached.is_connected(_on_visual_attached):
			_visuals_component.equipped_visual_attached.connect(_on_visual_attached)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_weapon_authority"):
		_debug_m_pressed = true
	if event.is_action_pressed("debug_bone_rest"):
		_debug_n_pressed = true
	if event.is_action_pressed("debug_force_holster"):
		_debug_o_pressed = true
	if event.is_action_pressed("debug_identify_pivot"):
		_debug_pivot_pressed = true
	if event.is_action_pressed("debug_validate_spaces"):
		_debug_spaces_pressed = true
	if event.is_action_pressed("debug_validate_basis"):
		_debug_basis_pressed = true
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		_toggle_diagnostic_logger()

func _process(delta: float) -> void:
	if _aim_controller == null or weapon_root == null:
		return

	var state: AimState = _aim_controller.get_aim_state()
	if state == null or not state.is_valid:
		return

	if _debug_force_holster:
		state.aim_orientation_weight = 0.0

	if _debug_spaces_pressed:
		_layer_stack.set_debug_validate_spaces(true)

	var weapon_xform := _layer_stack.compose(state, delta)
	weapon_root.global_transform = weapon_xform

	var grip := _build_grip_target(weapon_xform)
	if _fullbody_ik != null:
		_fullbody_ik.apply_grip_target(grip)

	if _diag_logger != null and _diag_logger.is_enabled():
		var weapon_visual := _get_weapon_visual()
		var layer_results: Array[Dictionary] = _layer_stack.get_last_composition_results()
		_diag_logger.begin_frame(state, weapon_root, weapon_visual, layer_results)

		if _skeleton != null:
			if _diag_bone_data.is_empty():
				_diag_bone_data = _diag_logger.collect_skeleton_bones(_skeleton)
			_diag_logger.log_skeleton_bones(_skeleton, _diag_bone_data)

		var grip_markers: Array[Node3D] = _diag_logger.collect_grip_markers(weapon_visual)
		_diag_logger.log_grip_markers(grip_markers[0], grip_markers[1])

		var ik_targets: Array[Dictionary] = _diag_logger.collect_ik_targets(_fullbody_ik)
		_diag_logger.log_ik_targets(ik_targets)

		var relatives: Array[Dictionary] = _diag_logger.collect_relative_transforms(
			weapon_root, weapon_visual, grip_markers[0], grip_markers[1], _skeleton)
		_diag_logger.log_relative_transforms(relatives)

		_diag_logger.end_frame.call_deferred(weapon_visual)

	if _debug_spaces_pressed:
		_debug_spaces_pressed = false
		_layer_stack.set_debug_validate_spaces(false)
		_debug_validate_spaces(weapon_xform)

	if _debug_basis_pressed:
		_debug_basis_pressed = false
		_debug_validate_aim_basis(state)

	if _debug_m_pressed:
		_debug_m_pressed = false
		_debug_print_weapon_authority(state, weapon_xform)
	if _debug_n_pressed:
		_debug_n_pressed = false
		_debug_print_bone_rest()
	if _debug_o_pressed:
		_debug_o_pressed = false
		_debug_force_holster = not _debug_force_holster
		prints("[FORCE_HOLSTER] %s" % ("ON — aim_orientation_weight forced to 0" if _debug_force_holster else "OFF — normal blend restored"))
	if _debug_pivot_pressed:
		_debug_pivot_pressed = false
		_debug_identify_pivot(state, weapon_xform)

# ============================================================
# GRIP TARGET PRODUCTION
# ============================================================

## Produces GripTarget from WeaponRoot transform x cached grip markers.
## FullBodyIKController consumes this without knowing about WeaponRoot.
func _build_grip_target(weapon_xform: Transform3D) -> GripTarget:
	var result := GripTarget.new()

	if _rgrip_found:
		var right_world: Transform3D = weapon_xform * _cached_rgrip_local
		result.set_right_hand(right_world.origin, right_world.basis.get_rotation_quaternion())

	if _lgrip_found:
		var left_world: Transform3D = weapon_xform * _cached_lgrip_local
		result.set_left_hand(left_world.origin, left_world.basis.get_rotation_quaternion())

	return result

# ============================================================
# GRIP MARKER CACHE
# ============================================================

func _on_visual_attached(slot_name: String, _item_id: String, visual: Node3D, _entry: Dictionary) -> void:
	if slot_name != "right_hand":
		return

	# Cache markers BEFORE reparent (transforms are local-to-parent,
	# but the visual's markers are always relative to the visual itself,
	# so order doesn't matter — cached for clarity).
	_cache_marker_locals_from_weapon(visual)

	# Wire grip marker to base layer for grip-marker-based positioning.
	if _base_layer != null and _marker_cache_valid:
		_base_layer.set_rgrip_local(_cached_rgrip_local)

	# Reparent weapon visual under WeaponRoot so the layer stack
	# (WeaponLayerBase, WeaponLayerAim) actually
	# affects the visual. Previously the visual was under
	# BoneAttachment3D which bypassed WeaponRoot entirely.
	if visual.get_parent() != weapon_root:
		var old_parent := visual.get_parent()
		if old_parent != null:
			old_parent.remove_child(visual)
		weapon_root.add_child(visual)
		# Reset local_transform so WeaponRoot is sole position authority.
		# Without this, the visual's preserved local_transform (from old
		# parent) creates a double-offset since WeaponRoot.global_transform
		# already equals the bone's world transform.
		visual.transform = Transform3D.IDENTITY

func _cache_marker_locals_from_weapon(weapon: Node3D) -> void:
	_marker_cache_valid = false

	var rgrip := _find_weapon_marker(weapon, "RGRIP")
	var lgrip := _find_weapon_marker(weapon, "LGRIP")

	_cached_rgrip_local = weapon.global_transform.affine_inverse() * rgrip.global_transform if rgrip != null else Transform3D.IDENTITY
	_cached_lgrip_local = weapon.global_transform.affine_inverse() * lgrip.global_transform if lgrip != null else Transform3D.IDENTITY
	# Track presence per marker so GripTarget can report per-hand validity.
	_rgrip_found = rgrip != null
	_lgrip_found = lgrip != null
	_marker_cache_valid = rgrip != null or lgrip != null

static func _find_weapon_marker(weapon: Node3D, marker_name: String) -> Node3D:
	if weapon == null or marker_name.is_empty():
		return null
	if weapon.name == marker_name:
		return weapon
	return weapon.find_child(marker_name, true, false) as Node3D

# ============================================================
#  DIAGNOSTIC — M: Weapon Authority
# ============================================================

func _debug_print_weapon_authority(state: AimState, weapon_xform: Transform3D) -> void:
	if _layer_stack == null or _layer_stack.get_layer_count() == 0:
		prints("[AUTH_DIAG] No layers in stack")
		return

	var base_layer: WeaponLayerBase = null
	for layer in _layer_stack._layers:
		if layer is WeaponLayerBase:
			base_layer = layer
			break
	if base_layer == null or base_layer._skeleton == null or base_layer._gun_bone_idx == -1:
		prints("[AUTH_DIAG] WeaponLayerBase or bone not available")
		return

	var skel: Skeleton3D = base_layer._skeleton
	var bone_idx: int = base_layer._gun_bone_idx

	var bone_global: Transform3D = skel.get_bone_global_pose(bone_idx)
	var skel_rot: Quaternion = skel.global_transform.basis.get_rotation_quaternion()
	var bone_rot: Quaternion = bone_global.basis.get_rotation_quaternion()
	var bone_world_rot: Quaternion = skel_rot * bone_rot
	var bone_world_basis: Basis = Basis(bone_world_rot)
	var bone_world_pos: Vector3 = skel.global_transform * bone_global.origin

	var bone_euler: Vector3 = bone_world_basis.get_euler()
	var weapon_euler: Vector3 = weapon_xform.basis.get_euler()

	var visual: Node3D = _get_weapon_visual()
	var visual_euler: Vector3 = Vector3.ZERO
	var visual_pos: Vector3 = Vector3.ZERO
	if visual != null:
		visual_euler = visual.global_transform.basis.get_euler()
		visual_pos = visual.global_transform.origin

	var cam_pivot: Node3D = _aim_controller.camera_controller.get_active_aim_pivot() if _aim_controller.camera_controller != null else null
	var cam_fwd: Vector3 = -cam_pivot.global_transform.basis.z.normalized() if cam_pivot != null else Vector3.FORWARD
	var cam_yaw: float = atan2(-cam_fwd.x, -cam_fwd.z)
	var cam_pitch: float = state.look_pitch

	var fwd_bone: Vector3 = -bone_world_basis.z
	var fwd_weapon: Vector3 = -weapon_xform.basis.z

	prints("")
	prints("===== WEAPON AUTHORITY DIAGNOSTIC (M) =====")
	prints("[ForceHolster] %s" % ("ON" if _debug_force_holster else "OFF"))
	prints("")
	prints("--- Orientation ---")
	prints("[Bone]        euler(deg): x:%+.2f  y:%+.2f  z:%+.2f" % [rad_to_deg(bone_euler.x), rad_to_deg(bone_euler.y), rad_to_deg(bone_euler.z)])
	prints("[WeaponRoot]  euler(deg): x:%+.2f  y:%+.2f  z:%+.2f" % [rad_to_deg(weapon_euler.x), rad_to_deg(weapon_euler.y), rad_to_deg(weapon_euler.z)])
	prints("[Visual]      euler(deg): x:%+.2f  y:%+.2f  z:%+.2f" % [rad_to_deg(visual_euler.x), rad_to_deg(visual_euler.y), rad_to_deg(visual_euler.z)])
	prints("[Camera]      yaw:%+.2f deg  pitch:%+.2f deg" % [rad_to_deg(cam_yaw), rad_to_deg(cam_pitch)])
	prints("")
	prints("--- Forward Vectors ---")
	prints("[Bone fwd]    %s" % _v3(fwd_bone))
	prints("[Weapon fwd]  %s" % _v3(fwd_weapon))
	prints("[Camera fwd]  %s" % _v3(cam_fwd))
	prints("[Bone·Cam]    dot:%+.6f  angle:%+.2f deg" % [fwd_bone.dot(cam_fwd), rad_to_deg(acos(clampf(fwd_bone.dot(cam_fwd), -1.0, 1.0)))])
	prints("[Weapon·Cam]  dot:%+.6f  angle:%+.2f deg" % [fwd_weapon.dot(cam_fwd), rad_to_deg(acos(clampf(fwd_weapon.dot(cam_fwd), -1.0, 1.0)))])
	prints("")
	prints("--- Position ---")
	prints("[Bone pos]    %s" % _v3(bone_world_pos))
	prints("[WeaponRoot]  %s" % _v3(weapon_xform.origin))
	prints("[Visual]      %s" % _v3(visual_pos))
	prints("[Pos delta]   bone→weapon: %s" % _v3(weapon_xform.origin - bone_world_pos))
	prints("")
	prints("--- AimState ---")
	prints("[aim_w]       %.4f  ads_w: %.4f" % [state.aim_orientation_weight, state.ads_weight])
	prints("[aim_dir]     %s" % _v3(state.aim_direction))
	prints("[eye_pos]     %s" % _v3(state.eye_position))
	prints("")
	prints("--- Transform Chain ---")
	prints("[skel_global] %s" % _basis_str(skel.global_transform.basis))
	prints("[bone_global] %s" % _basis_str(bone_global.basis))
	prints("[skel_rot×bone_rot] %s" % _basis_str(Basis(bone_world_rot)))
	prints("==========================================")
	prints("")

func _get_weapon_visual() -> Node3D:
	if _visuals_component == null:
		return null
	return _visuals_component.get_active_visual("right_hand")

# ============================================================
#  DIAGNOSTIC — N: Bone Rest Pose
# ============================================================

func _debug_print_bone_rest() -> void:
	if _layer_stack == null or _layer_stack.get_layer_count() == 0:
		prints("[BONE_REST_DIAG] No layers in stack")
		return

	var base_layer: WeaponLayerBase = null
	for layer in _layer_stack._layers:
		if layer is WeaponLayerBase:
			base_layer = layer
			break
	if base_layer == null or base_layer._skeleton == null or base_layer._gun_bone_idx == -1:
		prints("[BONE_REST_DIAG] WeaponLayerBase or bone not available")
		return

	var skel: Skeleton3D = base_layer._skeleton
	var bone_idx: int = base_layer._gun_bone_idx

	var rest_pose: Transform3D = skel.get_bone_rest(bone_idx)
	var rest_euler: Vector3 = rest_pose.basis.get_euler()
	var rest_fwd: Vector3 = -rest_pose.basis.z

	var global_pose: Transform3D = skel.get_bone_global_pose(bone_idx)
	var global_euler: Vector3 = global_pose.basis.get_euler()
	var global_fwd: Vector3 = -(skel.global_transform.basis * global_pose.basis).z

	var skel_global_basis: Basis = skel.global_transform.basis
	var skel_euler: Vector3 = skel_global_basis.get_euler()

	var visual: Node3D = _get_weapon_visual()
	var visual_fwd: Vector3 = Vector3.FORWARD
	if visual != null:
		visual_fwd = -visual.global_transform.basis.z

	prints("")
	prints("===== BONE REST DIAGNOSTIC (N) =====")
	prints("[Bone]         ik_hand_gun  idx: %d" % bone_idx)
	prints("")
	prints("--- Rest Pose (skeleton-local) ---")
	prints("[Rest]         euler(deg): x:%+.2f  y:%+.2f  z:%+.2f" % [rad_to_deg(rest_euler.x), rad_to_deg(rest_euler.y), rad_to_deg(rest_euler.z)])
	prints("[Rest fwd]     %s (skeleton-local -Z)" % _v3(rest_fwd))
	prints("[Rest pos]     %s" % _v3(rest_pose.origin))
	prints("")
	prints("--- Global Pose (post-modifiers) ---")
	prints("[Global]       euler(deg): x:%+.2f  y:%+.2f  z:%+.2f" % [rad_to_deg(global_euler.x), rad_to_deg(global_euler.y), rad_to_deg(global_euler.z)])
	prints("[Global fwd]   %s (world-space)" % _v3(global_fwd))
	prints("[Global pos]   %s (skeleton-local)" % _v3(global_pose.origin))
	prints("")
	prints("--- Skeleton Global ---")
	prints("[Skel]         euler(deg): x:%+.2f  y:%+.2f  z:%+.2f" % [rad_to_deg(skel_euler.x), rad_to_deg(skel_euler.y), rad_to_deg(skel_euler.z)])
	prints("[Skel fwd]     %s" % _v3(-skel_global_basis.z))
	prints("")
	prints("--- Weapon Visual ---")
	prints("[Visual fwd]   %s (world-space)" % _v3(visual_fwd))
	prints("")
	prints("--- Delta (rest vs visual) ---")
	prints("[Rest·Visual]  dot:%+.6f  angle:%+.2f deg" % [rest_fwd.dot(visual_fwd), rad_to_deg(acos(clampf(rest_fwd.dot(visual_fwd), -1.0, 1.0)))])
	prints("")
	prints("[Hint] If rest fwd and visual fwd differ significantly, the GLB mesh")
	prints("      forward axis is misaligned with the bone rest forward axis.")
	prints("====================================")
	prints("")

# ============================================================
#  DIAGNOSTIC — P: Rotation Pivot Identification
# ============================================================

func _debug_identify_pivot(state: AimState, weapon_xform: Transform3D) -> void:
	var rgrip_local: Transform3D = _cached_rgrip_local
	var lgrip_local: Transform3D = _cached_lgrip_local
	var rgrip_world: Transform3D = weapon_xform * rgrip_local if _marker_cache_valid and rgrip_local != Transform3D.IDENTITY else Transform3D()
	var lgrip_world: Transform3D = weapon_xform * lgrip_local if _marker_cache_valid and lgrip_local != Transform3D.IDENTITY else Transform3D()
	var eye_pos: Vector3 = state.eye_position
	var skel_pos: Vector3 = _skeleton.global_position if _skeleton != null else Vector3.ZERO

	var root_to_grip_r: float = weapon_xform.origin.distance_to(rgrip_world.origin) if rgrip_world != Transform3D() else 0.0
	var root_to_grip_l: float = weapon_xform.origin.distance_to(lgrip_world.origin) if lgrip_world != Transform3D() else 0.0
	var root_to_eye: float = weapon_xform.origin.distance_to(eye_pos)
	var root_to_skel: float = weapon_xform.origin.distance_to(skel_pos)

	prints("")
	prints("===== ROTATION PIVOT IDENTIFY =====")
	prints("[weapon_root] (%.4f, %.4f, %.4f)" % [weapon_xform.origin.x, weapon_xform.origin.y, weapon_xform.origin.z])
	prints("[rgrip_world] (%.4f, %.4f, %.4f)" % [rgrip_world.origin.x, rgrip_world.origin.y, rgrip_world.origin.z])
	prints("[lgrip_world] (%.4f, %.4f, %.4f)" % [lgrip_world.origin.x, lgrip_world.origin.y, lgrip_world.origin.z])
	prints("[eye_pos]     (%.4f, %.4f, %.4f)" % [eye_pos.x, eye_pos.y, eye_pos.z])
	prints("[skel_pos]    (%.4f, %.4f, %.4f)" % [skel_pos.x, skel_pos.y, skel_pos.z])
	prints("[root→grip_r] %.4f" % root_to_grip_r)
	prints("[root→grip_l] %.4f" % root_to_grip_l)
	prints("[root→eye]    %.4f" % root_to_eye)
	prints("[root→skel]   %.4f" % root_to_skel)
	prints("====================================")
	prints("")

# ============================================================
#  DIAGNOSTIC — S: Transform Space Validation
# ============================================================

func _debug_validate_spaces(weapon_xform: Transform3D) -> void:
	var snapshots: Array[Dictionary] = _layer_stack.get_last_layer_snapshots()
	if snapshots.is_empty():
		prints("[SPACE_VALIDATE] No snapshots captured. Debug mode might not be active in WeaponLayerStack.")
		return

	var skel_pos: Vector3 = _skeleton.global_position if _skeleton != null else Vector3.ZERO
	var prev_origin: Vector3 = Vector3.ZERO

	prints("")
	prints("===== TRANSFORM EVOLUTION =====")
	for i in snapshots.size():
		var s: Dictionary = snapshots[i]
		var label: String = s.get("label", "?")
		var origin: Vector3 = s.get("origin", Vector3.ZERO)
		var fwd: Vector3 = s.get("fwd", Vector3.ZERO)
		var right: Vector3 = s.get("right", Vector3.ZERO)
		var up: Vector3 = s.get("up", Vector3.ZERO)
		var basis_det: float = s.get("basis_det", 0.0)
		var origin_delta: Vector3 = origin - prev_origin

		prints("")
		prints("--- %s ---" % label)
		prints("[origin]   (%.4f, %.4f, %.4f)" % [origin.x, origin.y, origin.z])
		prints("[fwd]      (%.4f, %.4f, %.4f)" % [fwd.x, fwd.y, fwd.z])
		prints("[right]    (%.4f, %.4f, %.4f)" % [right.x, right.y, right.z])
		prints("[up]       (%.4f, %.4f, %.4f)" % [up.x, up.y, up.z])
		prints("[basis_det] %.6f%s" % [basis_det, " OK" if absf(basis_det - 1.0) < 0.01 else " *** DEGENERATED ***"])
		if i > 0:
			prints("[Δorigin]  (%.4f, %.4f, %.4f)  len: %.4f" % [origin_delta.x, origin_delta.y, origin_delta.z, origin_delta.length()])

		prev_origin = origin

	prints("")
	prints("--- Skeleton Reference ---")
	prints("[skel_pos]  (%.4f, %.4f, %.4f)" % [skel_pos.x, skel_pos.y, skel_pos.z])
	prints("[final→skel] %.4f" % [weapon_xform.origin.distance_to(skel_pos)])
	prints("================================")
	prints("")

# ============================================================
#  DIAGNOSTIC — B: Aim Basis Validation
# ============================================================

func _debug_validate_aim_basis(state: AimState) -> void:
	if _aim_layer == null:
		prints("[AIM_BASIS] _aim_layer not available")
		return

	var aim_dir: Vector3 = state.aim_direction.normalized()
	var flat_forward := Vector3(aim_dir.x, 0.0, aim_dir.z)
	if flat_forward.length_squared() < 0.001:
		flat_forward = Vector3.FORWARD
	else:
		flat_forward = flat_forward.normalized()

	var weapon_forward := flat_forward
	var weapon_right := weapon_forward.cross(Vector3.UP).normalized()
	if weapon_right.length_squared() < 0.001:
		weapon_right = Vector3.RIGHT
		weapon_forward = Vector3.UP.cross(weapon_right).normalized()
	var weapon_up := weapon_right.cross(weapon_forward).normalized()

	var orientation := Basis(weapon_right, weapon_up, -weapon_forward)
	if absf(state.look_pitch) > 0.0001:
		var pitch_rotation := Basis(weapon_right, state.look_pitch)
		orientation = orientation * pitch_rotation

	var built_fwd: Vector3 = -orientation.z
	var dot_val: float = aim_dir.dot(built_fwd)
	var angle: float = rad_to_deg(acos(clampf(dot_val, -1.0, 1.0)))
	var right_dot: float = aim_dir.dot(weapon_right)
	var up_dot: float = aim_dir.dot(weapon_up)

	prints("")
	prints("===== AIM BASIS VALIDATE =====")
	prints("[aim_dir]     (%.4f, %.4f, %.4f)" % [aim_dir.x, aim_dir.y, aim_dir.z])
	prints("[built_fwd]   (%.4f, %.4f, %.4f)" % [built_fwd.x, built_fwd.y, built_fwd.z])
	prints("[flat_fwd]    (%.4f, %.4f, %.4f)" % [flat_forward.x, flat_forward.y, flat_forward.z])
	prints("[weapon_right](%.4f, %.4f, %.4f)" % [weapon_right.x, weapon_right.y, weapon_right.z])
	prints("[weapon_up]   (%.4f, %.4f, %.4f)" % [weapon_up.x, weapon_up.y, weapon_up.z])
	prints("[dot]         %.6f" % dot_val)
	prints("[angle]       %.2f deg" % angle)
	prints("[aim·right]   %.6f  (should be ≈0)" % right_dot)
	prints("[aim·up]      %.6f  (should be ≈0)" % up_dot)
	prints("[look_pitch]  %.2f deg" % rad_to_deg(state.look_pitch))
	prints("[weight]      %.4f" % state.aim_orientation_weight)
	prints("================================")
	prints("")

# ============================================================
#  DIAGNOSTIC LOGGER TOGGLE
# ============================================================

func _toggle_diagnostic_logger() -> void:
	if _diag_logger != null and _diag_logger.is_enabled():
		_diag_logger.close()
		_diag_logger = null
		prints("[WeaponDiag] DISABLED — log written to Debug/weapon_diag.log")
	else:
		_diag_logger = WeaponDiagnosticLogger.new()
		_diag_logger.open()
		prints("[WeaponDiag] ENABLED — logging to Debug/weapon_diag.log (F12 to stop)")

# ============================================================
#  HELPERS
# ============================================================

static func _v3(v: Vector3) -> String:
	return "(%.4f, %.4f, %.4f)" % [v.x, v.y, v.z]

static func _basis_str(b: Basis) -> String:
	return "[%s %s %s]" % [_v3(b.x), _v3(b.y), _v3(b.z)]
