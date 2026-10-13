extends Node3D
class_name CameraController

# ============================================================
# CAMERA CONTROLLER
# Handles:
# - Mouse input
# - Independent FPS/TPS look state
# - Sending yaw target to Motor
# - Switching between FPS and TPS cameras
# - Head-bone anchored FPS pivot (always at eye position)
# ============================================================

@export_category("Mouse Settings")
@export var mouse_sensitivity: float = 0.002
@export var max_pitch: float = deg_to_rad(80.0)

@export_category("TPS Orbit Settings")
@export var tps_orbit_distance: float = 3.0
@export var tps_shoulder_offset: float = 0.2
@export var tps_height_offset: float = 0.25

@export_category("Head-Bone Anchoring")
## Path to the VisualsComponent node for reading head-bone eye position.
## Leave empty to use the legacy fixed FPS pivot position.
@export var visuals_component_path: NodePath = NodePath()

var fps_pivot: Node3D
var tps_pivot: Node3D
var fps_camera: Camera3D
var tps_camera: Camera3D

var motor: CharacterBody3D

# Independent look state
var fps_pitch: float = 0.0
var fps_yaw: float = 0.0
var tps_pitch: float = 0.0
var tps_yaw: float = 0.0

# Current mode
var using_fps: bool = true
var is_debug_free: bool = false
var debug_camera: Camera3D
var debug_fly_speed: float = 5.0
var debug_fly_accel: float = 10.0
var _debug_velocity: Vector3 = Vector3.ZERO

# Input blocking
var _input_blocked: bool = false
var _motor_warning_emitted: bool = false
var _inventory_view_controller: InventoryViewController

# Head-bone anchoring
var _visuals_component: VisualsComponent
var _head_bone_warning_emitted: bool = false

# ============================================================
# ADS STATE (read from AimState via apply_aim_state)
# ============================================================
var _current_ads_weight: float = 0.0
var _current_fov: float = 75.0
## Default local position of fps_pivot, captured once in _ready().
var _fps_pivot_default_local_position: Vector3 = Vector3.ZERO

# ============================================================
# READY
# ============================================================
func _ready():
	fps_pivot = get_node_or_null("FPSPIVOT") as Node3D
	tps_pivot = get_node_or_null("TPSPIVOT") as Node3D
	fps_camera = get_node_or_null("FPSPIVOT/FPSCAMERA") as Camera3D
	tps_camera = get_node_or_null("TPSPIVOT/TPSCAMERA") as Camera3D
	motor = _resolve_motor()

	if not _validate_required_nodes():
		set_process(false)
		return

	if fps_pivot != null:
		_fps_pivot_default_local_position = fps_pivot.position

	if not visuals_component_path.is_empty():
		_visuals_component = get_node_or_null(visuals_component_path) as VisualsComponent
		if _visuals_component == null and not _head_bone_warning_emitted:
			_head_bone_warning_emitted = true
			push_warning("[CameraController] visuals_component_path '%s' did not resolve to a VisualsComponent." % visuals_component_path)

	_setup_debug_camera()

	call_deferred("_finalize_motor_startup")

	fps_pitch = fps_pivot.rotation.x
	tps_pitch = tps_pivot.rotation.x
	if _is_valid_motor(motor):
		fps_yaw = motor.rotation.y
		tps_yaw = motor.rotation.y

	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_set_camera_mode(true)

	_connect_inventory_view_controller()

func _process(delta: float):
	_ensure_inventory_view_controller_connected()

	if not _is_valid_motor(motor):
		motor = _resolve_motor()
		if not _is_valid_motor(motor):
			_emit_missing_motor_warning_once()
			return
		_motor_warning_emitted = false

	if is_debug_free:
		_process_debug_fly(delta)
	else:
		_apply_active_look()

func _setup_debug_camera() -> void:
	debug_camera = Camera3D.new()
	debug_camera.name = "DEBUG_CAMERA"
	add_child(debug_camera)
	debug_camera.top_level = true

