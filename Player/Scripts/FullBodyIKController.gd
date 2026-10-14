extends SkeletonModifier3D
class_name FullBodyIKController

# ============================================================
#  EXPORTS
# ============================================================

@export var aim_controller_path: NodePath
@export var visuals_component_path: NodePath
@export var character_controller_path: NodePath
@export var aim_target_path: NodePath
@export var right_hand_target_path: NodePath
@export var left_hand_target_path: NodePath
@export var aim_target_distance: float = 100.0
@export var weight_blend_speed: float = 8.0
@export var zero_weight_epsilon: float = 0.001
# ============================================================
#  CACHED REFERENCES
# ============================================================

var _skeleton: Skeleton3D
var _character_controller: CharacterController
var _aim_controller: AimController
var _visuals_component: VisualsComponent
var _aim_target: Node3D
var _right_hand_target: Node3D
var _left_hand_target: Node3D
var _modifiers: Dictionary = {}
var _weights: Dictionary = {}
var _weight_targets: Dictionary = {}
var _warned_messages: Dictionary = {}

var _ik_hand_gun_bone_idx: int = -1

var _current_grip_target: GripTarget = null
var _grip_target_valid: bool = false
var _grip_target_just_valid: bool = false

## Set true only after _ready() fully resolves dependencies and caches
## state. Until then the modifier tick is a no-op, so a modifier that
## cannot resolve its dependencies never touches the skeleton.
var _initialized: bool = false

var _arm_ik_valid: Dictionary = {
	"RightArmIK": true,
	"LeftArmIK": true,
}

var _right_arm_root_idx: int = -1
var _left_arm_root_idx: int = -1
var _clavicle_r_bone_idx: int = -1
var _arm_r_bone_idx: int = -1
var _forearm_r_bone_idx: int = -1
var _hand_r_bone_idx: int = -1
var _rest_chain_length: float = 0.0

var _debug_f6_pressed: bool = false

# ============================================================
#  CONSTANTS
# ============================================================

## Grip IK weight is decoupled from combat state. This ensures any weapon +
## animation combo produces correct hand positions without per-state tuning.
##
## MEDIDO 2026-10-14: los TwoBoneIK3D de brazos NO mueven las manos en esta
## version del motor. Desplazar RightHandIKTarget 1 m produce 0.000000 m de
## movimiento en hand_r, con active=true e influence=1.00. Es el mismo
## phenomenon que ADR-0008 midio para los solvers de columna: los
## SkeletonModifier3D no escriben huesos. El error de agarre resultante es de
## 9.56 cm (derecha) y 55.85 cm (izquierda), y viene del clip, no de este
## controlador. Ver el item de lista de pesos muertos en project-docs.
const IK_GRIP_WEIGHT: float = 1.0

const MODIFIER_ORDER: PackedStringArray = [
	"RightArmIK",
	"LeftArmIK",
	"HeadCCDIK",
]

const WEIGHTS_UNARMED: Dictionary = {
	"RightArmIK": 0.0,
	"LeftArmIK": 0.0,
	"HeadCCDIK": 0.0,
}

const WEIGHTS_ARMED: Dictionary = {
	"RightArmIK": 0.3,
	"LeftArmIK": 0.35,
	"HeadCCDIK": 0.25,
}

const WEIGHTS_AIMING: Dictionary = {
	"RightArmIK": 0.5,
	"LeftArmIK": 0.55,
	"HeadCCDIK": 0.35,
}

# ============================================================
#  LIFECYCLE
# ============================================================

func _ready() -> void:
	_skeleton = get_skeleton()
	if _skeleton == null:
		push_error("FullBodyIKController must be a child of Skeleton3D.")
		return
	_try_initialize()

## Injects the player-owned external dependencies. Called by the composition
## root (CharacterController) once the rig exists in the tree. Rig-internal
## references (targets, modifiers) are resolved internally.
func configure(character: CharacterController, aim: AimController, visuals: VisualsComponent) -> void:
	_character_controller = character
	_aim_controller = aim
	_visuals_component = visuals
	if _skeleton != null and not _initialized:
		_try_initialize()

