extends Node
class_name InteractionComponent

@export var interact_distance: float = 4.0

var override_camera: Camera3D
var current_target: Node = null
var current_item: WorldItem = null
var current_prompt_text: String = ""

signal focus_changed(item: WorldItem, prompt_text: String)

# ============================================================
# INIT
# ============================================================

func _ready():
	_set_focus(null, null, "")

# ============================================================
# UPDATE
# ============================================================

func _process(_delta):
	_update_focus()

# ============================================================
# CORE
# ============================================================

func _update_focus() -> void:
	var active_camera := _get_active_camera()
	var world := get_viewport().world_3d
	
	if active_camera == null or world == null:
		_set_focus(null, null, "")
		return
	
	var from := active_camera.global_position
	var to := from + (-active_camera.global_basis.z * interact_distance)
	
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result := world.direct_space_state.intersect_ray(query)
	
	var new_target: Node = null
	var new_item: WorldItem = null
	var new_prompt_text := ""
	
	if not result.is_empty():
		var collider = result.get("collider")
		if collider is Node and collider.has_method("interact"):
			new_target = collider
			if collider is WorldItem:
				new_item = collider
			if collider is Node and collider.has_method("get_prompt_text"):
				new_prompt_text = collider.get_prompt_text()

	_set_focus(new_target, new_item, new_prompt_text)
		
func _set_focus(new_target: Node, new_item: WorldItem, new_prompt_text: String) -> void:
	if new_target == current_target and new_item == current_item and new_prompt_text == current_prompt_text:
		return

	current_target = new_target
	current_item = new_item
	current_prompt_text = new_prompt_text
	emit_signal("focus_changed", current_item, current_prompt_text)

func _get_active_camera() -> Camera3D:
	if override_camera != null and is_instance_valid(override_camera):
		return override_camera

	var viewport_camera := get_viewport().get_camera_3d()
	if viewport_camera != null:
		return viewport_camera

	return null

func set_camera(camera: Camera3D) -> void:
	override_camera = camera

# ============================================================
# ACTION
# ============================================================

func try_interact() -> void:
	if current_target == null:
		return
		
	if current_target.has_method("interact"):
		current_target.interact(get_parent())
