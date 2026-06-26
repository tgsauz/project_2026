extends SkeletonModifier3D
class_name WeaponPositionController

# ============================================================
#  EXPORTS
# ============================================================

@export var offset_cache_path: NodePath
@export var character_controller_path: NodePath
@export var aim_controller_path: NodePath

@export var chest_bone_name: String = "spine_02"
@export var gun_bone_name: String = "ik_hand_gun"
@export var gun_marker_path: NodePath = NodePath("../../GunMarker")

@export var capture_delay_frames: int = 15

@export_category("ADS Sight Corrector")
@export var enable_ads_sight_corrector: bool = true
@export_range(0.0, 1.0, 0.01) var ads_sight_corrector_weight: float = 1.0
@export_range(0.0, 20.0, 0.1) var ads_sight_corrector_max_angle_deg: float = 12.0

enum AnimState {
	NONE = -1,
	UNARMED,
	ARMED,
	AIMING
}

# ============================================================
#  CACHED REFERENCES
# ============================================================

var _skeleton: Skeleton3D
var _offset_cache
var _character_controller: CharacterController
var _aim_controller: AimController
var _gun_marker: Node3D

var _chest_bone_idx: int = -1
var _gun_bone_idx: int = -1
var _gun_parent_idx: int = -1
var _arm_bone_idx: int = -1

var _fixed_offset: Transform3D = Transform3D.IDENTITY
var _previous_state: int = AnimState.NONE
var _capture_timer: int = 0

var _warned_messages: Dictionary = {}

var _debug_f6_pressed: bool = false
var _debug_f7_pressed: bool = false
var _debug_sight_detail_pressed: bool = false

var _sight_back_local_offset: Vector3 = Vector3.ZERO
var _sight_front_local_offset: Vector3 = Vector3.ZERO
var _sight_offsets_valid: bool = false
var _has_applied_gun_pose: bool = false

const SIGHT_MARKER_MIN_DISTANCE: float = 0.01
const ROTATION_AXIS_EPSILON: float = 0.0001

# ============================================================
#  LIFECYCLE
# ============================================================

func _ready() -> void:
	_skeleton = get_skeleton()
	if _skeleton == null:
		push_error("WeaponPositionController must be a child of Skeleton3D.")
		return

	_resolve_dependencies()
	_cache_bone_indices()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_weapon_pose"):
		_debug_f6_pressed = true
	if event.is_action_pressed("debug_sight_screen"):
		_debug_f7_pressed = true
	if event.is_action_pressed("debug_sight_detail"):
		_debug_sight_detail_pressed = true

func _get_anim_state() -> int:
	if _character_controller == null:
		return AnimState.NONE
	if not _character_controller.has_main_hand_weapon():
		return AnimState.UNARMED
	if _character_controller.is_effectively_aiming():
		return AnimState.AIMING
	return AnimState.ARMED

func _process_modification_with_delta(_delta: float) -> void:
	if _skeleton == null or _offset_cache == null or _chest_bone_idx == -1 or _gun_bone_idx == -1:
		_clear_bone_override()
		return

	_resolve_dependencies()

	var current_state: int = _get_anim_state()

	if current_state == AnimState.UNARMED or current_state == AnimState.NONE:
		_fixed_offset = Transform3D.IDENTITY
		_capture_timer = 0
		_previous_state = current_state
		_reset_sight_corrector_cache()
		_clear_bone_override()
		return

	if current_state != _previous_state:
		_fixed_offset = Transform3D.IDENTITY
		_capture_timer = capture_delay_frames
		_previous_state = current_state
		_reset_sight_corrector_cache()

	if _capture_timer > 0:
		_capture_timer -= 1
		if _capture_timer == 0:
			_fixed_offset = _offset_cache.cached_offset

	if _fixed_offset == Transform3D.IDENTITY:
		_reset_sight_corrector_cache()
		_clear_bone_override()
		return

	var spine_corrected: Transform3D = _skeleton.get_bone_global_pose(_chest_bone_idx)

	# ── Desired position + orientation (spine-driven) ──
	# NOTE: Use constructor to avoid GDScript struct property-setter issues
	# on value-type Transform3D.
	var desired_global := Transform3D(
		spine_corrected.basis * _fixed_offset.basis,
		spine_corrected.origin + spine_corrected.basis * _fixed_offset.origin
	)
	desired_global = _apply_ads_sight_corrector(desired_global, current_state)

	_set_gun_pose(desired_global)

	if _debug_f6_pressed:
		_debug_f6_pressed = false
		_debug_print_pose(desired_global)

	if _debug_f7_pressed:
		_debug_f7_pressed = false
		_debug_print_sight_screen()

	if _debug_sight_detail_pressed:
		_debug_sight_detail_pressed = false
		_debug_print_sight_detail()

