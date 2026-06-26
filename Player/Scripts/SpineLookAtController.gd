extends SkeletonModifier3D
class_name SpineLookAtController

# ============================================================
#  EXPORTS
# ============================================================

@export var character_controller_path: NodePath
@export var aim_controller_path: NodePath
@export var look_at_target_path: NodePath

## Distance from pelvis to IK target. Tune for desired spine bend.
@export var arc_radius: float = 1.5

# ============================================================
#  CONSTANTS
# ============================================================

const INFLUENCE_UNARMED: float = 0.0
const INFLUENCE_ARMED: float = 0.15
const INFLUENCE_AIMING: float = 1.0
const INFLUENCE_BLEND_SPEED: float = 6.0
const INFLUENCE_EPSILON: float = 0.001

# ============================================================
#  STATE
# ============================================================

var _skeleton: Skeleton3D
var _character_controller: CharacterController
var _aim_controller: AimController
var _look_at_target: Node3D

var _pelvis_idx: int = -1
var _spine01_idx: int = -1
var _spine02_idx: int = -1
var _gun_bone_idx: int = -1

var _current_influence: float = 0.0

# Temp debug: prints spine bone eulers before CCDIK on P
var _debug_f8_pressed: bool = false

# ============================================================
#  LIFECYCLE
# ============================================================

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_spine_track"):
		_debug_f8_pressed = true

func _ready() -> void:
	_skeleton = get_skeleton()
	if _skeleton == null:
		push_error("SpineLookAtController must be a direct child of Skeleton3D.")
		return
	_resolve_dependencies()
	_cache_bone_indices()

	# Configure CCDIK3D via ChainIK3D API (Godot 4.6+)
	var ccdik := get_node("../CCDIK") as CCDIK3D
	if ccdik != null:
		ccdik.set_setting_count(1)
		ccdik.set_root_bone_name(0, "spine_01")
		ccdik.set_end_bone_name(0, "spine_02")
		if _look_at_target != null:
			ccdik.set_target_node(0, ccdik.get_path_to(_look_at_target))
		ccdik.max_iterations = 4
		ccdik.min_distance = 0.01

func _process_modification_with_delta(delta: float) -> void:
	if _skeleton == null or _spine01_idx == -1 or _spine02_idx == -1:
		return

	_resolve_dependencies()

	var target_influence: float = _compute_target_influence()
	_blend_influence(delta, target_influence)

	var pelvis_global: Transform3D = _skeleton.get_bone_global_pose(_pelvis_idx)
	var pitch := _get_camera_pitch()

	var local_offset := Vector3(0.0, arc_radius, 0.0).rotated(Vector3.RIGHT, -pitch)
	var aim_target := pelvis_global.origin + local_offset

	if _current_influence < 1.0 - INFLUENCE_EPSILON:
		var neutral_pos := pelvis_global.origin + Vector3(0.0, arc_radius, 0.0)
		aim_target = neutral_pos.lerp(aim_target, _current_influence)

	if _look_at_target != null:
		_look_at_target.position = aim_target

	if _debug_f8_pressed:
		_debug_f8_pressed = false
		prints("[CCDIK_CTX] camera_pitch(deg):", rad_to_deg(pitch),
			"  yaw(deg):", 0.0,
			"  influence:", _current_influence,
			"  target_pos:", aim_target)
		var s1_idx: int = _spine01_idx
		var s2_idx: int = _spine02_idx
		if s1_idx != -1:
			var q1: Quaternion = _skeleton.get_bone_pose_rotation(s1_idx)
			var e1: Vector3 = q1.get_euler()
			prints("[BEFORE_CCDIK] spine_01  q:", q1, "  euler(deg):",
				rad_to_deg(e1.x), rad_to_deg(e1.y), rad_to_deg(e1.z))
		if s2_idx != -1:
			var q2: Quaternion = _skeleton.get_bone_pose_rotation(s2_idx)
			var e2: Vector3 = q2.get_euler()
			prints("[BEFORE_CCDIK] spine_02  q:", q2, "  euler(deg):",
				rad_to_deg(e2.x), rad_to_deg(e2.y), rad_to_deg(e2.z))

		var ccdik_node: Node = get_node("../CCDIK")
		if ccdik_node != null and ccdik_node is SkeletonModifier3D:
			var ccdik_sm: SkeletonModifier3D = ccdik_node as SkeletonModifier3D
			var ccdik_typed := ccdik_node as CCDIK3D
			prints("[CCDIK_DIAG] influence:", ccdik_sm.influence,
				"  active:", ccdik_sm.active,
				"  process_mode:", ccdik_sm.process_mode,
				"  skeleton_valid:", ccdik_sm.get_skeleton() != null)
			if ccdik_typed != null:
				var post_bones = ccdik_typed.bones
				prints("[CCDIK_VERIFY] bones en P:", post_bones, "  is_empty:", post_bones.is_empty() if post_bones != null else "NULL")
				if post_bones != null:
					for bname in post_bones:
						var b_idx: int = _skeleton.find_bone(bname)
						prints("[CCDIK_BONE] name:", bname, "  find_bone:", b_idx)
		else:
			prints("[CCDIK_DIAG] CCDIK node not found or not SkeletonModifier3D")

		if _look_at_target != null:
			var tip_global: Vector3 = _skeleton.global_transform * _skeleton.get_bone_global_pose(s2_idx).origin if s2_idx != -1 else Vector3.ZERO
			prints("[TARGET_POS] look_at_target.global:", _look_at_target.global_position,
				"  spine_02_tip_world:", tip_global,
				"  tip→target_dist:", tip_global.distance_to(_look_at_target.global_position))

		# DIAGNOSTIC: skeleton-local target direction
		if _look_at_target != null and s2_idx != -1:
			var spine_pos_skel: Vector3 = _skeleton.get_bone_global_pose(s2_idx).origin
			var spine_pos_world: Vector3 = _skeleton.global_transform * spine_pos_skel
			var to_target_world: Vector3 = (_look_at_target.global_position - spine_pos_world).normalized()
			var local_dir: Vector3 = (_skeleton.global_basis.inverse() * to_target_world).normalized()
			prints("[DIAG_LOCAL_DIR] spine_02_pos(skel):", spine_pos_skel,
				"  to_target_world:", to_target_world,
				"  local_dir:", local_dir,
				"  local_dir.x:", local_dir.x,
				"  skel_basis:", _skeleton.global_basis)

		# DIAGNOSTIC: weapon-to-camera alignment
		var cc: CameraController = _aim_controller.camera_controller if _aim_controller != null else null
		if cc != null:
			var cam: Camera3D = cc.fps_camera if cc.using_fps else cc.tps_camera
			if cam != null and _gun_bone_idx != -1 and s2_idx != -1:
				var cam_pitch_deg := rad_to_deg(pitch)

				var spine_gpose: Transform3D = _skeleton.get_bone_global_pose(s2_idx)
				var spine_fwd: Vector3 = -spine_gpose.basis.z.normalized()
				var spine_pitch_deg := rad_to_deg(asin(clampf(spine_fwd.y, -1.0, 1.0)))

				var gun_gpose: Transform3D = _skeleton.get_bone_global_pose(_gun_bone_idx)
				var gun_fwd: Vector3 = -gun_gpose.basis.z.normalized()
				var gun_pitch_deg := rad_to_deg(asin(clampf(gun_fwd.y, -1.0, 1.0)))

				prints("[PITCH_CHAIN]  cam: %+.2f°  spine02: %+.2f°  (Δ: %+.2f°)  weapon: %+.2f°  (Δspine: %+.2f°)" % [
					cam_pitch_deg, spine_pitch_deg, spine_pitch_deg - cam_pitch_deg,
					gun_pitch_deg, gun_pitch_deg - spine_pitch_deg])

				var gun_world: Vector3 = _skeleton.global_transform * gun_gpose.origin
				var gun_screen: Vector2 = cam.unproject_position(gun_world)
				var vp_size: Vector2 = get_viewport().get_visible_rect().size
				var center: Vector2 = vp_size / 2.0
				var screen_offset: Vector2 = gun_screen - center
				prints("[GUN_SCREEN]  pos: (%.0f, %.0f)  center: (%.0f, %.0f)  offset: (%.0f, %.0f)  dist: %.0f px" % [
					gun_screen.x, gun_screen.y, center.x, center.y,
					screen_offset.x, screen_offset.y, screen_offset.length()])

				var cam_fwd: Vector3 = -cam.global_transform.basis.z.normalized()
				var dot_wpn_cam: float = gun_fwd.dot(cam_fwd)
				prints("[WEAPON·CAM]  dot: %+.4f  angle: %+.2f°" % [
					dot_wpn_cam, rad_to_deg(acos(clampf(dot_wpn_cam, -1.0, 1.0)))])

