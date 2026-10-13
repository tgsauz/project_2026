extends WeaponLayerBase
class_name WeaponLayerSocketPositionTest

## TEST-ONLY layer: applies the animated ik_hand_gun transform directly.
## No grip compensation, roll removal, or basis reconstruction is performed.

func _init(skeleton: Skeleton3D) -> void:
	super(skeleton)

func apply(_current: Transform3D, _state: AimState, _delta: float) -> Transform3D:
	if _skeleton == null or _gun_bone_idx < 0:
		return _current

	# Preserve the socket's complete transform as authored/evaluated by the rig.
	# Do not orthonormalize, remove roll, or shift the origin to a grip marker.
	var socket_pose: Transform3D = _skeleton.get_bone_global_pose(_gun_bone_idx)
	return _skeleton.global_transform * socket_pose