## Resolves dependencies and, only if they are sufficient, configures the
## modifier pipeline and marks the controller operational. Idempotent: a
## failed attempt (no host) leaves it inert and can be retried via configure().
func _try_initialize() -> void:
	if not _resolve_dependencies():
		return

	_cache_bone_indices()
	_cache_modifier_nodes()
	_configure_modifier_nodes()
	_init_weights()

	if _arm_r_bone_idx != -1 and _forearm_r_bone_idx != -1 and _hand_r_bone_idx != -1:
		var forearm_rest: Transform3D = _skeleton.get_bone_rest(_forearm_r_bone_idx)
		var hand_rest: Transform3D = _skeleton.get_bone_rest(_hand_r_bone_idx)
		_rest_chain_length = forearm_rest.origin.length() + hand_rest.origin.length()

	_initialized = true

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_ik_reach"):
		_debug_f6_pressed = true

func _process_modification_with_delta(delta: float) -> void:
	if not _initialized:
		return
	_update_aim_target()
	_update_hand_targets_from_grip_target()
	_compute_weight_targets()
	if delta > 0.0001:
		_blend_weights(delta)
	_apply_modifier_weights()

	if _debug_f6_pressed:
		_debug_f6_pressed = false
		_debug_print_ik_reach()

# ============================================================
#  DEPENDENCY RESOLUTION
# ============================================================

## Resolves rig-internal targets (required) and player-owned externals
## (optional). Internal failures are rig bugs -> push_error. Missing
## externals mean "not hosted by a player" -> warn once and stay inert.
func _resolve_dependencies() -> bool:
	if _aim_target == null and not aim_target_path.is_empty():
		_aim_target = get_node_or_null(aim_target_path) as Node3D
	if _right_hand_target == null and not right_hand_target_path.is_empty():
		_right_hand_target = get_node_or_null(right_hand_target_path) as Node3D
	if _left_hand_target == null and not left_hand_target_path.is_empty():
		_left_hand_target = get_node_or_null(left_hand_target_path) as Node3D

	if _character_controller == null and not character_controller_path.is_empty():
		_character_controller = get_node_or_null(character_controller_path) as CharacterController
	if _aim_controller == null and not aim_controller_path.is_empty():
		_aim_controller = get_node_or_null(aim_controller_path) as AimController
	if _visuals_component == null and not visuals_component_path.is_empty():
		_visuals_component = get_node_or_null(visuals_component_path) as VisualsComponent

	var internal_ok := true
	if _aim_target == null:
		push_error("FullBodyIKController could not resolve AimIKTarget.")
		internal_ok = false
	if _right_hand_target == null:
		push_error("FullBodyIKController could not resolve RightHandIKTarget.")
		internal_ok = false
	if _left_hand_target == null:
		push_error("FullBodyIKController could not resolve LeftHandIKTarget.")
		internal_ok = false

	var external_ok: bool = _character_controller != null and _aim_controller != null and _visuals_component != null
	if not external_ok:
		_warn_once("external_deps_unresolved", "FullBodyIKController: player dependencies unavailable; modifier stays inactive.")

	return internal_ok and external_ok

func _cache_bone_indices() -> void:
	_ik_hand_gun_bone_idx = _skeleton.find_bone("ik_hand_gun")
	_right_arm_root_idx = _skeleton.find_bone("arm_r")
	_left_arm_root_idx = _skeleton.find_bone("arm_l")

	if _ik_hand_gun_bone_idx == -1:
		push_warning("FullBodyIKController: skeleton missing bone 'ik_hand_gun'. Debug diagnostics disabled.")

	_clavicle_r_bone_idx = _skeleton.find_bone("clavicle_r")
	_arm_r_bone_idx = _skeleton.find_bone("arm_r")
	_forearm_r_bone_idx = _skeleton.find_bone("forearm_r")
	_hand_r_bone_idx = _skeleton.find_bone("hand_r")

