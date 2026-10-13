extends RefCounted
class_name AimState

# ============================================================
# AIM STATE
# Immutable data structure — single source of truth for aiming intent.
# Produced by AimController each frame.
# Consumed by CameraController, WeaponController, SpineLookAtController,
# FullBodyIKController, WeaponActionController, AI, Network.
#
# ============================================================

var look_pitch: float = 0.0
var look_yaw: float = 0.0
var intended_yaw: float = 0.0
var aim_origin: Vector3 = Vector3.ZERO
var eye_position: Vector3 = Vector3.ZERO
var aim_direction: Vector3 = Vector3.FORWARD
var aim_target_point: Vector3 = Vector3.ZERO
var ads_weight: float = 0.0
var aim_orientation_weight: float = 0.0
var fov_target: float = 75.0
var camera_mode: bool = true
var timestamp: int = 0
var sequence: int = 0
var is_valid: bool = true

func to_dictionary() -> Dictionary:
	return {
		"ts": timestamp,
		"seq": sequence,
		"pitch": look_pitch,
		"yaw": look_yaw,
		"iyaw": intended_yaw,
		"origin_x": aim_origin.x,
		"origin_y": aim_origin.y,
		"origin_z": aim_origin.z,
		"eye_x": eye_position.x,
		"eye_y": eye_position.y,
		"eye_z": eye_position.z,
		"dir_x": aim_direction.x,
		"dir_y": aim_direction.y,
		"dir_z": aim_direction.z,
		"ads": ads_weight,
		"aim_w": aim_orientation_weight,
		"fov": fov_target,
		"mode": camera_mode,
	}

static func from_dictionary(d: Dictionary) -> AimState:
	var s := AimState.new()
	s.timestamp = d.get("ts", 0)
	s.sequence = d.get("seq", 0)
	s.look_pitch = d.get("pitch", 0.0)
	s.look_yaw = d.get("yaw", 0.0)
	s.intended_yaw = d.get("iyaw", s.look_yaw)
	s.aim_origin = Vector3(
		d.get("origin_x", 0.0),
		d.get("origin_y", 0.0),
		d.get("origin_z", 0.0)
	)
	s.eye_position = Vector3(
		d.get("eye_x", 0.0),
		d.get("eye_y", 0.0),
		d.get("eye_z", 0.0)
	)
	s.aim_direction = Vector3(
		d.get("dir_x", 0.0),
		d.get("dir_y", 0.0),
		d.get("dir_z", 0.0)
	).normalized()
	s.ads_weight = d.get("ads", 0.0)
	s.aim_orientation_weight = d.get("aim_w", 0.0)
	s.fov_target = d.get("fov", 75.0)
	s.camera_mode = d.get("mode", true)
	s.aim_target_point = s.aim_origin + s.aim_direction * 1000.0
	s.is_valid = true
	return s