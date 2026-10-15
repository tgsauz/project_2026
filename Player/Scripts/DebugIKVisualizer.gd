extends Node3D
class_name DebugIKVisualizer

@export var skeleton_path: NodePath

@export var show_bones: bool = true
@export var show_axes: bool = true
@export var show_targets: bool = true
@export var show_aim_ray: bool = true
@export var show_camera_ray: bool = true
@export var show_muzzle_ray: bool = true
@export var show_labels: bool = true

const AXIS_LENGTH: float = 0.12
const CROSSHAIR_SIZE: float = 0.04
const LABEL_POOL_SIZE: int = 20

const CAMERA_RAY_LENGTH: float = 10.0
const MUZZLE_RAY_LENGTH: float = 10.0
const CAMERA_RAY_COLOR := Color(1.0, 0.0, 1.0)
const MUZZLE_RAY_COLOR := Color(1.0, 0.55, 0.1)

## Marcador de boca dentro del asset del arma (ver project-docs/GLOSSARY.md).
const MUZZLE_MARKER_NAME := "MUZZLE"

## Esqueleto y punto de mirada, por vecindad acotada al CharacterBody3D
## (el visualizador cuelga de el). Rutas fijas de fallback: las mismas que
## usa CharacterController para AnimationTree.
const SKELETON_FALLBACK_PATH := "VisualsComponent/Rig/ImportedModel/Armature/Skeleton3D"
const LOOK_AT_TARGET_NAME := "LookAtTarget"

const CHAIN_COLORS := {
	"spine": Color(0.31, 0.76, 0.97),
	"arm_r": Color(1.00, 0.44, 0.26),
	"arm_l": Color(0.40, 0.73, 0.42),
	"leg_r": Color(0.67, 0.28, 0.74),
	"leg_l": Color(0.15, 0.65, 0.60),
	"ik":    Color(0.74, 0.74, 0.74),
}

var _skeleton: Skeleton3D
var _skeleton_injected: bool = false
var _look_at_target: Node3D

## Fuentes de los rayos de apuntado. Inyección explícita preferida;
## si no se inyectan, se resuelven por vecindad acotada (el visualizador
## es hijo del CharacterBody3D): CAMERARIG/FPSPIVOT/FPSCAMERA y
## WeaponRoot/WeaponController.
var _fps_camera: Camera3D
var _camera_injected: bool = false
var _weapon_controller: WeaponController
var _weapon_controller_injected: bool = false

## Últimos rayos calculados en espacio global (para dibujo y verificación).
var _camera_ray_origin: Vector3 = Vector3.ZERO
var _camera_ray_dir: Vector3 = Vector3.ZERO
var _has_camera_ray: bool = false
var _muzzle_ray_origin: Vector3 = Vector3.ZERO
var _muzzle_ray_dir: Vector3 = Vector3.ZERO
var _has_muzzle_ray: bool = false

var _mesh_instance: MeshInstance3D
var _immediate_mesh: ImmediateMesh
var _label_pool: Array[Label3D] = []
var _label_pool_index: int = 0

var _inv_global_full: Transform3D
var _inv_global_basis: Basis

func _ready() -> void:
	_resolve_dependencies()
	_resolve_ray_sources()
	if _skeleton == null:
		set_process(false)
		return
	_create_mesh()
	_create_label_pool()

func _exit_tree() -> void:
	if _immediate_mesh != null:
		_immediate_mesh.clear_surfaces()

func set_skeleton(skeleton: Skeleton3D) -> void:
	_skeleton_injected = true
	if skeleton == null:
		push_error("DebugIKVisualizer received a null Skeleton3D.")
		return
	_skeleton = skeleton
	_cache_look_at_target()

func set_camera(camera: Camera3D) -> void:
	_fps_camera = camera
	_camera_injected = true

func set_weapon_controller(controller: WeaponController) -> void:
	_weapon_controller = controller
	_weapon_controller_injected = true

## Resuelve cámara FPS y WeaponController. La inyección explícita
## (set_camera / set_weapon_controller) tiene prioridad; si no hay
## inyección válida, se usa vecindad acotada al padre (CharacterBody3D).
func _resolve_ray_sources() -> void:
	if not is_instance_valid(_fps_camera):
		_fps_camera = null
		if not _camera_injected:
			var host := get_parent()
			if host != null:
				_fps_camera = host.get_node_or_null("CAMERARIG/FPSPIVOT/FPSCAMERA") as Camera3D
	if not is_instance_valid(_weapon_controller):
		_weapon_controller = null
		if not _weapon_controller_injected:
			var host := get_parent()
			if host != null:
				_weapon_controller = host.get_node_or_null("WeaponRoot/WeaponController") as WeaponController

func _resolve_dependencies() -> void:
	if _skeleton_injected:
		return
	if not skeleton_path.is_empty():
		_skeleton = get_node_or_null(skeleton_path) as Skeleton3D
	if _skeleton == null:
		# Vecindad acotada: el visualizador es hijo del CharacterBody3D.
		var host := get_parent()
		if host != null:
			_skeleton = host.get_node_or_null(SKELETON_FALLBACK_PATH) as Skeleton3D
	if _skeleton == null:
		push_error("DebugIKVisualizer could not resolve Skeleton3D.")
		return
	_cache_look_at_target()

