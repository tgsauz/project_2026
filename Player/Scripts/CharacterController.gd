extends CharacterBody3D

# ============================================================
#  MOVEMENT CONFIGURATION
# ============================================================

@export var move_speed: float = 4.0
@export var sprint_speed: float = 6.5

@export var base_accel: float = 10.0
@export var base_decel: float = 8.0

@export var base_turn_speed: float = 6.0
@export var turn_acceleration: float = 10.0

@export var stamina_max: float = 100.0
@export var stamina_drain_rate: float = 20.0
@export var stamina_regen_rate: float = 15.0

# ============================================================
#  INVENTORY SYSTEM (WIP)
# ============================================================

var load_factor: float = 0.0  # 0 = light, 1 = heavy+

@export var accel_weight_penalty: float = 0.5
@export var turn_weight_penalty: float = 0.5

# ============================================================
#  REFERENCES
# ============================================================

@export_category("References")
@export var inventory_path: NodePath
@export var interaction_path: NodePath
@export var visuals_component_path: NodePath
@export var animation_tree_path: NodePath

var inventory : Node
var interaction: Node
var visuals_component : Node
var animation_tree: AnimationTree

# ============================================================
#  INTERNAL STATE
# ============================================================

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# INPUT / INTENT
var input_vector: Vector2 = Vector2.ZERO
var intent_direction: Vector3 = Vector3.ZERO

# MOTOR
var target_velocity: Vector3 = Vector3.ZERO

# SPRINT
var is_sprinting: bool = false
var stamina: float = 100.0

# ROTATION
var target_yaw: float = 0.0

# ============================================================
#  READY
# ============================================================

func _ready():
	inventory = get_node(inventory_path)
	interaction = get_node(interaction_path)
	visuals_component = get_node(visuals_component_path)
	animation_tree = get_node(animation_tree_path)

	assert(inventory != null)
	assert(interaction != null)
	assert(visuals_component != null)
	assert(animation_tree != null)

	inventory.connect("weight_changed", _on_weight_changed)
	animation_tree.active = true
	
	var test_item = preload("res://World/Items/SquareItem.tres")
	inventory.add_item(test_item, 1)

# ============================================================
#  INPUT
# ============================================================

func _unhandled_input(event):

	if event is InputEventMouseButton and event.is_pressed():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event.is_action_pressed("interact"):
		interaction.try_interact()

	if event.is_action_pressed("sprint_toggle"):
		if stamina > 10.0:
			is_sprinting = !is_sprinting

# ============================================================
#  EXTERNAL ROTATION
# ============================================================

func set_target_yaw(new_yaw: float) -> void:
	target_yaw = new_yaw

# ============================================================
#  PHYSICS LOOP
# ============================================================

func _physics_process(delta):

	_collect_input()
	_update_sprint(delta)

	_update_rotation(delta)

	_compute_motor(delta)

	_apply_gravity(delta)
	move_and_slide()

	_update_animation()
	_update_visuals(delta)

# ============================================================
#  INPUT → INTENT
# ============================================================

func _collect_input():

	input_vector = Input.get_vector("right", "left", "backward", "forward")

	var cam_basis = Basis(Vector3.UP, rotation.y)

	intent_direction = cam_basis * Vector3(input_vector.x, 0, input_vector.y)
	intent_direction.y = 0
	intent_direction = intent_direction.normalized()

# ============================================================
#  MOTOR (CORE SYSTEM)
# ============================================================

func _compute_motor(delta):

	var speed := sprint_speed if is_sprinting else move_speed

	# --- WEIGHT MODIFIERS ---
	var accel_mult = lerp(1.0, 1.0 - accel_weight_penalty, load_factor)
	var turn_mult = lerp(1.0, 1.0 - turn_weight_penalty, load_factor)

	var accel = base_accel * accel_mult
	var decel = base_decel * accel_mult

	# --- SOFT SPRINT CONSTRAINT ---
	var adjusted_direction = intent_direction

	if is_sprinting:
		var local_dir = global_transform.basis.inverse() * intent_direction
		local_dir.x *= 0.4
		adjusted_direction = (global_transform.basis * local_dir).normalized()

	# --- TARGET VELOCITY ---
	target_velocity = adjusted_direction * speed

	# --- APPLY ACCELERATION ---
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)

	if intent_direction != Vector3.ZERO:
		horizontal_velocity = horizontal_velocity.move_toward(target_velocity, accel * delta)
	else:
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, decel * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

# ============================================================
#  ROTATION
# ============================================================

func _update_rotation(delta):

	var turn_mult = lerp(1.0, 1.0 - turn_weight_penalty, load_factor)

	var max_turn = base_turn_speed * turn_mult

	var current_yaw = rotation.y
	var new_yaw = lerp_angle(current_yaw, target_yaw, turn_acceleration * delta)

	var angle_diff = wrapf(new_yaw - current_yaw, -PI, PI)
	angle_diff = clamp(angle_diff, -max_turn * delta, max_turn * delta)

	rotation.y += angle_diff

# ============================================================
#  GRAVITY
# ============================================================

func _apply_gravity(delta):

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

# ============================================================
#  SPRINT SYSTEM
# ============================================================

func _update_sprint(delta):

	if is_sprinting:
		stamina -= stamina_drain_rate * delta
		if stamina <= 0.0:
			is_sprinting = false
	else:
		stamina += stamina_regen_rate * delta

	stamina = clamp(stamina, 0.0, stamina_max)

# ============================================================
#  ANIMATION
# ============================================================

func _update_animation():

	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	var local_velocity = global_transform.basis.inverse() * horizontal_velocity

	var max_speed = sprint_speed if is_sprinting else move_speed

	var lateral := 0.0
	var forward := 0.0

	if horizontal_velocity.length() > 0.01:
		lateral = local_velocity.x / max_speed
		forward = -local_velocity.z / max_speed

	lateral = clamp(lateral, -1.0, 1.0)
	forward = clamp(forward, -1.0, 1.0)

	animation_tree.set(
		"parameters/Locomotion/BlendSpace2D/blend_position",
		Vector2(lateral, forward)
	)

# ============================================================
#  VISUALS
# ============================================================

func _update_visuals(delta):

	visuals_component.update_tilt(
		delta,
		velocity,
		target_velocity,
		global_transform.basis
	)

func _on_weight_changed(new_weight: float, new_load_factor: float):
	load_factor = new_load_factor
