extends SkeletonModifier3D
class_name FullBodyIKController

# ============================================================
#  EXPORTS
# ============================================================

@export var aim_controller_path: NodePath
@export var visuals_component_path: NodePath
@export var character_controller_path: NodePath
@export var aim_target_path: NodePath
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
var _modifiers: Dictionary = {}
var _weights: Dictionary = {}
var _weight_targets: Dictionary = {}
var _warned_messages: Dictionary = {}

var _ik_hand_gun_bone_idx: int = -1
var _arm_r_bone_idx: int = -1

## Set true only after _ready() fully resolves dependencies and caches
## state. Until then the modifier tick is a no-op, so a modifier that
## cannot resolve its dependencies never touches the skeleton.
var _initialized: bool = false

var _debug_f6_pressed: bool = false

# ============================================================
#  CONSTANTS
# ============================================================

const MODIFIER_ORDER: PackedStringArray = [
	"HeadCCDIK",
]

const WEIGHTS_UNARMED: Dictionary = {
	"HeadCCDIK": 0.0,
}

const WEIGHTS_ARMED: Dictionary = {
	"HeadCCDIK": 0.25,
}

const WEIGHTS_AIMING: Dictionary = {
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

	_initialized = true

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_ik_reach"):
		_debug_f6_pressed = true

func _process_modification_with_delta(delta: float) -> void:
	if not _initialized:
		return
	_update_aim_target()
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

	var external_ok: bool = _character_controller != null and _aim_controller != null and _visuals_component != null
	if not external_ok:
		_warn_once("external_deps_unresolved", "FullBodyIKController: player dependencies unavailable; modifier stays inactive.")

	return internal_ok and external_ok

func _cache_bone_indices() -> void:
	_ik_hand_gun_bone_idx = _skeleton.find_bone("ik_hand_gun")
	_arm_r_bone_idx = _skeleton.find_bone("arm_r")

	if _ik_hand_gun_bone_idx == -1:
		push_warning("FullBodyIKController: skeleton missing bone 'ik_hand_gun'. Debug diagnostics disabled.")

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

func _init_weights() -> void:
	_weights = WEIGHTS_UNARMED.duplicate()
	_weight_targets = WEIGHTS_UNARMED.duplicate()
	_apply_modifier_weights()

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

func _blend_weights(delta: float) -> void:
	var blend_alpha: float = 1.0 - exp(-weight_blend_speed * delta)
	for modifier_name in MODIFIER_ORDER:
		var current: float = float(_weights.get(modifier_name, 0.0))
		var target: float = float(_weight_targets.get(modifier_name, 0.0))
		var blended: float = lerpf(current, target, blend_alpha)
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

	var rbone: Vector3 = (skel_tf * _skeleton.get_bone_global_pose(hand_r_idx)).origin if hand_r_idx != -1 else Vector3.ZERO
	var lbone: Vector3 = (skel_tf * _skeleton.get_bone_global_pose(hand_l_idx)).origin if hand_l_idx != -1 else Vector3.ZERO

	prints("[RHandBone]    world:", _v3_str(rbone))
	prints("[LHandBone]    world:", _v3_str(lbone))

	# Modifier influences
	var head_mod := _modifiers.get("HeadCCDIK") as SkeletonModifier3D
	prints("[HeadCCDIK]    influence:", "%.3f" % head_mod.influence if head_mod != null else "N/A")

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
	if _ik_hand_gun_bone_idx != -1 and _arm_r_bone_idx != -1:
		var gun_pose: Transform3D = _skeleton.get_bone_global_pose(_ik_hand_gun_bone_idx)
		var gun_world: Transform3D = skel_tf * gun_pose
		var shoulder_world: Vector3 = (skel_tf * _skeleton.get_bone_global_pose(_arm_r_bone_idx)).origin
		var shoulder_gun_dist: float = shoulder_world.distance_to(gun_world.origin)

		prints("[PivotDiag]    gun_world:", _v3_str(gun_world.origin))
		prints("[PivotDiag]    arm_r→gun: %.4f" % shoulder_gun_dist)

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
		result.append(entry)
	return result

func get_ik_target_positions() -> Dictionary:
	return {
		"aim": _aim_target.global_position if _aim_target != null else Vector3.ZERO,
	}
