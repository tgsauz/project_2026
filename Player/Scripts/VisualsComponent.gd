extends Node

@export_category("Tilt")
@export var tilt_strength: float = 0.08
@export var tilt_smoothing: float = 6.0
@export var max_tilt_angle: float = 0.35

@export_category("References")
@export var skeleton_path: NodePath
@export var bone_name: String = "Spine"

var skeleton: Skeleton3D
var bone_idx: int = -1

var previous_velocity: Vector3 = Vector3.ZERO
var tilt: Vector2 = Vector2.ZERO

func _ready():
	skeleton = get_node(skeleton_path)
	bone_idx = skeleton.find_bone(bone_name)

func update_tilt(delta: float, velocity: Vector3, target_velocity: Vector3, global_basis: Basis):

	var accel = (target_velocity - velocity)  # CLEAN acceleration signal

	var local_accel = global_basis.inverse() * accel

	var target_tilt = Vector2(
		-local_accel.x,
		local_accel.z
	) * tilt_strength

	target_tilt.x = clamp(target_tilt.x, -max_tilt_angle, max_tilt_angle)
	target_tilt.y = clamp(target_tilt.y, -max_tilt_angle, max_tilt_angle)

	tilt = tilt.lerp(target_tilt, tilt_smoothing * delta)

	_apply()

func _apply():

	if bone_idx == -1:
		return

	var pose = skeleton.get_bone_global_pose(bone_idx)

	var rot = Basis()
	rot = rot.rotated(Vector3.RIGHT, tilt.y)
	rot = rot.rotated(Vector3.FORWARD, tilt.x)

	pose.basis = rot * pose.basis

	skeleton.set_bone_global_pose(bone_idx, pose)