func _cache_modifier_nodes() -> void:
	_modifiers.clear()
	for modifier_name in MODIFIER_ORDER:
		var modifier := _skeleton.get_node(modifier_name) as SkeletonModifier3D
		if modifier == null:
			_warn_once("modifier_%s" % modifier_name, "FullBodyIKController missing modifier '%s'." % modifier_name)
			continue
		_modifiers[modifier_name] = modifier

func _configure_modifier_nodes() -> void:
	var head_ccdik := _modifiers.get("HeadCCDIK", null) as CCDIK3D
	if head_ccdik != null:
		head_ccdik.set_setting_count(1)
		head_ccdik.set_root_bone_name(0, "neck")
		head_ccdik.set_end_bone_name(0, "head")
		head_ccdik.set_target_node(0, head_ccdik.get_path_to(_aim_target))
		head_ccdik.max_iterations = 4
		head_ccdik.min_distance = 0.01

	_configure_arm_ik("RightArmIK", "arm_r", "forearm_r", "hand_r", _right_hand_target)
	_configure_arm_ik("LeftArmIK", "arm_l", "forearm_l", "hand_l", _left_hand_target)

func _configure_arm_ik(modifier_name: String, root_bone: String, middle_bone: String, end_bone: String, target: Node3D) -> void:
	var arm_ik := _modifiers.get(modifier_name, null) as TwoBoneIK3D
	if arm_ik == null:
		return
	if not _validate_bone(root_bone, modifier_name) or not _validate_bone(middle_bone, modifier_name) or not _validate_bone(end_bone, modifier_name):
		_arm_ik_valid[modifier_name] = false
		arm_ik.influence = 0.0
		push_error("FullBodyIKController: modifier '%s' missing bones. Disabled." % modifier_name)
		return

	_arm_ik_valid[modifier_name] = true
	arm_ik.set_setting_count(1)
	arm_ik.set_root_bone_name(0, root_bone)
	arm_ik.set_middle_bone_name(0, middle_bone)
	arm_ik.set_end_bone_name(0, end_bone)
	arm_ik.set_target_node(0, arm_ik.get_path_to(target))

func _validate_bone(bone_name: String, modifier_name: String) -> bool:
	if _skeleton.find_bone(bone_name) != -1:
		return true
	_warn_once("bone_%s_%s" % [modifier_name, bone_name], "FullBodyIKController: modifier '%s' missing bone '%s'." % [modifier_name, bone_name])
	return false

func _init_weights() -> void:
	_weights = WEIGHTS_UNARMED.duplicate()
	_weight_targets = WEIGHTS_UNARMED.duplicate()
	_apply_modifier_weights()

# ============================================================
#  GRIP TARGET CONSUMER (Step 8 — authority)
# ============================================================

## Receives GripTarget from WeaponController. GripTarget is now
## the authoritative source for hand positioning.
func apply_grip_target(grip_target: GripTarget) -> void:
	if grip_target == null or not grip_target.is_valid:
		_current_grip_target = null
		_grip_target_valid = false
		return

	if not _grip_target_valid:
		_grip_target_just_valid = true
	_current_grip_target = grip_target
	_grip_target_valid = true


# ============================================================
#  MODIFIER TICK UPDATES
# ============================================================

func _update_aim_target() -> void:
	if _aim_controller == null or _aim_target == null:
		return
	var state: AimState = _aim_controller.get_aim_state()
	if state == null or not state.is_valid:
		return
	var aim_dir: Vector3 = state.aim_direction
	if aim_dir == Vector3.ZERO:
		aim_dir = Vector3.FORWARD
	_aim_target.global_position = _skeleton.global_position + aim_dir * aim_target_distance

