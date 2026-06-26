extends Node
class_name AimController

# ============================================================
# AIM CONTROLLER
# Central owner of ADS feel parameters.
# Reads weapon_stance from parent CharacterController,
# computes ADS weight and target FOV, pushes to CameraController.
# Also temporarily resolves weapon SIGHT_BACK node for camera displacement.
# ============================================================

@export_category("ADS Timing")
@export var ads_enter_speed: float = 8.0
@export var ads_exit_speed: float = 10.0

@export_category("FOV Zoom")
@export var default_fov: float = 75.0
@export var fps_ads_fov: float = 55.0
@export var tps_ads_fov: float = 65.0
@export var fov_speed: float = 8.0

var character_controller: CharacterController
var camera_controller: CameraController

var aim_origin: Vector3 = Vector3.ZERO
var aim_direction: Vector3 = Vector3.FORWARD

var _ads_weight: float = 0.0
var _current_fov: float
var _sight_target_position: Vector3 = Vector3.ZERO
var _has_valid_sight: bool = false

func get_ads_weight() -> float:
	return _ads_weight

func _ready():
	character_controller = get_parent() as CharacterController
	if character_controller == null:
		push_error("AimController expects a CharacterController parent.")
		set_process(false)
		return

	camera_controller = character_controller.get_node_or_null("CAMERARIG") as CameraController
	if camera_controller == null:
		push_warning("AimController could not resolve CAMERARIG.")

	_current_fov = default_fov

func _process(delta: float):
	var is_ads: bool = character_controller.is_aiming and not character_controller.is_in_inventory

	_update_aim_basis()
	_update_ads_weight(delta, is_ads)
	_update_sight_tracking(is_ads)
	_update_fov(delta, is_ads)
	_push_to_camera()

func _update_aim_basis() -> void:
	if camera_controller == null:
		return
	var aim_pivot: Node3D = camera_controller.get_active_aim_pivot()
	if aim_pivot == null:
		return
	aim_origin = aim_pivot.global_position
	# World point the crosshair is on, 100m ahead of the camera
	var camera_forward := -aim_pivot.global_transform.basis.z.normalized()
	var aim_point := aim_pivot.global_position + camera_forward * 100.0
	# Direction from character to that crosshair point — decouples IK from camera position
	aim_direction = (aim_point - character_controller.global_position).normalized()

func _update_ads_weight(delta: float, is_ads: bool) -> void:
	var target: float = 1.0 if is_ads else 0.0
	var speed: float = ads_enter_speed if target >= _ads_weight else ads_exit_speed
	_ads_weight = lerpf(_ads_weight, target, 1.0 - exp(-speed * delta))
	if absf(_ads_weight - target) < 0.001:
		_ads_weight = target

func _update_sight_tracking(is_ads: bool) -> void:
	if not is_ads or _ads_weight < 0.001 or not character_controller.is_first_person:
		_has_valid_sight = false
		return

	var weapon_visual: Node3D = _get_weapon_visual()
	if weapon_visual == null:
		_has_valid_sight = false
		return

	var sight: Node3D = weapon_visual.find_child("SIGHT_BACK", true, false) as Node3D
	if sight != null:
		_sight_target_position = sight.global_position
		_has_valid_sight = true
	else:
		_has_valid_sight = false

func _get_weapon_visual() -> Node3D:
	if character_controller.visuals_component == null:
		return null
	return character_controller.visuals_component.get_active_visual("right_hand")

func _update_fov(delta: float, is_ads: bool) -> void:
	var target_fov: float
	if is_ads:
		target_fov = fps_ads_fov if character_controller.is_first_person else tps_ads_fov
	else:
		target_fov = default_fov

	_current_fov = lerpf(_current_fov, target_fov, 1.0 - exp(-fov_speed * delta))
	if absf(_current_fov - target_fov) < 0.001:
		_current_fov = target_fov

func _push_to_camera() -> void:
	if camera_controller == null:
		return

	camera_controller.set_ads_weight(_ads_weight)
	camera_controller.set_current_fov(_current_fov)

	if _has_valid_sight:
		camera_controller.set_ads_position_target(_sight_target_position)
