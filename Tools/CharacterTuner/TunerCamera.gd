extends Node3D

@export var target: Node3D
@export var camera_path: NodePath
@export var distance: float = 2.5
@export var orbit_speed: float = 0.5
@export var pan_speed: float = 0.005
@export var zoom_speed: float = 0.1

var rot_x: float = -0.2
var rot_y: float = 0.0
var anchor_pos: Vector3 = Vector3(0, 1, 0)

var camera: Camera3D = null

func _ready() -> void:
	camera = _resolve_camera()
	if camera == null:
		push_error("TunerCamera could not resolve or create a Camera3D.")
		set_process_input(false)
		return
	
	_update_camera()

func _input(event: InputEvent) -> void:
	if camera == null:
		return

	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			# Orbit
			rot_y -= event.relative.x * orbit_speed * 0.01
			rot_x -= event.relative.y * orbit_speed * 0.01
			rot_x = clamp(rot_x, -PI/2 + 0.1, PI/2 - 0.1)
			_update_camera()
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			# Pan
			var right = camera.global_transform.basis.x
			var up = camera.global_transform.basis.y
			anchor_pos -= right * event.relative.x * pan_speed
			anchor_pos += up * event.relative.y * pan_speed
			_update_camera()
			
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance -= zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance += zoom_speed
		distance = max(0.5, distance)
		_update_camera()

func _update_camera() -> void:
	if camera == null:
		return

	var rot = Quaternion.from_euler(Vector3(rot_x, rot_y, 0))
	var offset = rot * Vector3(0, 0, distance)
	camera.position = anchor_pos + offset
	camera.look_at(anchor_pos)

func _resolve_camera() -> Camera3D:
	var resolved_camera: Camera3D = null

	if not camera_path.is_empty():
		resolved_camera = get_node_or_null(camera_path) as Camera3D

	if resolved_camera == null:
		for child in get_children():
			if child is Camera3D:
				resolved_camera = child as Camera3D
				break

	if resolved_camera == null:
		resolved_camera = Camera3D.new()
		resolved_camera.name = "Camera3D"
		add_child(resolved_camera)

	return resolved_camera