## El punto de mirada es el unico objetivo de apuntado que queda vivo:
## lo escribe SpineLookAtController cada fotograma desde el AimState.
func _cache_look_at_target() -> void:
	if _skeleton == null:
		return
	_look_at_target = _skeleton.get_node_or_null(LOOK_AT_TARGET_NAME) as Node3D

func _create_mesh() -> void:
	_immediate_mesh = ImmediateMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "DebugIKMesh"
	_mesh_instance.mesh = _immediate_mesh

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	_mesh_instance.material_override = material

	add_child(_mesh_instance)

func _create_label_pool() -> void:
	for i in range(LABEL_POOL_SIZE):
		var label := Label3D.new()
		label.name = "DebugLabel_%d" % i
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 14
		label.modulate = Color.WHITE
		label.visible = false
		add_child(label)
		_label_pool.append(label)

func _acquire_label() -> Label3D:
	if _label_pool_index >= _label_pool.size():
		return null
	var label: Label3D = _label_pool[_label_pool_index]
	_label_pool_index += 1
	label.visible = true
	return label

func _release_all_labels() -> void:
	for label in _label_pool:
		label.visible = false
	_label_pool_index = 0

func _process(_delta: float) -> void:
	if _skeleton == null:
		return

	_inv_global_full = global_transform.affine_inverse()
	_inv_global_basis = global_transform.basis.transposed()

	_immediate_mesh.clear_surfaces()
	_release_all_labels()

	# Reintento acotado por si el rig se montó después del visualizador.
	if _look_at_target == null:
		_cache_look_at_target()

	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	if show_bones:
		_draw_bone_wireframe()
	if show_axes:
		_draw_bone_axes()
	if show_targets:
		_draw_target_markers()
	if show_aim_ray:
		_draw_aim_ray()
	_update_ray_sources()
	if show_camera_ray:
		_draw_camera_ray()
	if show_muzzle_ray:
		_draw_muzzle_ray()

	_immediate_mesh.surface_end()

	if show_labels:
		_update_labels()

## Posicion global del punto de mirada, o Vector3.ZERO como centinela de
## "todavia sin objetivo": sin ese filtro la cruceta se dibujaria clavada en
## el origen del mundo.
func _get_look_at_position() -> Vector3:
	if _look_at_target == null or not is_instance_valid(_look_at_target):
		return Vector3.ZERO
	return _look_at_target.global_position

# ============================================================
#  BONE HELPERS
# ============================================================

func _get_bone_global_pose(bone_idx: int) -> Transform3D:
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(bone_idx)

func _get_bone_count() -> int:
	return _skeleton.get_bone_count()

func _get_bone_parent(idx: int) -> int:
	return _skeleton.get_bone_parent(idx)

func _get_bone_name(idx: int) -> String:
	return _skeleton.get_bone_name(idx)

static func _get_chain(bone_name: String) -> String:
	match bone_name:
		"root", "pelvis", "spine_01", "spine_02", "neck", "head":
			return "spine"
		"clavicle_r", "arm_r", "forearm_r", "hand_r":
			return "arm_r"
		"clavicle_l", "arm_l", "forearm_l", "hand_l":
			return "arm_l"
		"thigh_r", "calf_r", "foot_r", "toe_r":
			return "leg_r"
		"thigh_l", "calf_l", "foot_l", "toe_l":
			return "leg_l"

	if bone_name.ends_with("_r") and not bone_name.begins_with("ik_"):
		return "arm_r"
	if bone_name.ends_with("_l") and not bone_name.begins_with("ik_"):
		return "arm_l"

	return "ik"

# ============================================================
#  DRAWING HELPERS
# ============================================================

func _add_line(from: Vector3, to: Vector3, color: Color) -> void:
	var local_from := _inv_global_full * from
	var local_to := _inv_global_full * to
	_immediate_mesh.surface_set_color(color)
	_immediate_mesh.surface_add_vertex(local_from)
	_immediate_mesh.surface_set_color(color)
	_immediate_mesh.surface_add_vertex(local_to)

func _draw_bone_wireframe() -> void:
	var count: int = _get_bone_count()
	for i in range(count):
		var parent: int = _get_bone_parent(i)
		if parent == -1:
			continue
		var child_pose: Transform3D = _get_bone_global_pose(i)
		var parent_pose: Transform3D = _get_bone_global_pose(parent)
		var chain: String = _get_chain(_get_bone_name(i))
		var color: Color = CHAIN_COLORS.get(chain, Color.WHITE)
		_add_line(child_pose.origin, parent_pose.origin, color)

