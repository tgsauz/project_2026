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
# No depende de AimController: el arma no lee AimState. Su pose es el hueso.
# No lee nada del rig más allá del hueso y de los marcadores del asset.
# ============================================================

## Hueso de soporte del arma. No es un hueso de mano: en el rig actual es
## hijo de spine_02. Ver project-docs/GLOSSARY.md
const WEAPON_SUPPORT_BONE := "ik_hand_gun"

@export var visuals_component_path: NodePath
@export var weapon_visual_slot: String = "right_hand"

var weapon_root: Node3D

var _visuals_component: VisualsComponent
var _skeleton: Skeleton3D
var _gun_bone_idx: int = -1

# ============================================================
#  LIFECYCLE
# ============================================================

func _ready() -> void:
	weapon_root = get_parent() as Node3D
	if weapon_root == null:
		push_error("WeaponController debe ser hijo de WeaponRoot.")
		return

	# Lee el hueso DESPUES de que la columna procedural lo escribe (prioridad
	# 100): si copia antes, el test lee hueso post-offset y arma pre-offset.
	process_priority = 200

	_visuals_component = get_node_or_null(visuals_component_path) as VisualsComponent

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

# ============================================================
#  PER-FRAME
# ============================================================

func _process(_delta: float) -> void:
	if weapon_root == null or _skeleton == null or _gun_bone_idx == -1:
		return

	var pose: Transform3D = _skeleton.global_transform * _skeleton.get_bone_global_pose(_gun_bone_idx)
	weapon_root.global_transform = pose

# ============================================================
#  EQUIP / UNEQUIP
# ============================================================

func _on_visual_attached(slot_name: String, _item_id: String, visual: Node3D, _entry: Dictionary) -> void:
	if slot_name != weapon_visual_slot:
		return

	_adopt_visual(visual)

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

func get_weapon_visual() -> Node3D:
	return _visuals_component.get_active_visual(weapon_visual_slot) if _visuals_component != null else null