func set_motor(new_motor: CharacterBody3D) -> void:
	if not _is_valid_motor(new_motor):
		push_warning("CameraController.set_motor received an invalid motor reference.")
		return

	motor = new_motor
	fps_yaw = motor.rotation.y
	tps_yaw = motor.rotation.y
	_apply_active_look()

func _resolve_motor() -> CharacterBody3D:
	var node: Node = self
	while node != null:
		if _is_valid_motor(node):
			return node as CharacterBody3D
		node = node.get_parent()
	return null

func _is_valid_motor(node: Node) -> bool:
	if not (node is CharacterBody3D):
		return false
	return node.has_method("set_target_yaw") and node.has_method("set_camera_yaw") and node.has_method("set_camera_mode")

func _validate_required_nodes() -> bool:
	var valid = true
	if fps_pivot == null:
		push_error("CameraController could not resolve FPSPIVOT.")
		valid = false
	if tps_pivot == null:
		push_error("CameraController could not resolve TPSPIVOT.")
		valid = false
	if fps_camera == null:
		push_error("CameraController could not resolve FPSPIVOT/FPSCAMERA.")
		valid = false
	if tps_camera == null:
		push_error("CameraController could not resolve TPSPIVOT/TPSCAMERA.")
		valid = false
	return valid

func _finalize_motor_startup() -> void:
	if not _is_valid_motor(motor):
		motor = _resolve_motor()

	if _is_valid_motor(motor):
		fps_yaw = motor.rotation.y
		tps_yaw = motor.rotation.y
		_apply_active_look()
		return

	_emit_missing_motor_warning_once()

func _emit_missing_motor_warning_once() -> void:
	if _motor_warning_emitted:
		return
	_motor_warning_emitted = true
	push_warning("No valid motor found for CameraController. Input look will stay disabled until a compatible parent is available.")

# ============================================================
# AIM STATE CONSUMER — PUBLIC API
# ============================================================

## Called each frame by AimController with the current AimState.
## CameraController reads presentation-relevant fields (FOV, ads_weight).
func apply_aim_state(state: AimState) -> void:
	if state == null or not state.is_valid:
		return
	_current_ads_weight = state.ads_weight
	_current_fov = state.fov_target
	if fps_camera != null:
		fps_camera.fov = _current_fov
	if tps_camera != null:
		tps_camera.fov = _current_fov

# ============================================================
# RAW LOOK — READ-ONLY PUBLIC API
# ============================================================

## Returns the active camera mode's raw pitch (radians, unmodified).
## Read-only for AimController — CameraController remains the sole writer.
func get_raw_pitch() -> float:
	return fps_pitch if using_fps else tps_pitch

## Returns the active camera mode's raw yaw (radians, unmodified).
## Read-only for AimController — CameraController remains the sole writer.
func get_raw_yaw() -> float:
	return fps_yaw if using_fps else tps_yaw

# ============================================================
# INPUT
# ============================================================

func _unhandled_input(event):
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and not _input_blocked:
		_handle_mouse_motion(event)

	if event.is_action_pressed("toggle_camera") and not is_debug_free:
		_set_camera_mode(!using_fps)

	if event.is_action_pressed("toggle_debug"):
		_toggle_debug_free()

	if is_debug_free and event.is_action_pressed("aim"):
		if motor.has_method("toggle_ads_debug"):
			motor.toggle_ads_debug()

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func apply_recoil(pitch_kick: float, yaw_kick: float) -> void:
	if using_fps:
		fps_pitch += pitch_kick
		fps_pitch = clamp(fps_pitch, -max_pitch, max_pitch)
		fps_yaw += yaw_kick
	else:
		tps_pitch += pitch_kick
		tps_pitch = clamp(tps_pitch, -max_pitch, max_pitch)
		tps_yaw += yaw_kick

# ============================================================
# MOUSE HANDLING
# ============================================================

