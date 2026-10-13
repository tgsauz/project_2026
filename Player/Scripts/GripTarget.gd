extends RefCounted
class_name GripTarget

# ============================================================
# GRIP TARGET
# Abstract hand-positioning data for FullBodyIKController.
# Produced each frame by WeaponController from WeaponRoot × grip markers.
# Consumed by FullBodyIKController — never references WeaponRoot directly.
# ============================================================

var right_hand_position: Vector3 = Vector3.ZERO
var right_hand_rotation: Quaternion = Quaternion.IDENTITY
var left_hand_position: Vector3 = Vector3.ZERO
var left_hand_rotation: Quaternion = Quaternion.IDENTITY

# Per-hand validity. A weapon may expose only one grip marker, so each hand's
# target is independent and the IK weights each arm separately.
var right_hand_valid: bool = false
var left_hand_valid: bool = false

# Derived: true when at least one hand has a valid target.
var is_valid: bool:
	get:
		return right_hand_valid or left_hand_valid

func set_right_hand(pos: Vector3, rot: Quaternion) -> void:
	right_hand_position = pos
	right_hand_rotation = rot
	right_hand_valid = true

func set_left_hand(pos: Vector3, rot: Quaternion) -> void:
	left_hand_position = pos
	left_hand_rotation = rot
	left_hand_valid = true
