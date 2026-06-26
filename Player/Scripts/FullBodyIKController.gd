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

var _right_grip_local_offset: Transform3D = Transform3D.IDENTITY
var _left_grip_local_offset: Transform3D = Transform3D.IDENTITY
var _right_grip_valid: bool = false
var _left_grip_valid: bool = false

var _cached_rgrip_local: Transform3D = Transform3D.IDENTITY
var _cached_lgrip_local: Transform3D = Transform3D.IDENTITY
var _marker_cache_valid: bool = false

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

## Grip IK weight is decoupled from combat state. The IK always
## pulls hands to RGRIP/LGRIP markers at this strength when a
## weapon is equipped. This ensures any weapon + animation combo
## produces correct hand positions without per-state tuning.
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

	if _visuals_component != null and _visuals_component.has_signal("equipped_visual_attached"):
		if not _visuals_component.equipped_visual_attached.is_connected(_on_visual_attached):
			_visuals_component.equipped_visual_attached.connect(_on_visual_attached)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_ik_reach"):
		_debug_f6_pressed = true

func _process_modification_with_delta(delta: float) -> void:
	_cache_weapon_marker_offsets()
	_update_aim_target()
	_update_hand_targets_from_bone_pose()
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

func _resolve_dependencies() -> bool:
	_character_controller = get_node(character_controller_path) as CharacterController
	_aim_controller = get_node(aim_controller_path) as AimController
	_visuals_component = get_node(visuals_component_path) as VisualsComponent
	_aim_target = get_node(aim_target_path) as Node3D
	_right_hand_target = get_node(right_hand_target_path) as Node3D
	_left_hand_target = get_node(left_hand_target_path) as Node3D
	var valid := true
	if _character_controller == null:
		push_error("FullBodyIKController could not resolve CharacterController.")
		valid = false
	if _aim_controller == null:
		push_error("FullBodyIKController could not resolve AimController.")
		valid = false
	if _visuals_component == null:
		push_error("FullBodyIKController could not resolve VisualsComponent.")
		valid = false
	if _aim_target == null:
		push_error("FullBodyIKController could not resolve AimIKTarget.")
		valid = false
	if _right_hand_target == null:
		push_error("FullBodyIKController could not resolve RightHandIKTarget.")
		valid = false
	if _left_hand_target == null:
		push_error("FullBodyIKController could not resolve LeftHandIKTarget.")
		valid = false
	return valid

func _cache_bone_indices() -> void:
	_ik_hand_gun_bone_idx = _skeleton.find_bone("ik_hand_gun")
	_right_arm_root_idx = _skeleton.find_bone("arm_r")
	_left_arm_root_idx = _skeleton.find_bone("arm_l")

	if _ik_hand_gun_bone_idx == -1:
		push_error("FullBodyIKController: skeleton missing bone 'ik_hand_gun'. Hand targets will be invalid.")

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
#  WEAPON GRIP OFFSETS (MARKER LOCAL CACHE)
# ============================================================

func _on_visual_attached(slot_name: String, _item_id: String, visual: Node3D, _entry: Dictionary) -> void:
	if slot_name != "right_hand":
		return
	_cache_marker_locals_from_weapon(visual)

func _cache_marker_locals_from_weapon(weapon: Node3D) -> void:
	_marker_cache_valid = false

	var rgrip := _find_weapon_marker(weapon, "RGRIP")
	var lgrip := _find_weapon_marker(weapon, "LGRIP")

	_cached_rgrip_local = rgrip.transform if rgrip != null else Transform3D.IDENTITY
	_cached_lgrip_local = lgrip.transform if lgrip != null else Transform3D.IDENTITY
	_marker_cache_valid = true

	var r_str: String = _v3_str(_cached_rgrip_local.origin) if rgrip != null else "N/A"
	var l_str: String = _v3_str(_cached_lgrip_local.origin) if lgrip != null else "N/A"
	prints("[IK] Marker cache:", _skeleton.get_bone_name(_ik_hand_gun_bone_idx) if _ik_hand_gun_bone_idx != -1 else "?", "RGRIP=" + r_str, "LGRIP=" + l_str)

