extends Node
class_name AimController

# ============================================================
# AIM CONTROLLER
# Central owner of ADS feel parameters.
# Reads weapon_stance from parent CharacterController,
# computes ADS weight and target FOV.
# Produces AimState — downstream systems consume, never write.
# ============================================================

@export_category("ADS Timing")
@export var ads_enter_speed: float = 8.0
@export var ads_exit_speed: float = 10.0

@export_category("FOV Zoom")
@export var default_fov: float = 75.0
@export var fps_ads_fov: float = 55.0
@export var tps_ads_fov: float = 65.0
@export var fov_speed: float = 8.0

@export_category("Orientation Blend")
@export var aim_orient_enter_speed: float = 12.0
@export var aim_orient_exit_speed: float = 10.0

var character_controller: CharacterController
var camera_controller: CameraController

var aim_origin: Vector3 = Vector3.ZERO
var aim_direction: Vector3 = Vector3.FORWARD

var _ads_weight: float = 0.0
var _aim_orientation_weight: float = 0.0
var _current_fov: float

# ============================================================
# AIM STATE PRODUCTION
# ============================================================

var _sequence: int = 0
var _current_state: AimState

func get_ads_weight() -> float:
	return _ads_weight

## Returns the authoritative AimState produced this frame.
## Read-only — downstream systems consume, never write.
func get_aim_state() -> AimState:
	return _current_state

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

	# Initialize with invalid AimState — consumers must check is_valid
	var initial := AimState.new()
	initial.is_valid = false
	_current_state = initial

func _process(delta: float):
	var is_ads: bool = character_controller.is_aiming and not character_controller.is_in_inventory

	_update_aim_basis()
	_update_aim_orientation_weight(delta, is_ads)
	_update_ads_weight(delta, is_ads)
	_update_fov(delta, is_ads)
	_build_aim_state()
	_push_state_to_camera()

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

func _update_aim_orientation_weight(delta: float, is_aiming: bool) -> void:
	var target: float = 1.0 if is_aiming else 0.0
	var speed: float = aim_orient_enter_speed if target >= _aim_orientation_weight else aim_orient_exit_speed
	_aim_orientation_weight = lerpf(_aim_orientation_weight, target, 1.0 - exp(-speed * delta))
	if absf(_aim_orientation_weight - target) < 0.001:
		_aim_orientation_weight = target

func _update_ads_weight(delta: float, is_ads: bool) -> void:
	var target: float = 1.0 if is_ads else 0.0
	var speed: float = ads_enter_speed if target >= _ads_weight else ads_exit_speed
	_ads_weight = lerpf(_ads_weight, target, 1.0 - exp(-speed * delta))
	if absf(_ads_weight - target) < 0.001:
		_ads_weight = target

func _update_fov(delta: float, is_ads: bool) -> void:
	var target_fov: float
	if is_ads:
		target_fov = fps_ads_fov if character_controller.is_first_person else tps_ads_fov
	else:
		target_fov = default_fov

	_current_fov = lerpf(_current_fov, target_fov, 1.0 - exp(-fov_speed * delta))
	if absf(_current_fov - target_fov) < 0.001:
		_current_fov = target_fov

func _push_state_to_camera() -> void:
	if camera_controller == null:
		return
	camera_controller.apply_aim_state(_current_state)

# ============================================================
# AIM STATE BUILD
# ============================================================

func _build_aim_state() -> void:
	var state := AimState.new()

	# Raw look from CameraController (Step 2 getters)
	if camera_controller != null:
		state.look_pitch = camera_controller.get_raw_pitch()
		state.look_yaw = camera_controller.get_raw_yaw()
		state.camera_mode = camera_controller.using_fps
	else:
		state.look_pitch = 0.0
		state.look_yaw = 0.0
		state.camera_mode = true

	# Feed-forward raw yaw for CharacterController body yaw (Step 6)
	state.intended_yaw = state.look_yaw

	# Aim origin: character eye position (not camera pivot — per ADR-12)
	if character_controller.visuals_component != null:
		var eye_pos: Vector3 = character_controller.visuals_component.get_eye_world_position()
		if not eye_pos.is_zero_approx():
			state.aim_origin = eye_pos
			state.eye_position = eye_pos
		else:
			state.aim_origin = aim_origin
			state.eye_position = aim_origin
	else:
		state.aim_origin = aim_origin
		state.eye_position = aim_origin

	# Aim direction from raw pitch/yaw (normalized, decoupled from camera transform)
	var pitch_basis := Basis(Vector3(1.0, 0.0, 0.0), state.look_pitch)
	var yaw_basis := Basis(Vector3(0.0, 1.0, 0.0), state.look_yaw)
	state.aim_direction = (yaw_basis * pitch_basis * Vector3.FORWARD).normalized()

	# ADS and FOV from existing computed state
	state.ads_weight = _ads_weight
	state.aim_orientation_weight = _aim_orientation_weight
	state.fov_target = _current_fov

	# Timestamp and sequence
	state.timestamp = Time.get_ticks_msec()
	_sequence += 1
	state.sequence = _sequence

	state.is_valid = (camera_controller != null and character_controller != null)

	_current_state = state