# ============================================================
#  RESOLVE
# ============================================================

func _resolve_dependencies() -> void:
	if _character_controller == null and not character_controller_path.is_empty():
		_character_controller = get_node(character_controller_path) as CharacterController
	if _aim_controller == null and not aim_controller_path.is_empty():
		_aim_controller = get_node(aim_controller_path) as AimController
	if _look_at_target == null and not look_at_target_path.is_empty():
		_look_at_target = get_node(look_at_target_path) as Node3D

func _cache_bone_indices() -> void:
	_pelvis_idx = _skeleton.find_bone("pelvis")
	_spine01_idx = _skeleton.find_bone("spine_01")
	_spine02_idx = _skeleton.find_bone("spine_02")
	_gun_bone_idx = _skeleton.find_bone("ik_hand_gun")

# ============================================================
#  INFLUENCE
# ============================================================

func _compute_target_influence() -> float:
	if _character_controller == null:
		return 0.0
	if not _character_controller.has_main_hand_weapon():
		return INFLUENCE_UNARMED
	if _character_controller.is_effectively_aiming():
		return INFLUENCE_AIMING
	return INFLUENCE_ARMED

func _blend_influence(delta: float, target: float) -> void:
	if delta <= 0.0:
		_current_influence = target
		return
	var alpha: float = 1.0 - exp(-INFLUENCE_BLEND_SPEED * delta)
	_current_influence = lerpf(_current_influence, target, alpha)
	if absf(_current_influence - target) <= INFLUENCE_EPSILON:
		_current_influence = target

# ============================================================
#  AIM
# ============================================================

func _get_camera_pitch() -> float:
	if _aim_controller == null or _aim_controller.camera_controller == null:
		return 0.0
	var cam := _aim_controller.camera_controller as CameraController
	return cam.fps_pitch if cam.using_fps else cam.tps_pitch

func _get_aim_direction_local() -> Vector3:
	if _aim_controller == null:
		return Vector3(0.0, 0.0, -1.0)
	var dir: Vector3 = _aim_controller.aim_direction
	if dir == Vector3.ZERO:
		return Vector3(0.0, 0.0, -1.0)
	return (_skeleton.global_transform.basis.inverse() * dir).normalized()
