extends RefCounted
class_name AimState

# ============================================================
# AIM STATE
# Immutable data structure — single source of truth for aiming intent.
# Produced by AimController each frame.
# Consumed by CameraController, CharacterController, SpineLookAtController.
# (WeaponController does NOT read it: the weapon reads
# only the support bone. There is no AI or network consumer in this repo.)
#
# ============================================================

var look_pitch: float = 0.0
var look_yaw: float = 0.0
var intended_yaw: float = 0.0
var aim_origin: Vector3 = Vector3.ZERO
var eye_position: Vector3 = Vector3.ZERO
var aim_direction: Vector3 = Vector3.FORWARD
var fov_target: float = 75.0
var camera_mode: bool = true
var timestamp: int = 0
var sequence: int = 0
var is_valid: bool = true