# ============================================================
#  DEPENDENCY RESOLUTION
# ============================================================

func _resolve_dependencies() -> void:
	if _offset_cache == null and not offset_cache_path.is_empty():
		_offset_cache = get_node(offset_cache_path)
		if _offset_cache == null:
			_warn_once("offset_cache", "WeaponPositionController could not resolve WeaponOffsetCache.")
	if _character_controller == null and not character_controller_path.is_empty():
		_character_controller = get_node(character_controller_path) as CharacterController
	if _aim_controller == null and not aim_controller_path.is_empty():
		_aim_controller = get_node(aim_controller_path) as AimController
	if _gun_marker == null and not gun_marker_path.is_empty():
		_gun_marker = get_node(gun_marker_path) as Node3D

func _cache_bone_indices() -> void:
	_chest_bone_idx = _skeleton.find_bone(chest_bone_name)
	_gun_bone_idx = _skeleton.find_bone(gun_bone_name)
	_gun_parent_idx = _skeleton.get_bone_parent(_gun_bone_idx)

	if _chest_bone_idx == -1:
		_warn_once("chest_bone", "WeaponPositionController: skeleton missing chest bone '%s'." % chest_bone_name)
	if _gun_bone_idx == -1:
		_warn_once("gun_bone", "WeaponPositionController: skeleton missing gun bone '%s'." % gun_bone_name)

	_arm_bone_idx = _skeleton.find_bone("arm_r")

# ============================================================
#  POSE APPLICATION
# ============================================================

func _set_gun_pose(desired_global: Transform3D) -> void:
	if _gun_bone_idx == -1:
		return
	_skeleton.set_bone_global_pose_override(_gun_bone_idx, desired_global, 1.0, true)
	if _gun_marker != null:
		_gun_marker.global_transform = _skeleton.global_transform * desired_global
	_has_applied_gun_pose = true

# ============================================================
#  ADS SIGHT CORRECTOR
# ============================================================

func _apply_ads_sight_corrector(desired_global: Transform3D, current_state: int) -> Transform3D:
	if not enable_ads_sight_corrector:
		return desired_global
	if current_state != AnimState.AIMING:
		return desired_global
	if _skeleton == null or _gun_bone_idx == -1:
		return desired_global

	var cam_rig: CameraController = _aim_controller.camera_controller if _aim_controller != null else null
	if cam_rig == null or not cam_rig.using_fps:
		return desired_global

	var camera: Camera3D = cam_rig.fps_camera
	if camera == null:
		return desired_global

	var camera_forward: Vector3 = (-camera.global_transform.basis.z).normalized()
	if camera_forward.is_zero_approx():
		return desired_global

	var current_gun_world: Transform3D = _get_current_gun_world()
	if not _refresh_sight_offsets(current_gun_world):
		return desired_global

	var desired_world: Transform3D = _skeleton.global_transform * desired_global
	var sight_back_world: Vector3 = desired_world * _sight_back_local_offset
	var sight_front_world: Vector3 = desired_world * _sight_front_local_offset
	var sight_vector: Vector3 = sight_front_world - sight_back_world
	if sight_vector.length() < SIGHT_MARKER_MIN_DISTANCE:
		return desired_global

	var sight_direction: Vector3 = sight_vector.normalized()
	var correction_basis: Basis = _get_limited_rotation_between(sight_direction, camera_forward)
	if correction_basis == Basis.IDENTITY:
		return desired_global

	var corrected_world_basis: Basis = (correction_basis * desired_world.basis).orthonormalized()
	var corrected_world_origin: Vector3 = sight_back_world + correction_basis * (desired_world.origin - sight_back_world)
	var corrected_world: Transform3D = Transform3D(corrected_world_basis, corrected_world_origin)
	return _skeleton.global_transform.affine_inverse() * corrected_world