static func _find_weapon_marker(weapon: Node3D, marker_name: String) -> Node3D:
	if weapon == null or marker_name.is_empty():
		return null
	if weapon.name == marker_name:
		return weapon
	return weapon.find_child(marker_name, true, false) as Node3D

func _cache_weapon_marker_offsets() -> void:
	if _skeleton == null or _visuals_component == null:
		return

	var has_weapon: bool = _character_controller != null and _character_controller.has_main_hand_weapon()

	if not has_weapon:
		_marker_cache_valid = false

	if not _marker_cache_valid:
		if has_weapon:
			var weapon := _visuals_component.get_active_visual("right_hand")
			if weapon != null:
				_cache_marker_locals_from_weapon(weapon)
			else:
				_right_grip_local_offset = Transform3D.IDENTITY
				_left_grip_local_offset = Transform3D.IDENTITY
				_right_grip_valid = false
				_left_grip_valid = false
				return
		else:
			_right_grip_local_offset = Transform3D.IDENTITY
			_left_grip_local_offset = Transform3D.IDENTITY
			_right_grip_valid = false
			_left_grip_valid = false
			return

	if _ik_hand_gun_bone_idx == -1:
		_right_grip_local_offset = Transform3D.IDENTITY
		_left_grip_local_offset = Transform3D.IDENTITY
		_right_grip_valid = false
		_left_grip_valid = false
		return

	if _cached_rgrip_local != Transform3D.IDENTITY:
		_right_grip_local_offset = _cached_rgrip_local
		_right_grip_valid = true
	else:
		_right_grip_local_offset = Transform3D.IDENTITY
		_right_grip_valid = false

	if _cached_lgrip_local != Transform3D.IDENTITY:
		_left_grip_local_offset = _cached_lgrip_local
		_left_grip_valid = true
	else:
		_left_grip_local_offset = Transform3D.IDENTITY
		_left_grip_valid = false



# ============================================================
#  MODIFIER TICK UPDATES
# ============================================================

func _update_aim_target() -> void:
	if _aim_controller == null or _aim_target == null:
		return
	var aim_dir: Vector3 = _aim_controller.aim_direction
	if aim_dir == Vector3.ZERO:
		aim_dir = Vector3.FORWARD
	_aim_target.global_position = _skeleton.global_position + aim_dir * aim_target_distance

func _update_hand_targets_from_bone_pose() -> void:
	if not _character_controller.has_main_hand_weapon():
		_set_target_weight("RightArmIK", 0.0)
		_set_target_weight("LeftArmIK", 0.0)
		return

	if _ik_hand_gun_bone_idx == -1:
		return

	var bone_pose := _skeleton.get_bone_global_pose(_ik_hand_gun_bone_idx)
	var bone_world := _skeleton.global_transform * bone_pose

	if _arm_ik_valid.get("RightArmIK", false) and _right_hand_target != null:
		_right_hand_target.global_transform = bone_world * _right_grip_local_offset

	if _arm_ik_valid.get("LeftArmIK", false) and _left_hand_target != null:
		_left_hand_target.global_transform = bone_world * _left_grip_local_offset

# ============================================================
#  WEIGHT STATE MACHINE
# ============================================================

func _compute_weight_targets() -> void:
	if not _character_controller.has_main_hand_weapon():
		_weight_targets = WEIGHTS_UNARMED.duplicate()
		return

	if _character_controller.is_effectively_aiming():
		_weight_targets = WEIGHTS_AIMING.duplicate()
		if _aim_controller != null:
			_weight_targets["HeadCCDIK"] = lerpf(WEIGHTS_AIMING["HeadCCDIK"], 0.0, _aim_controller.get_ads_weight())
	else:
		_weight_targets = WEIGHTS_ARMED.duplicate()

	# Grip IK is decoupled from combat state — always use grip weight
	# when weapon is equipped. The per-state table controls HeadCCDIK
	# while IK grip strength is constant.
	_weight_targets["RightArmIK"] = IK_GRIP_WEIGHT
	_weight_targets["LeftArmIK"] = IK_GRIP_WEIGHT

	if not _right_grip_valid:
		_weight_targets["RightArmIK"] = 0.0
	if not _left_grip_valid:
		_weight_targets["LeftArmIK"] = 0.0

