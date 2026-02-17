extends Node3D

# ============================================================
# CAMERA CONTROLLER
# Handles:
# - Mouse input
# - Shared pitch between FPS and TPS
# - Sending yaw target to Motor
# - Switching between FPS and TPS cameras
# ============================================================

@export_category("Mouse Settings")
@export var mouse_sensitivity: float = 0.002
@export var max_pitch: float = deg_to_rad(80.0)

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

# Shared pitch & yaw
var pitch: float = 0.0
var yaw: float = 0.0

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
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_set_camera_mode(true)

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

	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)

	if event.is_action_pressed("toggle_camera"):
		_set_camera_mode(!using_fps)

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


# ============================================================
# MOUSE HANDLING
# ============================================================

func _handle_mouse_motion(event: InputEventMouseMotion):

	# Update yaw (horizontal look)
	yaw -= event.relative.x * mouse_sensitivity

	# Update pitch (vertical look)
	pitch -= event.relative.y * mouse_sensitivity
	pitch = clamp(pitch, -max_pitch, max_pitch)

	# Apply shared pitch to both pivots
	fps_pivot.rotation.x = pitch
	tps_pivot.rotation.x = pitch

	# Send desired yaw to motor
	motor.set_target_yaw(yaw)

# ============================================================
# CAMERA MODE SWITCHING
# ============================================================

func _set_camera_mode(enable_fps: bool):

	using_fps = enable_fps

	fps_camera.current = using_fps
	tps_camera.current = not using_fps