func _refresh_sight_offsets(current_gun_world: Transform3D) -> bool:
	var sight_back: Node3D = _resolve_visual_marker("SIGHT_BACK")
	var sight_front: Node3D = _resolve_visual_marker("SIGHT_FRONT")
	if sight_back == null or sight_front == null:
		_sight_offsets_valid = false
		return false

	var marker_distance: float = sight_back.global_position.distance_to(sight_front.global_position)
	if marker_distance < SIGHT_MARKER_MIN_DISTANCE:
		_sight_offsets_valid = false
		return false

	var gun_world_inverse: Transform3D = current_gun_world.affine_inverse()
	_sight_back_local_offset = gun_world_inverse * sight_back.global_position
	_sight_front_local_offset = gun_world_inverse * sight_front.global_position
	_sight_offsets_valid = true
	return true

func _reset_sight_corrector_cache() -> void:
	_sight_back_local_offset = Vector3.ZERO
	_sight_front_local_offset = Vector3.ZERO
	_sight_offsets_valid = false
	_has_applied_gun_pose = false

func _get_current_gun_world() -> Transform3D:
	if _has_applied_gun_pose and _gun_marker != null and is_instance_valid(_gun_marker):
		return _gun_marker.global_transform
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(_gun_bone_idx)

func _get_limited_rotation_between(from_dir: Vector3, to_dir: Vector3) -> Basis:
	var from_normalized: Vector3 = from_dir.normalized()
	var to_normalized: Vector3 = to_dir.normalized()
	var dot: float = clampf(from_normalized.dot(to_normalized), -1.0, 1.0)
	if dot >= 0.9999:
		return Basis.IDENTITY

	var axis: Vector3 = from_normalized.cross(to_normalized)
	if axis.length() < ROTATION_AXIS_EPSILON:
		axis = _get_fallback_rotation_axis(from_normalized)
	else:
		axis = axis.normalized()

	var full_angle: float = acos(dot)
	var max_angle: float = deg_to_rad(ads_sight_corrector_max_angle_deg)
	var corrected_angle: float = minf(full_angle, max_angle) * clampf(ads_sight_corrector_weight, 0.0, 1.0)
	if corrected_angle <= 0.00001:
		return Basis.IDENTITY
	return Basis(axis, corrected_angle)

func _get_fallback_rotation_axis(direction: Vector3) -> Vector3:
	var axis: Vector3 = direction.cross(Vector3.UP)
	if axis.length() < ROTATION_AXIS_EPSILON:
		axis = direction.cross(Vector3.RIGHT)
	return axis.normalized()

# ============================================================
#  K DEBUG — Weapon Pose
# ============================================================

