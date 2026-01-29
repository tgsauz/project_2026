extends CharacterBody3D

# ───────────── ANIMATION ─────────────
@export var animation_tree: AnimationTree
@onready var animation_state = animation_tree.get("parameters/playback")

# ───────────── CONSTANTS ─────────────
const SPEED := 5.0
const ACCEL := 10.0
const DECEL := 12.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENS := 0.002
const MAX_PITCH := deg_to_rad(80)

var pitch := 0.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
#───────────── DEBUG ─────────────
var using_debug_camera := false
# ───────────── INPUT ─────────────
var input_vector := Vector2.ZERO
var move_dir := Vector3.ZERO

# ───────────── ROOT MOTION CACHE ─────────────
var root_motion_pos := Vector3.ZERO
var root_motion_rot := Quaternion.IDENTITY

# ───────────── STATE ─────────────
var using_root_motion := false

# ───────────── NODES ─────────────
@onready var camera_pivot :=  $Visuals/Rig/Armature/Skeleton3D/BoneAttachment3D/CameraPivot
@onready var fps_camera: Camera3D = $Visuals/Rig/Armature/Skeleton3D/BoneAttachment3D/CameraPivot/Camera3D
@onready var debug_camera_pivot := $DebugCameraPivot
@onready var debug_camera: Camera3D = $DebugCameraPivot/DebugCamera3D


func is_using_root_motion() -> bool:
	return animation_state.get_current_node() == "Climb"
	
func apply_input_movement(delta):
	var target_velocity := move_dir * SPEED

	velocity.x = move_toward(velocity.x, target_velocity.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, ACCEL * delta)

func apply_root_motion(delta):
	var current_rot := (
		animation_tree.get_root_motion_rotation_accumulator().inverse()
		* get_quaternion()
	)
	
	var rm_velocity = (current_rot * root_motion_pos) / delta
	
	velocity.x = rm_velocity.x
	velocity.z = rm_velocity.z
	
	set_quaternion(get_quaternion() * root_motion_rot)

func _process(_delta):
	using_root_motion = is_using_root_motion()
	
	if using_root_motion:
		root_motion_pos = animation_tree.get_root_motion_position()
		root_motion_rot = animation_tree.get_root_motion_rotation()

func _unhandled_input(event):
	if event.is_action_pressed("toggle_debug_camera"):
		using_debug_camera = !using_debug_camera
		debug_camera.current = !debug_camera.current
		fps_camera.current = !debug_camera.current
	
	if event is InputEventMouseButton and event.is_pressed():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		
		if using_debug_camera:
			debug_camera_pivot.rotation.y -= event.relative.x * MOUSE_SENS
			
			pitch -= event.relative.y * MOUSE_SENS
			pitch = clamp(pitch, -MAX_PITCH, MAX_PITCH)
			debug_camera_pivot.rotation.x = pitch
		else:
		#FPS MODE
		# YAW — rotate the character body
			rotation.y -= event.relative.x * MOUSE_SENS

		# PITCH — rotate the camera pivot
			pitch -= event.relative.y * MOUSE_SENS
			pitch = clamp(pitch, -MAX_PITCH, MAX_PITCH)
			camera_pivot.rotation.x = pitch


func _physics_process(delta):
	# ───── INPUT ─────
	input_vector = Input.get_vector("right", "left", "backward", "forward")
	print(input_vector)
	var cam_basis = Basis(Vector3.UP, rotation.y)
	move_dir = cam_basis * Vector3(input_vector.x, 0, input_vector.y)
	move_dir.y = 0
	move_dir = move_dir.normalized()

	# ───── ANIMATION CONDITIONS ─────
	var moving := move_dir.length() > 0.1
	animation_tree.set("parameters/conditions/startmove", moving)
	animation_tree.set("parameters/conditions/idle", !moving)

	# ───── MOVEMENT SOURCE ─────
	if using_root_motion:
		apply_root_motion(delta)
	else:
		apply_input_movement(delta)

	# ───── GRAVITY ─────
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# ───── JUMP ─────
	if Input.is_action_just_pressed("jump") and is_on_floor() and not using_root_motion:
		velocity.y = JUMP_VELOCITY

	move_and_slide()