func _update_hand_targets_from_grip_target() -> void:
	if _current_grip_target == null or not _current_grip_target.is_valid:
		_grip_target_valid = false
		return

	_grip_target_valid = true

	if _current_grip_target.right_hand_valid and _arm_ik_valid.get("RightArmIK", false) and _right_hand_target != null:
		_right_hand_target.global_position = _current_grip_target.right_hand_position
		_right_hand_target.global_transform.basis = Basis(_current_grip_target.right_hand_rotation)

	if _current_grip_target.left_hand_valid and _arm_ik_valid.get("LeftArmIK", false) and _left_hand_target != null:
		_left_hand_target.global_position = _current_grip_target.left_hand_position
		_left_hand_target.global_transform.basis = Basis(_current_grip_target.left_hand_rotation)

# ============================================================
#  WEIGHT STATE MACHINE
# ============================================================

func _compute_weight_targets() -> void:
	if not _character_controller.has_main_hand_weapon():
		_weight_targets = WEIGHTS_UNARMED.duplicate()
		return

	if _character_controller.is_effectively_aiming():
		# Cabeza quieta por ADR-0005 (peso discreto, sin mezcla continua).
		_weight_targets = WEIGHTS_AIMING.duplicate()
		_weight_targets["HeadCCDIK"] = 0.0
	else:
		_weight_targets = WEIGHTS_ARMED.duplicate()

	# Grip IK is decoupled from combat state — always use grip weight when the
	# weapon is equipped. Per-hand validity comes from the GripTarget, so a hand
	# without a grip marker relaxes to the animation instead of a stale target.
	# OJO: estos pesos no tienen efecto observable mientras los TwoBoneIK3D
	# sigan inertes (ver la nota de IK_GRIP_WEIGHT mas arriba). Se mantienen
	# porque son la configuracion correcta si los solvers vuelven a escribir.
	var right_valid: bool = _current_grip_target != null and _current_grip_target.right_hand_valid
	var left_valid: bool = _current_grip_target != null and _current_grip_target.left_hand_valid
	_weight_targets["RightArmIK"] = IK_GRIP_WEIGHT if right_valid else 0.0
	_weight_targets["LeftArmIK"] = IK_GRIP_WEIGHT if left_valid else 0.0

func _blend_weights(delta: float) -> void:
	var blend_alpha: float = 1.0 - exp(-weight_blend_speed * delta)
	var snap_first_frame: bool = _grip_target_just_valid
	_grip_target_just_valid = false
	for modifier_name in MODIFIER_ORDER:
		var current: float = float(_weights.get(modifier_name, 0.0))
		var target: float = float(_weight_targets.get(modifier_name, 0.0))
		var blended: float
		if snap_first_frame and (modifier_name == "RightArmIK" or modifier_name == "LeftArmIK"):
			blended = target
		else:
			blended = lerpf(current, target, blend_alpha)
		if absf(blended - target) <= zero_weight_epsilon:
			blended = target
		_weights[modifier_name] = blended

func _apply_modifier_weights() -> void:
	for modifier_name in MODIFIER_ORDER:
		var modifier := _modifiers.get(modifier_name, null) as SkeletonModifier3D
		if modifier == null:
			continue
		modifier.influence = clampf(float(_weights.get(modifier_name, 0.0)), 0.0, 1.0)

func _warn_once(key: String, message: String) -> void:
	if _warned_messages.has(key):
		return
	_warned_messages[key] = true
	push_warning(message)

# ============================================================
#  ONE-SHOT IK REACH DEBUG (press J when armed)
# ============================================================