func _debug_print_pose(desired_global: Transform3D) -> void:
	var after_pose: Transform3D = _skeleton.get_bone_global_pose(_gun_bone_idx) if _gun_bone_idx != -1 else Transform3D.IDENTITY
	var marker_pose: Transform3D = _gun_marker.global_transform if _gun_marker != null else Transform3D.IDENTITY
	var skel_global: Transform3D = _skeleton.global_transform
	var spine_anim: Transform3D = _offset_cache.spine_anim_global if _offset_cache != null else Transform3D.IDENTITY
	var gun_anim: Transform3D = _offset_cache.gun_anim_global if _offset_cache != null else Transform3D.IDENTITY

	var gun_bone_name_str: String = _skeleton.get_bone_name(_gun_bone_idx) if _gun_bone_idx != -1 else "N/A"
	var parent_name: String = _skeleton.get_bone_name(_gun_parent_idx) if _gun_parent_idx != -1 else "N/A"

	prints("")
	prints("===== GUN POSE DEBUG (K) =====")

	# Shoulder displacement measurement
	if _arm_bone_idx != -1 and _offset_cache != null:
		var arm_corrected: Transform3D = _skeleton.get_bone_global_pose(_arm_bone_idx)
		var arm_anim: Transform3D = _offset_cache.arm_anim_global
		var shoulder_delta: Vector3 = arm_corrected.origin - arm_anim.origin
		prints("[ShoulderDelta] bone: arm_r  delta:", _v3_str(shoulder_delta),
			"  len_cm: %.2f" % (shoulder_delta.length() * 100.0))
	else:
		prints("[ShoulderDelta] N/A (bone or cache missing)")

	# Shoulder distances
	if _arm_bone_idx != -1 and _gun_bone_idx != -1:
		var shoulder_world: Vector3 = _skeleton.get_bone_global_pose(_arm_bone_idx).origin
		var gun_world: Vector3 = _skeleton.get_bone_global_pose(_gun_bone_idx).origin
		var shoulder_gun_dist: float = shoulder_world.distance_to(gun_world)
		prints("[ShoulderDist] arm_r→gun: %.4f" % shoulder_gun_dist)
		# RGRIP marker from weapon scene
		var rgrip: Node3D = _resolve_rgrip()
		if rgrip != null:
			var shoulder_rgrip_dist: float = shoulder_world.distance_to(rgrip.global_position)
			prints("[ShoulderDist] arm_r→RGRIP: %.4f" % shoulder_rgrip_dist)
		else:
			prints("[ShoulderDist] arm_r→RGRIP: N/A (no RGRIP marker)")
	else:
		prints("[ShoulderDist] N/A (bone index missing)")

	prints("[Bones]        gun:", gun_bone_name_str, "idx:", _gun_bone_idx,
		"  parent:", parent_name, "idx:", _gun_parent_idx)
	prints("[SkelGlobal]   pos:", _v3_str(skel_global.origin),
		"  basis:", _basis_str(skel_global.basis))
	prints("[SpineAnim]    pos:", _v3_str(spine_anim.origin),
		"  basis:", _basis_str(spine_anim.basis))
	prints("[GunAnim]      pos:", _v3_str(gun_anim.origin),
		"  basis:", _basis_str(gun_anim.basis))

	var spine_corrected: Transform3D = _skeleton.get_bone_global_pose(_chest_bone_idx) if _chest_bone_idx != -1 else Transform3D.IDENTITY
	var spine_corrected_euler: Vector3 = spine_corrected.basis.get_euler()
	var spine_delta_basis: Basis = spine_corrected.basis * spine_anim.basis.inverse()
	var spine_delta_euler: Vector3 = spine_delta_basis.get_euler()
	var offset_euler: Vector3 = _fixed_offset.basis.get_euler()
	var desired_euler: Vector3 = desired_global.basis.get_euler()

	var state_names: Dictionary = {
		AnimState.NONE: "NONE",
		AnimState.UNARMED: "UNARMED",
		AnimState.ARMED: "ARMED",
		AnimState.AIMING: "AIMING"
	}
	var current_state: int = _get_anim_state()
	var state_name: String = state_names.get(current_state, "?")

	prints("[SpineCorrected] euler(deg):  x: %+.2f°  y: %+.2f°  z: %+.2f°" % [rad_to_deg(spine_corrected_euler.x), rad_to_deg(spine_corrected_euler.y), rad_to_deg(spine_corrected_euler.z)])
	prints("[SpineDelta]     euler(deg):  x: %+.2f°  y: %+.2f°  z: %+.2f°" % [rad_to_deg(spine_delta_euler.x), rad_to_deg(spine_delta_euler.y), rad_to_deg(spine_delta_euler.z)])
	prints("[FixedOffset]    euler(deg):  x: %+.2f°  y: %+.2f°  z: %+.2f°  captured: %s  timer: %d" % [rad_to_deg(offset_euler.x), rad_to_deg(offset_euler.y), rad_to_deg(offset_euler.z), "YES" if _fixed_offset != Transform3D.IDENTITY else "DLAY", _capture_timer])
	prints("[AnimState]      cur: %s  prev: %s" % [state_name, state_names.get(_previous_state, "?")])

	# ── Spine tracking validation ──────────────────────────────────
	var spine_fwd: Vector3 = -spine_corrected.basis.z
	var weapon_fwd_out: Vector3 = -desired_global.basis.z
	var fwd_dot: float = spine_fwd.dot(weapon_fwd_out)
	prints("[SpineOnlyBasis] euler(deg):  x: %+.2f°  y: %+.2f°  z: %+.2f°" % [rad_to_deg(desired_euler.x), rad_to_deg(desired_euler.y), rad_to_deg(desired_euler.z)])
	prints("[SpineTrack]    spine_fwd: %s  weapon_fwd: %s  dot: %.6f" % [_v3_str(spine_fwd), _v3_str(weapon_fwd_out), fwd_dot])

	prints("[Desired]      pos:", _v3_str(desired_global.origin),
		"  basis:", _basis_str(desired_global.basis))
	prints("[BonePose]     pos:", _v3_str(after_pose.origin),
		"  basis:", _basis_str(after_pose.basis))
	prints("[MarkerPose]   pos:", _v3_str(marker_pose.origin),
		"  basis:", _basis_str(marker_pose.basis))
	prints("[Delta]        dpos:", _v3_str(desired_global.origin - after_pose.origin))
	prints("================================")
	prints("")