func _draw_bone_axes() -> void:
	var count: int = _get_bone_count()
	for i in range(count):
		var pose: Transform3D = _get_bone_global_pose(i)
		var origin: Vector3 = pose.origin
		var bone_basis: Basis = pose.basis

		_add_line(origin, origin + bone_basis.x.normalized() * AXIS_LENGTH, Color.RED)
		_add_line(origin, origin + bone_basis.y.normalized() * AXIS_LENGTH, Color.GREEN)
		_add_line(origin, origin + bone_basis.z.normalized() * AXIS_LENGTH, Color.BLUE)

func _draw_crosshair(pos: Vector3, color: Color, size: float = CROSSHAIR_SIZE) -> void:
	_add_line(pos - Vector3(size, 0, 0), pos + Vector3(size, 0, 0), color)
	_add_line(pos - Vector3(0, size, 0), pos + Vector3(0, size, 0), color)
	_add_line(pos - Vector3(0, 0, size), pos + Vector3(0, 0, size), color)

func _draw_target_markers() -> void:
	var look_at_pos: Vector3 = _get_look_at_position()
	if look_at_pos != Vector3.ZERO:
		_draw_crosshair(look_at_pos, Color.CYAN)

func _draw_aim_ray() -> void:
	var look_at_pos: Vector3 = _get_look_at_position()
	if look_at_pos == Vector3.ZERO or _skeleton == null:
		return
	var skel_origin: Vector3 = _skeleton.global_position
	_add_line(skel_origin, look_at_pos, Color.YELLOW)

# ============================================================
#  RAYOS DE APUNTADO (cámara y boca, en espacio global)
# ============================================================

## Recalcula ambos rayos en espacio global. Se llama cada fotograma
## mientras el visualizador está activo; los valores quedan disponibles
## vía has_camera_ray()/get_camera_ray_*() y has_muzzle_ray()/... aunque
## el dibujo esté apagado con show_camera_ray/show_muzzle_ray.
func _update_ray_sources() -> void:
	_resolve_ray_sources()
	_update_camera_ray()
	_update_muzzle_ray()

func has_camera_ray() -> bool:
	return _has_camera_ray

func get_camera_ray_origin() -> Vector3:
	return _camera_ray_origin

func get_camera_ray_direction() -> Vector3:
	return _camera_ray_dir

func has_muzzle_ray() -> bool:
	return _has_muzzle_ray

func get_muzzle_ray_origin() -> Vector3:
	return _muzzle_ray_origin

func get_muzzle_ray_direction() -> Vector3:
	return _muzzle_ray_dir

func _update_camera_ray() -> void:
	_has_camera_ray = false
	if not is_instance_valid(_fps_camera):
		return
	if not _fps_camera.is_inside_tree():
		return
	_camera_ray_origin = _fps_camera.global_transform.origin
	_camera_ray_dir = -_fps_camera.global_transform.basis.z.normalized()
	_has_camera_ray = true

func _update_muzzle_ray() -> void:
	_has_muzzle_ray = false
	if not is_instance_valid(_weapon_controller):
		return
	if not _weapon_controller.has_method("get_weapon_visual"):
		return
	var visual: Node3D = _weapon_controller.get_weapon_visual() as Node3D
	if not is_instance_valid(visual):
		return
	var muzzle: Node3D = _find_muzzle_marker(visual)
	if muzzle == null or not is_instance_valid(muzzle):
		return
	if not muzzle.is_inside_tree():
		return
	_muzzle_ray_origin = muzzle.global_transform.origin
	_muzzle_ray_dir = -muzzle.global_transform.basis.z.normalized()
	_has_muzzle_ray = true

func _find_muzzle_marker(visual: Node3D) -> Node3D:
	if visual.name == MUZZLE_MARKER_NAME:
		return visual
	return visual.find_child(MUZZLE_MARKER_NAME, true, false) as Node3D

func _draw_camera_ray() -> void:
	if not _has_camera_ray:
		return
	_add_line(_camera_ray_origin, _camera_ray_origin + _camera_ray_dir * CAMERA_RAY_LENGTH, CAMERA_RAY_COLOR)

func _draw_muzzle_ray() -> void:
	if not _has_muzzle_ray:
		return
	_add_line(_muzzle_ray_origin, _muzzle_ray_origin + _muzzle_ray_dir * MUZZLE_RAY_LENGTH, MUZZLE_RAY_COLOR)

# ============================================================
#  LABELS
# ============================================================

func _update_labels() -> void:
	var look_at_pos: Vector3 = _get_look_at_position()
	if look_at_pos != Vector3.ZERO:
		_place_label(look_at_pos, LOOK_AT_TARGET_NAME, Color.CYAN)

	if _has_camera_ray:
		_place_label(_camera_ray_origin + _camera_ray_dir * CAMERA_RAY_LENGTH, "CameraRay", CAMERA_RAY_COLOR)

	if _has_muzzle_ray:
		_place_label(_muzzle_ray_origin + _muzzle_ray_dir * MUZZLE_RAY_LENGTH, "MuzzleRay", MUZZLE_RAY_COLOR)

func _place_label(world_pos: Vector3, text: String, color: Color) -> void:
	var label: Label3D = _acquire_label()
	if label == null:
		return
	label.global_position = world_pos
	label.text = text
	label.modulate = color
