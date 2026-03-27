extends Node
class_name InteractionComponent

@export var interact_distance: float = 4.0

var override_camera: Camera3D
var current_target: Node = null
var current_prompt_data: Dictionary = {}

signal focus_changed(prompt_data: Dictionary)

# ============================================================
# INIT
# ============================================================

func _ready():
	_set_focus(null, {})

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
		_set_focus(null, {})
		return
	
	var from := active_camera.global_position
	var to := from + (-active_camera.global_basis.z * interact_distance)
	
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var result := world.direct_space_state.intersect_ray(query)
	
	var new_target: Node = null
	var new_prompt_data := {}
	
	if not result.is_empty():
		var collider := result.get("collider") as Node
		var resolved_target := _resolve_interaction_target(collider)
		if resolved_target != null and resolved_target.has_method("interact"):
			new_target = resolved_target
			if resolved_target.has_method("get_interaction_prompt_data"):
				new_prompt_data = resolved_target.get_interaction_prompt_data()

	_set_focus(new_target, new_prompt_data)
		
func _set_focus(new_target: Node, new_prompt_data: Dictionary) -> void:
	if new_target == current_target and new_prompt_data == current_prompt_data:
		return

	current_target = new_target
	current_prompt_data = new_prompt_data.duplicate(true)
	emit_signal("focus_changed", current_prompt_data)

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

func get_current_quick_actions(actor: Node) -> Array[Dictionary]:
	if current_target == null or not current_target.has_method("get_interaction_actions"):
		return []
	return current_target.get_interaction_actions(actor)

func perform_current_action(actor: Node, action_id: String) -> void:
	if current_target == null or not current_target.has_method("perform_interaction_action"):
		return
	current_target.perform_interaction_action(actor, action_id)

func _resolve_interaction_target(candidate: Node) -> Node:
	if candidate == null:
		return null
	if candidate.has_method("interact"):
		return candidate

	var parent := candidate.get_parent()
	if parent is Node and parent.has_method("interact"):
		return parent

	return null
