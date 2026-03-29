extends CharacterBody3D
class_name CharacterController

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
@export var interact_hold_threshold: float = 0.28

# ============================================================
#  INVENTORY SYSTEM (WIP)
# ============================================================

var load_factor: float = 0.0  # 0 = light, 1 = heavy+

@export var accel_weight_penalty: float = 0.5
@export var turn_weight_penalty: float = 0.5

# ============================================================
#  REFERENCES
# ============================================================

var inventory: InventoryComponent
var interaction: InteractionComponent
var visuals_component: VisualsComponent
var animation_tree: AnimationTree
var camera_controller: Node

signal quick_action_menu_changed(prompt_data: Dictionary, actions: Array, selected_index: int, is_open: bool)

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
var camera_yaw: float = 0.0
var is_first_person: bool = true
var quick_action_menu_open: bool = false
var quick_action_target: Node = null
var quick_action_prompt_data: Dictionary = {}
var quick_action_entries: Array[Dictionary] = []
var quick_action_selected_index: int = 0
var interact_pressed: bool = false
var interact_press_time_ms: int = 0
var interact_hold_consumed: bool = false

# ============================================================
#  READY
# ============================================================

func _ready():
	if not _resolve_dependencies():
		set_physics_process(false)
		set_process(false)
		return
	
	if camera_controller.has_method("set_motor"):
		camera_controller.set_motor(self)

	if not inventory.weight_changed.is_connected(_on_weight_changed):
		inventory.weight_changed.connect(_on_weight_changed)
	if visuals_component != null:
		visuals_component.bind_inventory(inventory)
	animation_tree.active = true
	target_yaw = rotation.y
	camera_yaw = rotation.y

	_bind_ui()

func _process(_delta: float) -> void:
	_check_interact_hold()

# ============================================================
#  INPUT
# ============================================================

func _unhandled_input(event):

	if event is InputEventMouseButton and event.is_pressed():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event.is_action_pressed("ui_cancel"):
		if quick_action_menu_open:
			_close_quick_action_menu()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event.is_action_pressed("interact"):
		_begin_interact_press()

	if event.is_action_released("interact"):
		_finish_interact_press()

	if event.is_action_pressed("sprint_toggle"):
		if stamina > 10.0:
			is_sprinting = !is_sprinting

	if event.is_action_pressed("quick_actions"):
		if quick_action_menu_open:
			_close_quick_action_menu()
		else:
			open_quick_actions_for_target(interaction.current_target)

	if quick_action_menu_open and event.is_action_pressed("ui_down"):
		_select_next_quick_action(1)

	if quick_action_menu_open and event.is_action_pressed("ui_up"):
		_select_next_quick_action(-1)

# ============================================================
#  EXTERNAL ROTATION
# ============================================================

func set_target_yaw(new_yaw: float) -> void:
	target_yaw = new_yaw

func set_camera_yaw(new_yaw: float) -> void:
	camera_yaw = new_yaw

func set_camera_mode(first_person: bool) -> void:
	is_first_person = first_person

func get_inventory_component() -> InventoryComponent:
	return inventory

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

	var move_yaw = rotation.y if is_first_person else camera_yaw
	var move_basis = Basis(Vector3.UP, move_yaw)

	intent_direction = move_basis * Vector3(input_vector.x, 0, input_vector.y)
	intent_direction.y = 0
	intent_direction = intent_direction.normalized()
	
	if not is_first_person and intent_direction.length_squared() > 0.0:
		target_yaw = atan2(intent_direction.x, intent_direction.z)
		
# ============================================================
#  MOTOR (CORE SYSTEM)
# ============================================================

func _compute_motor(delta):

	var speed := sprint_speed if is_sprinting else move_speed

	# --- WEIGHT MODIFIERS ---
	var accel_mult = lerp(1.0, 1.0 - accel_weight_penalty, load_factor)
	var _turn_mult = lerp(1.0, 1.0 - turn_weight_penalty, load_factor)

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
	if is_first_person:
		rotation.y = target_yaw
		return
	
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

func _on_weight_changed(_new_weight: float, new_load_factor: float):
	load_factor = new_load_factor

# ============================================================
#  QUICK ACTIONS
# ============================================================

func open_quick_actions_for_target(target: Node) -> bool:
	if target == null:
		return false
	if not target.has_method("get_interaction_actions"):
		return false

	var actions: Array[Dictionary] = target.get_interaction_actions(self)
	if actions.is_empty():
		return false

	quick_action_target = target
	quick_action_entries = actions
	quick_action_selected_index = 0
	quick_action_menu_open = true
	if target.has_method("get_interaction_prompt_data"):
		quick_action_prompt_data = target.get_interaction_prompt_data()
	else:
		quick_action_prompt_data = {}

	emit_signal("quick_action_menu_changed", quick_action_prompt_data, quick_action_entries, quick_action_selected_index, true)
	return true