func _debug_print_ik_reach() -> void:
	if _skeleton == null:
		return

	var hand_r_idx: int = _skeleton.find_bone("hand_r")
	var hand_l_idx: int = _skeleton.find_bone("hand_l")

	var has_weapon: bool = _character_controller != null and _character_controller.has_main_hand_weapon()
	if not has_weapon:
		prints("===== IK REACH DEBUG =====")
		prints("[No weapon equipped]")
		return

	var skel_tf: Transform3D = _skeleton.global_transform

	prints("")
	prints("===== IK REACH DEBUG (J) =====")

	var r_ik: Vector3 = _current_grip_target.right_hand_position if _current_grip_target != null and _current_grip_target.is_valid else Vector3.ZERO
	var l_ik: Vector3 = _current_grip_target.left_hand_position if _current_grip_target != null and _current_grip_target.is_valid else Vector3.ZERO
	var rht: Vector3 = _right_hand_target.global_position if _right_hand_target != null else Vector3.ZERO
	var lht: Vector3 = _left_hand_target.global_position if _left_hand_target != null else Vector3.ZERO
	var rbone: Vector3 = (skel_tf * _skeleton.get_bone_global_pose(hand_r_idx)).origin if hand_r_idx != -1 else Vector3.ZERO
	var lbone: Vector3 = (skel_tf * _skeleton.get_bone_global_pose(hand_l_idx)).origin if hand_l_idx != -1 else Vector3.ZERO

	prints("[GripTarget R] pos:", _v3_str(r_ik))
	prints("[GripTarget L] pos:", _v3_str(l_ik))
	prints("[RHandTarget]  world:", _v3_str(rht))
	prints("[RHandBone]    world:", _v3_str(rbone))
	prints("[LHandTarget]  world:", _v3_str(lht))
	prints("[LHandBone]    world:", _v3_str(lbone))
	if r_ik != Vector3.ZERO:
		prints("[Grip→RHand]   dist:", "%.4f" % r_ik.distance_to(rht))
	if l_ik != Vector3.ZERO:
		prints("[Grip→LHand]   dist:", "%.4f" % l_ik.distance_to(lht))
	if hand_r_idx != -1:
		prints("[RHandBone→Target] dist:", "%.4f" % rbone.distance_to(rht))
	if hand_l_idx != -1:
		prints("[LHandBone→Target] dist:", "%.4f" % lbone.distance_to(lht))

	# Arm reach measurement
	if _arm_r_bone_idx != -1 and r_ik != Vector3.ZERO:
		var arm_r_world: Vector3 = (skel_tf * _skeleton.get_bone_global_pose(_arm_r_bone_idx)).origin
		var arm_r_target_dist: float = arm_r_world.distance_to(r_ik)
		var reach_margin: float = _rest_chain_length - arm_r_target_dist
		prints("[ArmReach]     chain: %.4f  arm_r→Grip: %.4f  margin_cm: %+.2f" % [
			_rest_chain_length, arm_r_target_dist, reach_margin * 100.0])

	# Chain bone positions and distances to GripTarget
	if r_ik != Vector3.ZERO:
		var cav_r_world: Vector3 = (skel_tf * _skeleton.get_bone_global_pose(_clavicle_r_bone_idx)).origin if _clavicle_r_bone_idx != -1 else Vector3.ZERO
		var a_r_world: Vector3 = (skel_tf * _skeleton.get_bone_global_pose(_arm_r_bone_idx)).origin if _arm_r_bone_idx != -1 else Vector3.ZERO
		var fa_r_world: Vector3 = (skel_tf * _skeleton.get_bone_global_pose(_forearm_r_bone_idx)).origin if _forearm_r_bone_idx != -1 else Vector3.ZERO
		var h_r_world: Vector3 = (skel_tf * _skeleton.get_bone_global_pose(_hand_r_bone_idx)).origin if _hand_r_bone_idx != -1 else Vector3.ZERO
		prints("[ChainWorld]   clavicle:", _v3_str(cav_r_world))
		prints("[ChainWorld]   arm_r:   ", _v3_str(a_r_world))
		prints("[ChainWorld]   forearm: ", _v3_str(fa_r_world))
		prints("[ChainWorld]   hand_r:  ", _v3_str(h_r_world))
		prints("[ChainWorld]   GripR:   ", _v3_str(r_ik))
		var cav_dist: float = cav_r_world.distance_to(r_ik)
		var arm_dist: float = a_r_world.distance_to(r_ik)
		var fa_dist: float = fa_r_world.distance_to(r_ik)
		prints("[ChainDist]   clavicle→Grip: %.4f  arm_r→Grip: %.4f  forearm→Grip: %.4f" % [cav_dist, arm_dist, fa_dist])

	# Modifier influences
	var rik_mod := _modifiers.get("RightArmIK") as SkeletonModifier3D
	var lik_mod := _modifiers.get("LeftArmIK") as SkeletonModifier3D
	prints("[RightArmIK]   influence:", "%.3f" % rik_mod.influence if rik_mod != null else "N/A")
	prints("[LeftArmIK]    influence:", "%.3f" % lik_mod.influence if lik_mod != null else "N/A")
	prints("[GripValid]    ", _grip_target_valid)

	# ik_hand_gun bone diagnostic
	if _ik_hand_gun_bone_idx != -1:
		var gun_rest: Transform3D = _skeleton.get_bone_rest(_ik_hand_gun_bone_idx)
		var gun_global_pose: Transform3D = _skeleton.get_bone_global_pose(_ik_hand_gun_bone_idx)
		var parent_idx: int = _skeleton.get_bone_parent(_ik_hand_gun_bone_idx)
		var parent_name_str: String = _skeleton.get_bone_name(parent_idx) if parent_idx != -1 else "N/A"
		var gun_bone_name_str_local: String = _skeleton.get_bone_name(_ik_hand_gun_bone_idx)

		prints("[ik_hand_gun]  bone:", gun_bone_name_str_local, " parent:", parent_name_str, " (idx:", parent_idx, ")")
		prints("[ik_hand_gun]  restX:", _v3_str(gun_rest.basis.x), " Y:", _v3_str(gun_rest.basis.y), " Z:", _v3_str(gun_rest.basis.z))
		prints("[ik_hand_gun]  global_pose  pos:", _v3_str(gun_global_pose.origin), " X:", _v3_str(gun_global_pose.basis.x), " Y:", _v3_str(gun_global_pose.basis.y), " Z:", _v3_str(gun_global_pose.basis.z))

	# Shoulder-pivot diagnostic
	if _ik_hand_gun_bone_idx != -1 and _arm_r_bone_idx != -1 and r_ik != Vector3.ZERO:
		var gun_pose: Transform3D = _skeleton.get_bone_global_pose(_ik_hand_gun_bone_idx)
		var gun_world: Transform3D = skel_tf * gun_pose
		var shoulder_world: Vector3 = (skel_tf * _skeleton.get_bone_global_pose(_arm_r_bone_idx)).origin
		var shoulder_gun_dist: float = shoulder_world.distance_to(gun_world.origin)
		var shoulder_grip_dist: float = shoulder_world.distance_to(r_ik)

		prints("[PivotDiag]    gun_world:", _v3_str(gun_world.origin))
		prints("[PivotDiag]    arm_r→gun: %.4f  arm_r→grip: %.4f" % [shoulder_gun_dist, shoulder_grip_dist])

	prints("================================")
	prints("")

