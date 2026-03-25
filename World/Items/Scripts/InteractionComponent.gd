extends Node
class_name InteractionComponent

@export var camera_path: NodePath
@export var interact_distance: float = 4.0

var camera: Camera3D
var current_item: WorldItem = null

signal focus_changed(item)

# ============================================================
# INIT
# ============================================================

func _ready():
	camera = get_node(camera_path)

# ============================================================
# UPDATE
# ============================================================

func _process(_delta):
	_update_focus()

# ============================================================
# CORE
# ============================================================

func _update_focus():
	var space = get_world_3d().direct_space_state
	
	var from = camera.global_transform.origin
	var to = from + camera.global_transform.basis.z * -interact_distance
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result = space.intersect_ray(query)
	
	var new_item: WorldItem = null
	
	if result:
		var collider = result.collider
		
		if collider is RigidBody3D and collider is WorldItem:
			new_item = collider
	
	if new_item != current_item:
		current_item = new_item
		emit_signal("focus_changed", current_item)

# ============================================================
# ACTION
# ============================================================

func try_interact():
	if current_item == null:
		return
	
	current_item.try_pickup()