func _handle_mouse_motion(event: InputEventMouseMotion):
	if is_debug_free:
		debug_camera.rotation.y -= event.relative.x * mouse_sensitivity
		debug_camera.rotation.x -= event.relative.y * mouse_sensitivity
		debug_camera.rotation.x = clamp(debug_camera.rotation.x, -PI/2, PI/2)
		return

	if using_fps:
		fps_yaw -= event.relative.x * mouse_sensitivity
		fps_pitch -= event.relative.y * mouse_sensitivity
		fps_pitch = clamp(fps_pitch, -max_pitch, max_pitch)
	else:
		tps_yaw -= event.relative.x * mouse_sensitivity
		tps_pitch -= event.relative.y * mouse_sensitivity
		tps_pitch = clamp(tps_pitch, -max_pitch, max_pitch)

	_apply_active_look()

func _apply_active_look():
	if not _is_valid_motor(motor):
		return

	fps_pivot.rotation.x = fps_pitch

	# Head-bone anchored eye level in FPS, fixed editor position as fallback.
	var base_local: Vector3 = _fps_pivot_default_local_position
	if using_fps and _visuals_component != null:
		var eye_world: Vector3 = _visuals_component.get_eye_world_position()
		if not eye_world.is_zero_approx():
			base_local = to_local(eye_world)
	fps_pivot.position = base_local

	# Keep TPS orbit independent from character yaw by compensating parent rotation.
	tps_pivot.rotation.x = tps_pitch
	tps_pivot.rotation.y = tps_yaw - motor.rotation.y
	tps_camera.position = Vector3(tps_shoulder_offset, tps_height_offset, tps_orbit_distance)

	if using_fps:
		pass  # Body yaw authority transferred to CharacterController (Step 6)

	motor.set_camera_yaw(tps_yaw if not using_fps else fps_yaw)
	motor.set_camera_mode(using_fps)

func get_active_aim_pivot() -> Node3D:
	return fps_pivot if using_fps else tps_pivot

func _connect_inventory_view_controller() -> void:
	var inventory_view_controller := get_tree().root.find_child("InventoryViewController", true, false) as InventoryViewController
	if inventory_view_controller == null:
		return
	if _inventory_view_controller == inventory_view_controller:
		return

	_inventory_view_controller = inventory_view_controller
	if not _inventory_view_controller.inventory_mode_changed.is_connected(_on_inventory_mode_changed):
		_inventory_view_controller.inventory_mode_changed.connect(_on_inventory_mode_changed)
	_on_inventory_mode_changed(_inventory_view_controller.is_inventory_mode)

func _on_inventory_mode_changed(is_active: bool) -> void:
	_input_blocked = is_active

func _ensure_inventory_view_controller_connected() -> void:
	if _inventory_view_controller != null and is_instance_valid(_inventory_view_controller):
		return
	_connect_inventory_view_controller()

# ============================================================
# CAMERA MODE SWITCHING
# ============================================================

func _set_camera_mode(enable_fps: bool):
	if enable_fps != using_fps:
		if enable_fps:
			fps_yaw = tps_yaw
			fps_pitch = tps_pitch
		else:
			tps_yaw = fps_yaw
			tps_pitch = fps_pitch

	using_fps = enable_fps

	if using_fps:
		fps_camera.make_current()
	else:
		tps_camera.make_current()

	_apply_active_look()

func _toggle_debug_free() -> void:
	is_debug_free = !is_debug_free

	if is_debug_free:
		var active_cam = get_viewport().get_camera_3d()
		if active_cam:
			debug_camera.global_transform = active_cam.global_transform
		debug_camera.make_current()
		_debug_velocity = Vector3.ZERO

		if motor:
			motor.debug_input_locked = true
	else:
		if using_fps:
			fps_camera.make_current()
		else:
			tps_camera.make_current()

		if motor:
			motor.debug_input_locked = false

func _process_debug_fly(delta: float) -> void:
	var move_dir = Vector3.ZERO
	if Input.is_key_pressed(KEY_W): move_dir -= debug_camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_S): move_dir += debug_camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_A): move_dir -= debug_camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_D): move_dir += debug_camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_E): move_dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q): move_dir -= Vector3.UP

	var multiplier = 3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	var target_vel = move_dir.normalized() * debug_fly_speed * multiplier
	_debug_velocity = _debug_velocity.move_toward(target_vel, debug_fly_accel * delta)
	debug_camera.global_position += _debug_velocity * delta
