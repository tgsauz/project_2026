extends CharacterBody3D

# ============================================================
#  MOVEMENT CONFIGURATION
# ============================================================

@export_category("Movement Speeds")
@export var walk_speed: float = 2.5
@export var fast_walk_speed: float = 4.0
@export var sprint_speed: float = 6.5

@export_category("Acceleration")
@export var walk_accel: float = 8.0
@export var sprint_accel: float = 5.0
@export var deceleration: float = 6.0

@export_category("Rotation")
@export var max_turn_speed: float = 6.0          # radians/sec
@export var turn_acceleration: float = 10.0

@export_category("Sprint System")
@export var stamina_max: float = 100.0
@export var stamina_drain_rate: float = 20.0
@export var stamina_regen_rate: float = 15.0
@export var sprint_commit_time: float = 0.75     # minimum sprint duration

# ============================================================
#  ANIMATION CONFIGURATION
# ============================================================

@export_category("Animation")
@export var animation_tree_path: NodePath

var animation_tree: AnimationTree

# ============================================================
#  INTERNAL STATE
# ============================================================

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Input
var input_vector: Vector2 = Vector2.ZERO
var move_direction: Vector3 = Vector3.ZERO

# Sprint
var is_sprinting: bool = false
var sprint_timer: float = 0.0
var stamina: float = 100.0

# Rotation inertia
var target_yaw: float = 0.0
var current_turn_speed: float = 0.0 #Upgrade or remove?

# ============================================================
#  READY HANDLING
# ============================================================

func _ready():
	animation_tree = get_node(animation_tree_path)
	print("AnimationTree is: ", animation_tree)
	
	assert(animation_tree != null, "Animation Tree not Assigned!")
	
	animation_tree.active = true
	
# ============================================================
#  INPUT HANDLING
# ============================================================

func _unhandled_input(event):
	
	if event is InputEventMouseButton and event.is_pressed():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Toggle Sprint
	if event.is_action_pressed("sprint_toggle"):
		_attempt_toggle_sprint()


func _attempt_toggle_sprint():
	# Only allow sprint if stamina is available
	if stamina > 10.0:
		is_sprinting = !is_sprinting

		# If enabling sprint, start commitment timer
		if is_sprinting:
			sprint_timer = sprint_commit_time

# ============================================================
#  EXTERNAL ROTATION API (Camera → Motor)
# ============================================================

func set_target_yaw(new_yaw: float) -> void:
	target_yaw = new_yaw

#Debug
func _update_animation_parameters():

	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	
	# Speed magnitude
	var speed_value = horizontal_velocity.length()
	
	#Direction relative to character facing
	var local_velocity = global_transform.basis.inverse() * horizontal_velocity
	
	var direction_value = 0.0
	
	if speed_value > 0.01:
		direction_value = local_velocity.x / sprint_speed
	animation_tree.set("parameters/Locomotion/BlendSpace2D/blend_position",Vector2(direction_value, speed_value))
	
	#print("SpeedValue: ", speed_value, "Direction Value: ", direction_value)
	print("Animation Tree parameters: ", animation_tree.get("parameters/Locomotion/BlendSpace2D/blend_position"))


# ============================================================
#  PHYSICS LOOP
# ============================================================

func _physics_process(delta):

	# ---------------------------
	# INPUT COLLECTION
	# ---------------------------
	input_vector = Input.get_vector("right", "left", "backward", "forward")

	var cam_basis = Basis(Vector3.UP, rotation.y)
	move_direction = cam_basis * Vector3(input_vector.x, 0, input_vector.y)
	move_direction.y = 0
	move_direction = move_direction.normalized()

	# ---------------------------
	# SPRINT + STAMINA LOGIC
	# ---------------------------
	_update_sprint_system(delta)

	# ---------------------------
	# ROTATION SYSTEM
	# ---------------------------
	_update_rotation(delta)

	# ---------------------------
	# MOVEMENT CALCULATION
	# ---------------------------
	_apply_movement(delta)
	

	# ---------------------------
	# GRAVITY
	# ---------------------------
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	
	# ---------------------------
	# ANIMATION CALCULATION
	# ---------------------------
	_update_animation_parameters()


# ============================================================
#  MOVEMENT SYSTEM
# ============================================================

func _apply_movement(delta):

	var target_speed: float
	var accel: float

	if is_sprinting:
		target_speed = sprint_speed
		accel = sprint_accel
	else:
		target_speed = fast_walk_speed
		accel = walk_accel

	var target_velocity = move_direction * target_speed

	# Apply acceleration toward target velocity
	velocity.x = move_toward(velocity.x, target_velocity.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, accel * delta)

	# Apply deceleration when no input
	if move_direction == Vector3.ZERO:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)

# ============================================================
#  ROTATION SYSTEM (Angular Inertia)
# ============================================================

func _update_rotation(delta):

	var current_yaw = rotation.y
	
	# Smooth interpolation
	var new_yaw = lerp_angle(current_yaw, target_yaw, turn_acceleration * delta)

	# Clamp turning speed
	var angle_diff = wrapf(new_yaw - current_yaw, -PI, PI)
	var max_step = max_turn_speed * delta
	angle_diff = clamp(angle_diff, -max_step, max_step)

	rotation.y = current_yaw + angle_diff

# ============================================================
#  SPRINT + STAMINA SYSTEM
# ============================================================

func _update_sprint_system(delta):

	if is_sprinting:

		# Commitment timer
		if sprint_timer > 0.0:
			sprint_timer -= delta

		# Drain stamina
		stamina -= stamina_drain_rate * delta
		stamina = max(stamina, 0.0)

		# Force stop sprint if stamina depleted
		if stamina <= 0.0:
			is_sprinting = false

	else:
		# Regenerate stamina when not sprinting
		stamina += stamina_regen_rate * delta
		stamina = min(stamina, stamina_max)

	# Prevent cancelling sprint during commitment
	if sprint_timer > 0.0:
		is_sprinting = true