func _blend_weights(delta: float) -> void:
	var blend_alpha: float = 1.0 - exp(-weight_blend_speed * delta)
	for modifier_name in MODIFIER_ORDER:
		var current: float = float(_weights.get(modifier_name, 0.0))
		var target: float = float(_weight_targets.get(modifier_name, 0.0))
		var blended := lerpf(current, target, blend_alpha)
		if absf(blended - target) <= zero_weight_epsilon:
			blended = target
		_weights[modifier_name] = blended

func _apply_modifier_weights() -> void:
	for modifier_name in MODIFIER_ORDER:
		var modifier := _modifiers.get(modifier_name, null) as SkeletonModifier3D
		if modifier == null:
			continue
		modifier.influence = clampf(float(_weights.get(modifier_name, 0.0)), 0.0, 1.0)

func _set_target_weight(modifier_name: String, weight: float) -> void:
	_weight_targets[modifier_name] = clampf(weight, 0.0, 1.0)

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

	var weapon := _visuals_component.get_active_visual("right_hand") if _visuals_component != null else null
	if weapon == null:
		prints("===== IK REACH DEBUG =====")
		prints("[No weapon equipped]")
		return

	var skel_tf: Transform3D = _skeleton.global_transform

	prints("")
	prints("===== IK REACH DEBUG (J) =====")

	# Right hand
	var rgrip: Node3D = _visuals_component.get_active_visual_marker("right_hand", "RGRIP")
	var rgrip_world: Vector3 = rgrip.global_position if rgrip != null else Vector3.ZERO
	var rht: Vector3 = _right_hand_target.global_position if _right_hand_target != null else Vector3.ZERO
	var rbone: Vector3 = (skel_tf * _skeleton.get_bone_global_pose(hand_r_idx)).origin if hand_r_idx != -1 else Vector3.ZERO

	prints("[RGRIP]        world:", _v3_str(rgrip_world))
	prints("[RHandTarget]  world:", _v3_str(rht))
	prints("[RHandBone]    world:", _v3_str(rbone))
	if rgrip != null:
		prints("[RGRIP→Target] dist:", "%.4f" % rgrip_world.distance_to(rht))
	if hand_r_idx != -1:
		prints("[RHandBone→Target] dist:", "%.4f" % rbone.distance_to(rht))

	# Arm reach measurement
	if _arm_r_bone_idx != -1 and rgrip != null:
		var arm_r_world: Vector3 = (skel_tf * _skeleton.get_bone_global_pose(_arm_r_bone_idx)).origin
		var arm_r_target_dist: float = arm_r_world.distance_to(rgrip_world)
		var reach_margin: float = _rest_chain_length - arm_r_target_dist
		prints("[ArmReach]     chain: %.4f  arm_r→RGRIP: %.4f  margin_cm: %+.2f" % [
			_rest_chain_length, arm_r_target_dist, reach_margin * 100.0])

	# Chain bone positions and distances to RGRIP
	if rgrip != null:
		var cav_r_world: Vector3 = (skel_tf * _skeleton.get_bone_global_pose(_clavicle_r_bone_idx)).origin if _clavicle_r_bone_idx != -1 else Vector3.ZERO
		var a_r_world: Vector3 = (skel_tf * _skeleton.get_bone_global_pose(_arm_r_bone_idx)).origin if _arm_r_bone_idx != -1 else Vector3.ZERO
		var fa_r_world: Vector3 = (skel_tf * _skeleton.get_bone_global_pose(_forearm_r_bone_idx)).origin if _forearm_r_bone_idx != -1 else Vector3.ZERO
		var h_r_world: Vector3 = (skel_tf * _skeleton.get_bone_global_pose(_hand_r_bone_idx)).origin if _hand_r_bone_idx != -1 else Vector3.ZERO
		prints("[ChainWorld]   clavicle:", _v3_str(cav_r_world))
		prints("[ChainWorld]   arm_r:   ", _v3_str(a_r_world))
		prints("[ChainWorld]   forearm: ", _v3_str(fa_r_world))
		prints("[ChainWorld]   hand_r:  ", _v3_str(h_r_world))
		prints("[ChainWorld]   RGRIP:   ", _v3_str(rgrip_world))
		var cav_dist: float = cav_r_world.distance_to(rgrip_world)
		var arm_dist: float = a_r_world.distance_to(rgrip_world)
		var fa_dist: float = fa_r_world.distance_to(rgrip_world)
		prints("[ChainDist]   clavicle→RGRIP: %.4f  arm_r→RGRIP: %.4f  forearm→RGRIP: %.4f" % [cav_dist, arm_dist, fa_dist])

	# Left hand
	var lgrip: Node3D = _visuals_component.get_active_visual_marker("right_hand", "LGRIP")
	var lgrip_world: Vector3 = lgrip.global_position if lgrip != null else Vector3.ZERO
	var lht: Vector3 = _left_hand_target.global_position if _left_hand_target != null else Vector3.ZERO
	var lbone: Vector3 = (skel_tf * _skeleton.get_bone_global_pose(hand_l_idx)).origin if hand_l_idx != -1 else Vector3.ZERO

	prints("[LGRIP]        world:", _v3_str(lgrip_world))
	prints("[LHandTarget]  world:", _v3_str(lht))
	prints("[LHandBone]    world:", _v3_str(lbone))
	if lgrip != null:
		prints("[LGRIP→Target] dist:", "%.4f" % lgrip_world.distance_to(lht))
	if hand_l_idx != -1:
		prints("[LHandBone→Target] dist:", "%.4f" % lbone.distance_to(lht))

	# Modifier influences
	var rik_mod := _modifiers.get("RightArmIK") as SkeletonModifier3D
	var lik_mod := _modifiers.get("LeftArmIK") as SkeletonModifier3D
	prints("[RightArmIK]   influence:", "%.3f" % rik_mod.influence if rik_mod != null else "N/A")
	prints("[LeftArmIK]    influence:", "%.3f" % lik_mod.influence if lik_mod != null else "N/A")
	prints("[GripValid]    R:", _right_grip_valid, " L:", _left_grip_valid)

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
	# Weapon follows spine rigidly (WeaponPositionController applies only chest offset).
	# arm_r→gun should stay invariant across pitch angles.
	if _ik_hand_gun_bone_idx != -1 and _arm_r_bone_idx != -1 and rgrip != null:
		var gun_pose: Transform3D = _skeleton.get_bone_global_pose(_ik_hand_gun_bone_idx)
		var gun_world: Transform3D = skel_tf * gun_pose
		var shoulder_world: Vector3 = (skel_tf * _skeleton.get_bone_global_pose(_arm_r_bone_idx)).origin
		var shoulder_gun_dist: float = shoulder_world.distance_to(gun_world.origin)
		var grip_world: Vector3 = rgrip_world
		var shoulder_grip_dist: float = shoulder_world.distance_to(grip_world)

		prints("[PivotDiag]    gun_world:", _v3_str(gun_world.origin))
		prints("[PivotDiag]    arm_r→gun: %.4f  arm_r→grip: %.4f" % [shoulder_gun_dist, shoulder_grip_dist])
		prints("[PivotDiag]    weapon follows spine (no independent pitch)")

	# Offsets
	prints("[RHS]          offset:", _v3_str(_right_grip_local_offset.origin))
	prints("[LHS]          offset:", _v3_str(_left_grip_local_offset.origin))

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
