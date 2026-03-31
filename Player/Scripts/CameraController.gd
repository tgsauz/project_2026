extends Node3D

# ============================================================
# CAMERA CONTROLLER
# Handles:
# - Mouse input
# - Independent FPS/TPS look state
# - Sending yaw target to Motor
# - Switching between FPS and TPS cameras
# ============================================================

@export_category("Mouse Settings")
@export var mouse_sensitivity: float = 0.002
@export var max_pitch: float = deg_to_rad(80.0)

@export_category("TPS Orbit Settings")
@export var tps_orbit_distance: float = 3.0
@export var tps_shoulder_offset: float = 0.2
@export var tps_height_offset: float = 0.25

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

# Input blocking
var _input_blocked: bool = false
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
	
	fps_pitch = fps_pivot.rotation.x
	tps_pitch = tps_pivot.rotation.x
	if _is_valid_motor(motor):
		fps_yaw = motor.rotation.y
		tps_yaw = motor.rotation.y

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_set_camera_mode(true)
	
	_connect_inventory_view_controller()
	
func _process(_delta):
	if not _is_valid_motor(motor):
		motor = _resolve_motor()
		if not _is_valid_motor(motor):
			return
	
	_apply_active_look()

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
	
	if not _is_valid_motor(motor):
		push_warning("No valid motor found at startup. CameraController will retry via parent traversal.")

	return valid

# ============================================================
# INPUT
# ============================================================

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and not _input_blocked:
		_handle_mouse_motion(event)

	if event.is_action_pressed("toggle_camera"):
		_set_camera_mode(!using_fps)

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# ============================================================
# MOUSE HANDLING
# ============================================================

func _handle_mouse_motion(event: InputEventMouseMotion):
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
	
	# Keep TPS orbit independent from character yaw by compensating parent rotation.
	tps_pivot.rotation.x = tps_pitch
	tps_pivot.rotation.y = tps_yaw - motor.rotation.y
	tps_camera.position = Vector3(tps_shoulder_offset, tps_height_offset, tps_orbit_distance)
	
	if using_fps:
		motor.set_target_yaw(fps_yaw)
	
	motor.set_camera_yaw(tps_yaw if not using_fps else fps_yaw)
	motor.set_camera_mode(using_fps)

func _connect_inventory_view_controller() -> void:
	var inventory_view_controller = get_tree().root.find_child("InventoryViewController", true, false)
	if inventory_view_controller and inventory_view_controller.has_signal("inventory_mode_changed"):
		if not inventory_view_controller.inventory_mode_changed.is_connected(_on_inventory_mode_changed):
			inventory_view_controller.inventory_mode_changed.connect(_on_inventory_mode_changed)

func _on_inventory_mode_changed(is_active: bool) -> void:
	_input_blocked = is_active

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
	
	fps_camera.current = using_fps
	tps_camera.current = not using_fps
	_apply_active_look()