# ============================================================
#  L DIAGNOSTIC — Spine Pitch Tracking
# ============================================================

func _debug_print_sight_screen() -> void:
	if _character_controller == null or not _character_controller.has_main_hand_weapon():
		prints("===== SPINE TRACK (L) =====")
		prints("[No weapon equipped]")
		return

	var cam_rig: CameraController = _aim_controller.camera_controller if _aim_controller != null else null
	if cam_rig == null:
		prints("===== SPINE TRACK (L) =====")
		prints("[No camera controller]")
		return

	var camera: Camera3D = cam_rig.fps_camera if cam_rig.using_fps else cam_rig.tps_camera
	if camera == null:
		prints("===== SPINE TRACK (L) =====")
		prints("[No active camera]")
		return

	var skel_t: Transform3D = _skeleton.global_transform

	# --- Spine bone actual world orientations ---
	var spine1_idx: int = _skeleton.find_bone("spine_01")
	var spine2_idx: int = _skeleton.find_bone("spine_02")
	var neck_idx: int = _skeleton.find_bone("neck")

	var spine1_gpose: Transform3D = _skeleton.get_bone_global_pose(spine1_idx) if spine1_idx != -1 else Transform3D.IDENTITY
	var spine2_gpose: Transform3D = _skeleton.get_bone_global_pose(spine2_idx) if spine2_idx != -1 else Transform3D.IDENTITY
	var neck_gpose: Transform3D = _skeleton.get_bone_global_pose(neck_idx) if neck_idx != -1 else Transform3D.IDENTITY

	# Convert to world space: global_pose is in skeleton space, so multiply by skel_t
	var spine1_world_basis: Basis = skel_t.basis * spine1_gpose.basis
	var spine2_world_basis: Basis = skel_t.basis * spine2_gpose.basis
	var neck_world_basis: Basis = skel_t.basis * neck_gpose.basis

	# Extract pitch from each bone's world basis (forward = -z, pitch = asin of forward.y)
	var sp1_forward: Vector3 = (-spine1_world_basis.z).normalized()
	var sp2_forward: Vector3 = (-spine2_world_basis.z).normalized()
	var neck_forward: Vector3 = (-neck_world_basis.z).normalized()
	var sp1_pitch: float = rad_to_deg(asin(sp1_forward.y))
	var sp2_pitch: float = rad_to_deg(asin(sp2_forward.y))
	var neck_pitch: float = rad_to_deg(asin(neck_forward.y))

	# --- Weapon world forward ---
	var weapon_gpose: Transform3D = _gun_marker.global_transform if _gun_marker != null else Transform3D.IDENTITY
	var weapon_world_forward: Vector3 = (-weapon_gpose.basis.z).normalized()

	# --- Camera forward ---
	var cam_forward: Vector3 = -camera.global_transform.basis.z.normalized()
	var cam_pitch: float = rad_to_deg(_get_camera_pitch())

	# --- Weapon origin in world space ---
	var weapon_origin_world: Vector3 = weapon_gpose.origin if _gun_marker != null else skel_t.origin
	var cam_pos: Vector3 = camera.global_position

	# --- Offset basis info ---
	var offset_basis: Basis = _fixed_offset.basis
	var offset_euler: Vector3 = offset_basis.get_euler()

	# --- Spine2 euler (world) showing actual rotation ---
	var sp2_euler: Vector3 = spine2_world_basis.get_euler()

	prints("")
	prints("===== SPINE TRACK DIAGNOSTIC (L) =====")
	prints("")
	prints("--- Pitch Tracking ---")
	prints("[CamPitch]      request: %+.2f°" % cam_pitch)
	prints("[Spine01]       forward: %s  pitch: %+.2f°" % [_v3_str(sp1_forward), sp1_pitch])
	prints("[Spine02]       forward: %s  pitch: %+.2f°  euler(deg): %s" % [_v3_str(sp2_forward), sp2_pitch, _v3_str(Vector3(rad_to_deg(sp2_euler.x), rad_to_deg(sp2_euler.y), rad_to_deg(sp2_euler.z)))])
	prints("[Neck]          forward: %s  pitch: %+.2f°" % [_v3_str(neck_forward), neck_pitch])
	prints("[Weapon]        forward: %s  pitch: %+.2f°" % [_v3_str(weapon_world_forward), rad_to_deg(asin(weapon_world_forward.y))])
	prints("")
	prints("--- Alignment ---")
	var dot_sp2_cam: float = sp2_forward.dot(cam_forward)
	var dot_wpn_cam: float = weapon_world_forward.dot(cam_forward)
	prints("[Spine02·Camera] dot: %+.6f  (1.0 = perfect, deg: %.2f°)" % [dot_sp2_cam, rad_to_deg(acos(clamp(dot_sp2_cam, -1.0, 1.0)))])
	prints("[Weapon·Camera]  dot: %+.6f  (1.0 = perfect, deg: %.2f°)" % [dot_wpn_cam, rad_to_deg(acos(clamp(dot_wpn_cam, -1.0, 1.0)))])
	prints("")
	prints("--- Pitch Delta (camera - bone) ---")
	prints("[ΔSpine01]      %+.2f°" % (cam_pitch - sp1_pitch))
	prints("[ΔSpine02]      %+.2f°" % (cam_pitch - sp2_pitch))
	prints("[ΔNeck]         %+.2f°" % (cam_pitch - neck_pitch))
	prints("[ΔWeapon]       %+.2f°" % (cam_pitch - rad_to_deg(asin(weapon_world_forward.y))))
	prints("")
	prints("--- Mode ---")
	prints("[CamMode]       %s" % ("FPS" if cam_rig.using_fps else "TPS"))
	prints("[Cam→WeaponDist] %.4f" % cam_pos.distance_to(weapon_origin_world))
	prints("[FixedOffset]   euler(deg):  x: %+.2f°  y: %+.2f°  z: %+.2f°" % [rad_to_deg(offset_euler.x), rad_to_deg(offset_euler.y), rad_to_deg(offset_euler.z)])
	prints("=========================================")
	prints("")

