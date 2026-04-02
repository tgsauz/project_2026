extends Node3D

@export var target: Node3D
@export var distance: float = 2.5
@export var orbit_speed: float = 0.5
@export var pan_speed: float = 0.005
@export var zoom_speed: float = 0.1

var rot_x: float = -0.2
var rot_y: float = 0.0
var anchor_pos: Vector3 = Vector3(0, 1, 0)

@onready var camera: Camera3D = $Camera3D

func _ready():
	if not camera:
		camera = Camera3D.new()
		add_child(camera)
	
	_update_camera()

func _input(event):
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

func _update_camera():
	var rot = Quaternion.from_euler(Vector3(rot_x, rot_y, 0))
	var offset = rot * Vector3(0, 0, distance)
	camera.position = anchor_pos + offset
	camera.look_at(anchor_pos)
