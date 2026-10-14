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
var aim_orientation_weight: float = 0.0
var fov_target: float = 75.0
var camera_mode: bool = true
var timestamp: int = 0
var sequence: int = 0
var is_valid: bool = true