static func _v3_str(v: Vector3) -> String:
	return "(%.4f, %.4f, %.4f)" % [v.x, v.y, v.z]

# ============================================================
#  DEBUG DATA PROVIDER (consumed by DebugIKVisualizer)
# ============================================================

func get_modifier_debug_info() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mod_name in MODIFIER_ORDER:
		var mod := _modifiers.get(mod_name) as SkeletonModifier3D
		if mod == null:
			continue
		var entry := { "name": mod_name, "influence": mod.influence }
		if mod is CCDIK3D:
			entry.type = "ccdik"
			entry.bones = mod.bones
		elif mod is TwoBoneIK3D:
			entry.type = "two_bone"
			entry.root_bone = _skeleton.find_bone(mod.get_root_bone_name(0))
			entry.middle_bone = _skeleton.find_bone(mod.get_middle_bone_name(0))
			entry.end_bone = _skeleton.find_bone(mod.get_end_bone_name(0))
		result.append(entry)
	return result

func get_ik_target_positions() -> Dictionary:
	return {
		"aim": _aim_target.global_position if _aim_target != null else Vector3.ZERO,
		"right_hand": _right_hand_target.global_position if _right_hand_target != null else Vector3.ZERO,
		"left_hand": _left_hand_target.global_position if _left_hand_target != null else Vector3.ZERO,
	}
