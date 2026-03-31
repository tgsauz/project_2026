## InventoryViewController
## Manages inventory UI mode and camera orbital animation
## Responsible for toggling inventory view and orchestrating camera transitions
extends Node

class_name InventoryViewController

## Emitted when inventory mode is toggled
signal inventory_mode_changed(is_active: bool)

@export var inventory_action_name: String = "inventory"
@export var orbit_distance: float = 3.5
@export var orbit_height: float = 1.2
@export var orbit_forward_offset: float = 0.8
@export var orbit_right_offset: float = 0.6
@export var animation_duration: float = 0.5

var is_inventory_mode: bool = false
var _inventory_camera: Camera3D
var _main_camera: Camera3D
var _camera_tween: Tween
var _character: Node3D

func _ready() -> void:
	# Create independent camera
	_inventory_camera = Camera3D.new()
	_inventory_camera.name = "InventoryOrbitCamera"
	_inventory_camera.current = false
	add_child(_inventory_camera)
	
	# Try to find the main camera now, but we can also find it at runtime
	_main_camera = get_viewport().get_camera_3d()

func _unhandled_input(event: InputEvent) -> void:
	# Listen for toggle action
	if event.is_action_pressed(inventory_action_name) or event.is_action_pressed("ui_focus_next"):
		toggle_inventory_mode()
		get_tree().root.set_input_as_handled()
	
	# Listen for exit via Escape
	elif is_inventory_mode and event.is_action_pressed("ui_cancel"):
		exit_inventory_mode()
		get_tree().root.set_input_as_handled()

## Toggle between inventory mode and normal mode
func toggle_inventory_mode() -> void:
	if is_inventory_mode:
		exit_inventory_mode()
	else:
		enter_inventory_mode()

## Enter inventory mode with camera orbit animation
func enter_inventory_mode() -> void:
	if not _character:
		push_error("InventoryViewController: Missing character reference")
		return
	
	# Find current main camera to return to it later
	if not is_inventory_mode:
		_main_camera = get_viewport().get_camera_3d()
	
	if not _main_camera:
		return
		
	is_inventory_mode = true
	
	# Setup independent camera
	_inventory_camera.global_transform = _main_camera.global_transform
	_inventory_camera.make_current()
	
	# Kill any existing tween
	if _camera_tween:
		_camera_tween.kill()
	
	# Calculate orbit position around character using character's facing direction
	var char_pos = _character.global_position
	var char_forward = _character.global_transform.basis.z.normalized()
	var char_right = _character.global_transform.basis.x.normalized()
	
	var orbit_pos = char_pos + (char_forward * orbit_distance * orbit_forward_offset) + (char_right * orbit_distance * orbit_right_offset) + Vector3(0, orbit_height, 0)

	
	# Get tier configuration
	var ui_profile = get_ui_profile()
	var should_animate = ui_profile and ui_profile.presentation_tier == UIStyleProfile.PresentationTier.HIGH
	
	if should_animate:
		# Animate camera to orbit position
		_camera_tween = create_tween()
		_camera_tween.set_trans(Tween.TRANS_QUAD)
		_camera_tween.set_ease(Tween.EASE_OUT)
		_camera_tween.set_parallel(true)
		
		_camera_tween.tween_property(_inventory_camera, "global_position", orbit_pos, animation_duration)
		_camera_tween.tween_method(
			func(weight: float): 
				var target_transform = Transform3D().looking_at(char_pos - orbit_pos, Vector3.UP)
				target_transform.origin = _inventory_camera.global_position
				_inventory_camera.global_transform = _inventory_camera.global_transform.interpolate_with(target_transform, weight),
			0.0, 1.0, animation_duration
		)
	else:
		# Instant snap
		_inventory_camera.global_position = orbit_pos
		_inventory_camera.look_at(char_pos, Vector3.UP)
	
	inventory_mode_changed.emit(true)

## Exit inventory mode and restore camera
func exit_inventory_mode() -> void:
	if not _main_camera:
		push_error("InventoryViewController: Missing main camera reference")
		return
	
	is_inventory_mode = false
	
	# Kill any existing tween
	if _camera_tween:
		_camera_tween.kill()
	
	# Get tier configuration
	var ui_profile = get_ui_profile()
	var should_animate = ui_profile and ui_profile.presentation_tier == UIStyleProfile.PresentationTier.HIGH
	
	if should_animate:
		# Animate camera back to original position
		_camera_tween = create_tween()
		_camera_tween.set_trans(Tween.TRANS_QUAD)
		_camera_tween.set_ease(Tween.EASE_OUT)
		_camera_tween.set_parallel(true)
		
		_camera_tween.tween_property(_inventory_camera, "global_position", _main_camera.global_position, animation_duration)
		_camera_tween.tween_method(
			func(weight: float): _inventory_camera.global_transform = _inventory_camera.global_transform.interpolate_with(_main_camera.global_transform, weight),
			0.0, 1.0, animation_duration
		)
		
		await _camera_tween.finished
		if not is_inventory_mode and _main_camera != null and is_instance_valid(_main_camera):
			_main_camera.make_current()
	else:
		# Instant snap
		_main_camera.make_current()
	
	inventory_mode_changed.emit(false)

## Set the character node reference
func set_character(character: Node3D) -> void:
	_character = character

## Get the active character
func get_character() -> Node3D:
	return _character

## Get UI profile for tier-gated behavior
func get_ui_profile() -> UIStyleProfile:
	var ui_root = get_tree().root.find_child("UIRoot", true, false)
	if ui_root and ui_root.has_meta("ui_profile"):
		return ui_root.get_meta("ui_profile")
	
	# Fallback: find UIStyleProfile in scene
	var profile = get_tree().root.find_child("UIStyleProfile", true, false)
	if profile and profile is UIStyleProfile:
		return profile
	
	return null