# ============================================================
#  I DIAGNOSTIC — SIGHT DETAIL WORLD+SCREEN
# ============================================================

func _debug_print_sight_detail() -> void:
	if _character_controller == null or not _character_controller.has_main_hand_weapon():
		prints("===== SIGHT DETAIL (I) =====")
		prints("[No weapon equipped]")
		return

	var cam_rig: CameraController = _aim_controller.camera_controller if _aim_controller != null else null
	if cam_rig == null:
		prints("===== SIGHT DETAIL (I) =====")
		prints("[No camera controller]")
		return

	var camera: Camera3D = cam_rig.fps_camera if cam_rig.using_fps else cam_rig.tps_camera
	if camera == null:
		prints("===== SIGHT DETAIL (I) =====")
		prints("[No active camera]")
		return

	var vp_camera: Camera3D = get_viewport().get_camera_3d()
	if vp_camera == null:
		prints("===== SIGHT DETAIL (I) =====")
		prints("[No viewport camera]")
		return

	var vc = _character_controller.visuals_component
	if vc == null:
		prints("===== SIGHT DETAIL (I) =====")
		prints("[No visuals component]")
		return

	var sight_back: Node3D = vc.get_active_visual_marker("right_hand", "SIGHT_BACK") as Node3D
	var sight_front: Node3D = vc.get_active_visual_marker("right_hand", "SIGHT_FRONT") as Node3D
	if sight_back == null or sight_front == null:
		prints("===== SIGHT DETAIL (I) =====")
		prints("[SIGHT_BACK or SIGHT_FRONT marker not found]")
		return

	var state_names: Dictionary = {
		AnimState.NONE: "NONE", AnimState.UNARMED: "UNARMED",
		AnimState.ARMED: "ARMED", AnimState.AIMING: "AIMING"
	}
	var current_state: int = _get_anim_state()
	var state_name: String = state_names.get(current_state, "?")

	var vp: Viewport = get_viewport()
	var vp_center: Vector2 = vp.size * 0.5 if vp != null else Vector2.ZERO

	var sb_world: Vector3 = sight_back.global_position
	var sf_world: Vector3 = sight_front.global_position
	var sight_dir: Vector3 = (sf_world - sb_world).normalized()
	var cam_forward: Vector3 = -camera.global_transform.basis.z.normalized()
	var dot: float = clampf(sight_dir.dot(cam_forward), -1.0, 1.0)
	var angle_deg: float = rad_to_deg(acos(dot))

	var sb_screen: Vector2 = vp_camera.unproject_position(sb_world)
	var sf_screen: Vector2 = vp_camera.unproject_position(sf_world)
	var sb_offset: Vector2 = sb_screen - vp_center
	var sf_offset: Vector2 = sf_screen - vp_center

	prints("")
	prints("===== SIGHT DETAIL DIAGNOSTIC (I) =====")
	prints("[State]         %s" % state_name)
	prints("[SIGHT_BACK]    world: %s  screen: (%.1f, %.1f)" % [_v3_str(sb_world), sb_screen.x, sb_screen.y])
	prints("[SIGHT_FRONT]   world: %s  screen: (%.1f, %.1f)" % [_v3_str(sf_world), sf_screen.x, sf_screen.y])
	prints("[sight_dir]     (FRONT - BACK).norm: %s" % _v3_str(sight_dir))
	prints("[camera_forward] %s" % _v3_str(cam_forward))
	prints("[angle_deg]     acos(sight·cam): %+.3f°" % angle_deg)
	prints("[screen_offset] SIGHT_BACK: (%+.1f, %+.1f) px   SIGHT_FRONT: (%+.1f, %+.1f) px" % [sb_offset.x, sb_offset.y, sf_offset.x, sf_offset.y])
	prints("[CamMode]       %s" % ("FPS" if cam_rig.using_fps else "TPS"))
	prints("[spine_02]      pitch: %+.2f°" % _get_spine02_world_pitch())
	prints("[CamPitch]      %+.2f°" % rad_to_deg(_get_camera_pitch()))
	prints("")
	prints("--- World Yaw/Pitch/Roll (YXZ euler deg) ---")
	var sp_anim: Transform3D = _offset_cache.spine_anim_global if _offset_cache != null else Transform3D.IDENTITY
	var sp_corrected: Transform3D = _skeleton.get_bone_global_pose(_chest_bone_idx) if _chest_bone_idx != -1 else Transform3D.IDENTITY
	var gun_actual: Transform3D = _skeleton.get_bone_global_pose(_gun_bone_idx) if _gun_bone_idx != -1 else Transform3D.IDENTITY

	var sp_anim_world: Basis = _get_world_basis(sp_anim)
	var sp_corr_world: Basis = _get_world_basis(sp_corrected)
	var desired_world: Basis = sp_corr_world * _fixed_offset.basis if _fixed_offset != Transform3D.IDENTITY else Basis.IDENTITY
	var gun_world: Basis = _get_world_basis(gun_actual)
	var cam_basis: Basis = camera.global_transform.basis

	_print_roll_line("spine_02 anim", sp_anim_world)
	_print_roll_line("spine_02 corrected", sp_corr_world)
	_print_roll_line("fixed_offset (local)", _fixed_offset.basis)
	_print_roll_line("desired gun", desired_world)
	_print_roll_line("actual gun", gun_world)
	_print_roll_line("camera", cam_basis)

	var cam_euler: Vector3 = cam_basis.get_euler()
	var desired_euler: Vector3 = desired_world.get_euler()
	var sp2_euler: Vector3 = sp_corr_world.get_euler()
	prints("[ΔRoll] desired gun - camera:%+.2f°    spine02 - camera:%+.2f°" % [rad_to_deg(desired_euler.z - cam_euler.z), rad_to_deg(sp2_euler.z - cam_euler.z)])
	prints("========================================")
	prints("")

