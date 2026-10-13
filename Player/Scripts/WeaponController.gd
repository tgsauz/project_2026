extends Node
class_name WeaponController

# ============================================================
# WEAPON CONTROLLER
# Única autoridad de la transform del arma.
#
# Regla: la posición y la orientación del arma SON las del hueso de soporte
# (ik_hand_gun). No hay offset, ni longitud estimada, ni constante de
# dirección, ni capas que compongan correcciones, ni fallback.
#
#   weapon_root.global_transform = skeleton.global_transform
#                                × skeleton.get_bone_global_pose(ik_hand_gun)
#
# Consecuencia: si el arma no está donde se espera, el problema no está
# aquí. Está en el hueso (animación o rig) o en la cadena que lo mueve.
# Ver project-docs/ADRs/0001-el-hueso-es-la-autoridad-del-arma.md
#
# No escribe nada en AimState: AimController es su único productor.
# No lee nada del rig más allá del hueso y de los marcadores del asset.
# ============================================================

## Hueso de soporte del arma. No es un hueso de mano: en el rig actual es
## hijo de spine_02. Ver project-docs/GLOSSARY.md
const WEAPON_SUPPORT_BONE := "ik_hand_gun"

## Marcadores de agarre dentro del asset del arma.
const MARKER_RIGHT_GRIP := "RGRIP"
const MARKER_LEFT_GRIP := "LGRIP"

@export var aim_controller_path: NodePath
@export var fullbody_ik_path: NodePath
@export var visuals_component_path: NodePath
@export var weapon_visual_slot: String = "right_hand"

var weapon_root: Node3D

var _aim_controller: AimController
var _fullbody_ik: FullBodyIKController
var _visuals_component: VisualsComponent
var _skeleton: Skeleton3D
var _gun_bone_idx: int = -1

var _rgrip_local: Transform3D = Transform3D.IDENTITY
var _lgrip_local: Transform3D = Transform3D.IDENTITY
var _rgrip_found: bool = false
var _lgrip_found: bool = false

var _grip: GripTarget = GripTarget.new()

# ============================================================
#  LIFECYCLE
# ============================================================

func _ready() -> void:
	weapon_root = get_parent() as Node3D
	if weapon_root == null:
		push_error("WeaponController debe ser hijo de WeaponRoot.")
		return

	_aim_controller = get_node_or_null(aim_controller_path) as AimController
	_fullbody_ik = get_node_or_null(fullbody_ik_path) as FullBodyIKController
	_visuals_component = get_node_or_null(visuals_component_path) as VisualsComponent

	if _aim_controller == null:
		push_warning("WeaponController: sin AimController el arma queda en su pose de autor.")
		set_process(false)
		return

	if _visuals_component != null:
		_skeleton = _visuals_component.skeleton
		if _skeleton != null:
			_gun_bone_idx = _skeleton.find_bone(WEAPON_SUPPORT_BONE)
			if _gun_bone_idx == -1:
				push_error("WeaponController: el esqueleto no tiene el hueso '%s'." % WEAPON_SUPPORT_BONE)
				set_process(false)
				return

		if not _visuals_component.equipped_visual_attached.is_connected(_on_visual_attached):
			_visuals_component.equipped_visual_attached.connect(_on_visual_attached)
		if not _visuals_component.equipped_visual_detached.is_connected(_on_visual_detached):
			_visuals_component.equipped_visual_detached.connect(_on_visual_detached)

# ============================================================
#  PER-FRAME
# ============================================================

func _process(_delta: float) -> void:
	if weapon_root == null or _skeleton == null or _gun_bone_idx == -1:
		return

	var pose: Transform3D = _skeleton.global_transform * _skeleton.get_bone_global_pose(_gun_bone_idx)
	weapon_root.global_transform = pose

	_publish_grip_target(pose)

func _publish_grip_target(pose: Transform3D) -> void:
	_grip.right_hand_valid = _rgrip_found
	_grip.left_hand_valid = _lgrip_found

	if _rgrip_found:
		_grip.set_right_hand(pose.origin + pose.basis * _rgrip_local.origin,
				(pose.basis * _rgrip_local.basis).get_rotation_quaternion())
	if _lgrip_found:
		_grip.set_left_hand(pose.origin + pose.basis * _lgrip_local.origin,
				(pose.basis * _lgrip_local.basis).get_rotation_quaternion())

	if _fullbody_ik != null:
		_fullbody_ik.apply_grip_target(_grip)

# ============================================================
#  EQUIP / UNEQUIP
# ============================================================

func _on_visual_attached(slot_name: String, _item_id: String, visual: Node3D, _entry: Dictionary) -> void:
	if slot_name != weapon_visual_slot:
		return

	_cache_grip_markers(visual)
	_adopt_visual(visual)

func _on_visual_detached(slot_name: String, _item_id: String) -> void:
	if slot_name != weapon_visual_slot:
		return

	_rgrip_found = false
	_lgrip_found = false
	_rgrip_local = Transform3D.IDENTITY
	_lgrip_local = Transform3D.IDENTITY

## WeaponRoot es la autoridad de la transform: el visual cuelga de él con
## transformada identidad. Sin esto, el visual conserva la transformada local
## que tenía bajo su anclaje anterior y se suma un offset invisible.
func _adopt_visual(visual: Node3D) -> void:
	if visual == null or weapon_root == null:
		return
	if visual.get_parent() != weapon_root:
		var old_parent: Node = visual.get_parent()
		if old_parent != null:
			old_parent.remove_child(visual)
		weapon_root.add_child(visual)
	visual.transform = Transform3D.IDENTITY

func _cache_grip_markers(weapon: Node3D) -> void:
	_rgrip_found = false
	_lgrip_found = false

	if weapon == null:
		return

	var rgrip: Node3D = _find_marker(weapon, MARKER_RIGHT_GRIP)
	var lgrip: Node3D = _find_marker(weapon, MARKER_LEFT_GRIP)

	# Local a local. Usar el espacio mundo aquí capturaría la transformada
	# transitoria del reparentado del mismo fotograma.
	if rgrip != null:
		_rgrip_local = weapon.transform.affine_inverse() * rgrip.transform
		_rgrip_found = true
	if lgrip != null:
		_lgrip_local = weapon.transform.affine_inverse() * lgrip.transform
		_lgrip_found = true

func _find_marker(weapon: Node3D, marker_name: String) -> Node3D:
	if weapon.name == marker_name:
		return weapon
	return weapon.find_child(marker_name, true, false) as Node3D

func get_weapon_visual() -> Node3D:
	return _visuals_component.get_active_visual(weapon_visual_slot) if _visuals_component != null else null