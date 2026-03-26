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
@export var tps_shoulder_offset: float = 0.35
@export var tps_height_offset: float = 0.25

@export_category("Camera References")
@export var fps_pivot_path: NodePath
@export var tps_pivot_path: NodePath
@export var fps_camera_path: NodePath
@export var tps_camera_path: NodePath

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

# ============================================================
# READY
# ============================================================
func _ready():
	fps_pivot = get_node(fps_pivot_path)
	tps_pivot = get_node(tps_pivot_path)
	fps_camera = get_node(fps_camera_path)
	tps_camera = get_node(tps_camera_path)
	motor = get_tree().get_first_node_in_group("Player")
	
	_assert_nodes()
	
	fps_pitch = fps_pivot.rotation.x
	tps_pitch = tps_pivot.rotation.x
	fps_yaw = motor.rotation.y
	tps_yaw = motor.rotation.y

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_set_camera_mode(true)
	
func _process(_delta):
	_apply_active_look()

func _assert_nodes():
	assert(fps_pivot != null, "FPS Pivot not assigned!")
	assert(tps_pivot != null, "TPS Pivot not assigned!")
	assert(fps_camera != null, "FPS Camera not assigned!")
	assert(tps_camera != null, "TPS Camera not assigned!")
	assert(motor != null, "No node in group 'Player' found!")

# ============================================================
# INPUT
# ============================================================

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
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
	fps_pivot.rotation.x = fps_pitch
	
	# Keep TPS orbit independent from character yaw by compensating parent rotation.
	tps_pivot.rotation.x = tps_pitch
	tps_pivot.rotation.y = tps_yaw - motor.rotation.y
	tps_camera.position = Vector3(tps_shoulder_offset, tps_height_offset, tps_orbit_distance)
	
	if using_fps:
		motor.set_target_yaw(fps_yaw)
	
	motor.set_camera_yaw(tps_yaw if not using_fps else fps_yaw)
	motor.set_camera_mode(using_fps)

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
