extends Node
class_name WeaponActionController

var character_controller: CharacterController
var inventory: InventoryComponent

@export var max_hitreg_distance: float = 100.0

func _ready() -> void:
	character_controller = get_parent() as CharacterController
	if character_controller == null:
		push_warning("WeaponActionController expects a CharacterController parent.")
		set_process_unhandled_input(false)
		return

	call_deferred("_resolve_inventory")

func _resolve_inventory() -> void:
	inventory = character_controller.get_inventory_component()
	if inventory == null:
		push_warning("WeaponActionController could not resolve InventoryComponent.")
		set_process_unhandled_input(false)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
		
	if event.is_action_pressed("primary_action") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()):
		if _can_fire():
			_request_fire()

func _can_fire() -> bool:
	if character_controller.is_in_inventory or character_controller.quick_action_menu_open:
		return false
	
	var item = inventory.get_main_hand_item()
	if item == null or item.definition == null or item.definition.category != ItemDefinition.CATEGORY_WEAPON:
		return false
		
	return true

func _request_fire() -> void:
	# Extract bore direction
	var origin: Vector3
	var direction: Vector3
	
	# For STALKER feel, hitreg can originate from camera center in FPS, or strictly from the barrel.
	# We'll use camera center for player reliability, but cast from the weapon muzzle if requested.
	var cam_pivot = character_controller.camera_controller.get_active_aim_pivot() if character_controller.camera_controller.has_method("get_active_aim_pivot") else null
	if cam_pivot != null and cam_pivot is Node3D:
		origin = cam_pivot.global_position
		direction = -cam_pivot.global_transform.basis.z.normalized()
	else:
		origin = character_controller.global_position + Vector3(0, 1.6, 0)
		direction = -character_controller.global_transform.basis.z.normalized()
	
	# We send the request to the server to validate and process the shot
	rpc_id(1, "server_process_fire", origin, direction)
	
	# Apply local recoil immediately for client-side prediction / feel
	_apply_local_recoil()

@rpc("any_peer", "call_local", "reliable")
func server_process_fire(origin: Vector3, direction: Vector3) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Server authority check
	if not multiplayer.is_server():
		return
		
	# Validate rate of fire, ammo, etc., here in the future
	
	# Broadcast visual shot to all clients (muzzle flash, sound)
	rpc("client_play_fire_effects")
	
	# Server Hitreg
	var space_state = character_controller.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(origin, origin + direction * max_hitreg_distance)
	query.exclude = [character_controller.get_rid()] # exclude self
	
	var result = space_state.intersect_ray(query)
	if result:
		# Apply damage
		var collider = result.collider
		if collider.has_method("apply_damage"):
			collider.apply_damage(10.0, sender_id) # Placeholder damage

@rpc("authority", "call_local", "unreliable")
func client_play_fire_effects() -> void:
	# Here we would play the muzzle flash, sound, and tracer
	# This runs on all proxies so everyone hears/sees the gunshot
	pass

func _apply_local_recoil() -> void:
	if character_controller.camera_controller != null and character_controller.camera_controller.has_method("apply_recoil"):
		# Apply random recoil impulse
		var pitch_kick = randf_range(0.015, 0.025)
		var yaw_kick = randf_range(-0.005, 0.005)
		character_controller.camera_controller.apply_recoil(pitch_kick, yaw_kick)