func _get_world_basis(gpose: Transform3D) -> Basis:
	if _skeleton == null:
		return gpose.basis
	return _skeleton.global_transform.basis * gpose.basis

func _print_roll_line(label: String, basis: Basis) -> void:
	var e: Vector3 = basis.get_euler()
	prints("  %-24s  y:%+7.2f°  p:%+7.2f°  r:%+7.2f°" % [label, rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z)])

func _get_spine02_world_pitch() -> float:
	if _skeleton == null:
		return 0.0
	var idx: int = _skeleton.find_bone("spine_02")
	if idx == -1:
		return 0.0
	var gpose: Transform3D = _skeleton.get_bone_global_pose(idx)
	var world_basis: Basis = _skeleton.global_transform.basis * gpose.basis
	var forward: Vector3 = (-world_basis.z).normalized()
	return rad_to_deg(asin(forward.y))

# ============================================================
#  CAMERA PITCH
# ============================================================

func _get_camera_pitch() -> float:
	if _aim_controller == null:
		return 0.0
	var cam: CameraController = _aim_controller.camera_controller
	if cam == null:
		return 0.0
	return cam.fps_pitch if cam.using_fps else cam.tps_pitch

# ============================================================
#  HELPERS
# ============================================================

func _clear_bone_override() -> void:
	if _skeleton != null and _gun_bone_idx != -1:
		_skeleton.set_bone_global_pose_override(_gun_bone_idx, Transform3D.IDENTITY, 0.0, true)

func _warn_once(key: String, message: String) -> void:
	if _warned_messages.has(key):
		return
	_warned_messages[key] = true
	push_warning(message)

func _resolve_rgrip() -> Node3D:
	return _resolve_visual_marker("RGRIP")

func _resolve_visual_marker(marker_name: String) -> Node3D:
	if _character_controller == null:
		return null
	var vc = _character_controller.visuals_component
	if vc == null or not vc.has_method("get_active_visual_marker"):
		return null
	return vc.get_active_visual_marker("right_hand", marker_name) as Node3D

static func _v3_str(v: Vector3) -> String:
	return "(%.4f, %.4f, %.4f)" % [v.x, v.y, v.z]

static func _basis_str(b: Basis) -> String:
	return "[%s %s %s]" % [_v3_str(b.x), _v3_str(b.y), _v3_str(b.z)]