func perform_physical_inventory_action(item_id: String, action_id: String) -> void:
	if inventory == null:
		return

	match action_id:
		"move_to_hand":
			inventory.move_item_to_hand(item_id)
		"unequip":
			inventory.unequip_item(item_id)
		"drop":
			var dropped_item: ItemInstance = inventory.drop_item(item_id) as ItemInstance
			if dropped_item != null:
				_spawn_dropped_world_item(dropped_item)
		"inspect":
			pass

	_close_quick_action_menu()

func _execute_selected_quick_action() -> void:
	if quick_action_target == null:
		return
	if quick_action_selected_index < 0 or quick_action_selected_index >= quick_action_entries.size():
		return

	var action_id: String = quick_action_entries[quick_action_selected_index].get("id", "")
	if action_id.is_empty():
		return

	if quick_action_target.has_method("perform_interaction_action"):
		quick_action_target.perform_interaction_action(self, action_id)

	_close_quick_action_menu()

func _select_next_quick_action(direction: int) -> void:
	if quick_action_entries.is_empty():
		return
	quick_action_selected_index = wrapi(quick_action_selected_index + direction, 0, quick_action_entries.size())
	emit_signal("quick_action_menu_changed", quick_action_prompt_data, quick_action_entries, quick_action_selected_index, true)

func _close_quick_action_menu() -> void:
	quick_action_menu_open = false
	quick_action_target = null
	quick_action_entries.clear()
	quick_action_prompt_data = {}
	quick_action_selected_index = 0
	emit_signal("quick_action_menu_changed", {}, [], 0, false)

func _begin_interact_press() -> void:
	interact_pressed = true
	interact_hold_consumed = false
	interact_press_time_ms = Time.get_ticks_msec()

func _finish_interact_press() -> void:
	if not interact_pressed:
		return

	interact_pressed = false
	if interact_hold_consumed:
		return

	if quick_action_menu_open:
		_execute_selected_quick_action()
		return

	interaction.try_interact()

func _check_interact_hold() -> void:
	if not interact_pressed or interact_hold_consumed:
		return
	if quick_action_menu_open:
		return

	var held_duration := float(Time.get_ticks_msec() - interact_press_time_ms) / 1000.0
	if held_duration < interact_hold_threshold:
		return

	if open_quick_actions_for_target(interaction.current_target):
		interact_hold_consumed = true

func _spawn_dropped_world_item(item: ItemInstance) -> void:
	var world_item := WorldItem.new()
	world_item.item_definition = item.definition
	world_item.item_instance = item
	world_item.freeze = true

	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.35, 0.25, 0.2)
	collision_shape.shape = box_shape
	world_item.add_child(collision_shape)

	get_parent().add_child(world_item)
	world_item.global_position = global_position + (-global_basis.z * 0.8) + Vector3.UP * 1.0

# ============================================================
#  DEPENDENCY RESOLUTION
# ============================================================

func _resolve_dependencies() -> bool:
	inventory = get_node_or_null("InventoryComponent") as InventoryComponent
	interaction = get_node_or_null("InteractionComponent") as InteractionComponent
	visuals_component = get_node_or_null("Visuals") as VisualsComponent

	if visuals_component != null:
		animation_tree = visuals_component.get_node_or_null("Rig/AnimationTree") as AnimationTree
		camera_controller = visuals_component.get_node_or_null("Rig/CAMERARIG")
	else:
		animation_tree = null
		camera_controller = null

	var valid := true

	if inventory == null:
		push_error("CharacterController requires a child InventoryComponent node.")
		valid = false

	if interaction == null:
		push_error("CharacterController requires a child InteractionComponent node.")
		valid = false

	if visuals_component == null:
		push_error("CharacterController requires a child Visuals node.")
		valid = false

	if animation_tree == null:
		push_error("CharacterController could not resolve Visuals/Rig/AnimationTree.")
		valid = false

	if camera_controller == null:
		push_error("CharacterController could not resolve Visuals/Rig/CAMERARIG.")
		valid = false

	return valid

func _bind_ui() -> void:
	var ui_root := get_node_or_null("UIRoot")
	if ui_root != null and ui_root.has_method("bind_character"):
		ui_root.bind_character(self)
