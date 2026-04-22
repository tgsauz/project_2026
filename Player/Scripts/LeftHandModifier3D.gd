extends SkeletonModifier3D
class_name LeftHandModifier3D

signal debug_snapshot_emitted(snapshot: Dictionary)

const MIN_BLEND_WEIGHT: float = 0.001
const MIN_AXIS_LENGTH_SQUARED: float = 0.0001
const MIN_REACH_EPSILON: float = 0.001
const DEFAULT_DEBUG_INTERVAL_SECONDS: float = 0.75

const DEBUG_MODE_OFF: String = "off"
const DEBUG_MODE_BASIC: String = "basic"
const DEBUG_MODE_FULL: String = "full"

var target_node: Node3D
var target_rotation_offset: Vector3 = Vector3.ZERO
var target_position_offset: Vector3 = Vector3.ZERO
var blend_weight: float = 0.0

var debug_mode: String = DEBUG_MODE_OFF
var debug_draw_gizmos: bool = false
var debug_log_snapshots: bool = false
var debug_capture_once: bool = false
var debug_compare_tag: String = ""
var debug_log_interval_seconds: float = DEFAULT_DEBUG_INTERVAL_SECONDS

var enable_soft_reach_clamp: bool = true
var soft_reach_buffer: float = 0.08
var enable_clavicle_assist: bool = false
var clavicle_assist_max_degrees: float = 12.0
var clavicle_assist_full_overstretch: float = 0.18

var shoulder_idx: int = -1
var elbow_idx: int = -1
var wrist_idx: int = -1
var clavicle_idx: int = -1

var latest_debug_snapshot: Dictionary = {}

var _is_blending_in: bool = false
var _snapshot_offset_pos: Vector3 = Vector3.ZERO
var _snapshot_offset_q: Quaternion = Quaternion()
var _debug_time_accumulator: float = 0.0

func setup(root_bone: String, tip_bone: String, clavicle_bone: String = "") -> bool:
	var skel: Skeleton3D = get_skeleton()
	if skel == null:
		return false

	shoulder_idx = skel.find_bone(root_bone)
	wrist_idx = skel.find_bone(tip_bone)
	clavicle_idx = -1

	if shoulder_idx == -1 or wrist_idx == -1:
		return false

	var wrist_parent_idx: int = skel.get_bone_parent(wrist_idx)
	if wrist_parent_idx == -1:
		push_warning("LeftHandModifier3D: Wrist bone '%s' has no parent; cannot build Two-Bone IK chain." % tip_bone)
		return false

	elbow_idx = wrist_parent_idx

	var elbow_parent_idx: int = skel.get_bone_parent(elbow_idx)
	if elbow_parent_idx != shoulder_idx:
		push_warning("LeftHandModifier3D: Expected Two-Bone chain %s -> %s -> %s, but '%s' parent is '%s'." % [
			root_bone,
			skel.get_bone_name(elbow_idx),
			tip_bone,
			skel.get_bone_name(elbow_idx),
			skel.get_bone_name(elbow_parent_idx) if elbow_parent_idx != -1 else "<none>"
		])
		return false

	if not clavicle_bone.is_empty():
		var resolved_clavicle_idx: int = skel.find_bone(clavicle_bone)
		if resolved_clavicle_idx == -1:
			push_warning("LeftHandModifier3D: Clavicle bone '%s' not found. Clavicle assist disabled." % clavicle_bone)
		elif resolved_clavicle_idx == shoulder_idx:
			push_warning("LeftHandModifier3D: Clavicle bone '%s' matches shoulder root. Clavicle assist disabled." % clavicle_bone)
		elif skel.get_bone_parent(shoulder_idx) != resolved_clavicle_idx:
			push_warning("LeftHandModifier3D: Clavicle bone '%s' is not parent of shoulder bone '%s'. Clavicle assist disabled." % [
				clavicle_bone,
				root_bone
			])
		else:
			clavicle_idx = resolved_clavicle_idx

	return true

func reset_blend_state() -> void:
	_is_blending_in = false
	_snapshot_offset_pos = Vector3.ZERO
	_snapshot_offset_q = Quaternion()
	_debug_time_accumulator = 0.0

func request_debug_snapshot(compare_tag: String = "") -> void:
	debug_capture_once = true
	debug_compare_tag = compare_tag

func _process_modification() -> void:
	if blend_weight <= MIN_BLEND_WEIGHT:
		reset_blend_state()
		return

	var skel: Skeleton3D = get_skeleton()
	if skel == null or shoulder_idx == -1 or elbow_idx == -1 or wrist_idx == -1:
		return

	if target_node == null or not is_instance_valid(target_node):
		reset_blend_state()
		return

	var should_emit_snapshot: bool = _should_emit_debug_snapshot()
	var should_log_snapshot: bool = _should_log_snapshot()
	var capture_tag: String = debug_compare_tag
	var target_info: Dictionary = _resolve_target_info(skel)
	var target_transform: Transform3D = target_info.get("transform", Transform3D.IDENTITY) as Transform3D

	var shoulder_pose: Transform3D = skel.get_bone_global_pose(shoulder_idx)
	var elbow_pose: Transform3D = skel.get_bone_global_pose(elbow_idx)
	var wrist_pose: Transform3D = skel.get_bone_global_pose(wrist_idx)

	var target_rotation: Quaternion = Quaternion(target_transform.basis.orthonormalized())
	if not _is_blending_in:
		_is_blending_in = true
		_capture_snapshot(target_transform, target_rotation, wrist_pose)

	var virtual_target: Transform3D = _build_virtual_target(target_transform, target_rotation, wrist_pose)

	if enable_clavicle_assist and clavicle_idx != -1:
		var clavicle_adjusted: Dictionary = _apply_clavicle_assist(
			skel,
			shoulder_pose,
			elbow_pose,
			wrist_pose,
			virtual_target.origin
		)
		shoulder_pose = clavicle_adjusted["shoulder_pose"] as Transform3D
		elbow_pose = clavicle_adjusted["elbow_pose"] as Transform3D
		wrist_pose = clavicle_adjusted["wrist_pose"] as Transform3D

	var solve_data: Dictionary = _build_solve_data(shoulder_pose, elbow_pose, wrist_pose, virtual_target.origin)
	var solve_target: Vector3 = solve_data["target"] as Vector3
	var raw_target_distance: float = float(solve_data["raw_target_distance"])
	var clamped_target_distance: float = float(solve_data["clamped_target_distance"])
	var max_reach: float = float(solve_data["max_reach"])
	var upper_length: float = float(solve_data["upper_length"])
	var lower_length: float = float(solve_data["lower_length"])

	var shoulder_origin: Vector3 = shoulder_pose.origin
	var elbow_origin: Vector3 = elbow_pose.origin
	var wrist_origin: Vector3 = wrist_pose.origin
	var shoulder_local_to_elbow: Vector3 = shoulder_pose.affine_inverse() * elbow_origin
	var elbow_local_to_wrist: Vector3 = elbow_pose.affine_inverse() * wrist_origin

	var shoulder_to_wrist: Vector3 = (wrist_origin - shoulder_origin).normalized()
	var shoulder_to_target: Vector3 = (solve_target - shoulder_origin).normalized()

	var swing_rotation: Quaternion = _get_rotation_between(shoulder_to_wrist, shoulder_to_target)
	var swung_elbow_origin: Vector3 = shoulder_origin + swing_rotation * (elbow_origin - shoulder_origin)

	var arm_direction: Vector3 = shoulder_to_target
	var elbow_direction: Vector3 = (swung_elbow_origin - shoulder_origin).normalized()
	var pole_direction: Vector3 = elbow_direction - arm_direction * arm_direction.dot(elbow_direction)
	if pole_direction.length_squared() < MIN_AXIS_LENGTH_SQUARED:
		pole_direction = Vector3.UP - arm_direction * arm_direction.dot(Vector3.UP)
		if pole_direction.length_squared() < MIN_AXIS_LENGTH_SQUARED:
			pole_direction = Vector3.RIGHT - arm_direction * arm_direction.dot(Vector3.RIGHT)
	pole_direction = pole_direction.normalized()
	var hinge_axis: Vector3 = arm_direction.cross(pole_direction).normalized()

	var cos_alpha: float = (upper_length * upper_length + clamped_target_distance * clamped_target_distance - lower_length * lower_length) / (2.0 * upper_length * clamped_target_distance)
	var required_alpha: float = acos(clampf(cos_alpha, -1.0, 1.0))
	var current_alpha: float = arm_direction.angle_to(elbow_direction)
	var shoulder_projection: float = (upper_length * upper_length - lower_length * lower_length + clamped_target_distance * clamped_target_distance) / (2.0 * clamped_target_distance)
	var pole_height_squared: float = maxf(upper_length * upper_length - shoulder_projection * shoulder_projection, 0.0)
	var pole_height: float = sqrt(pole_height_squared)
	var final_elbow_origin: Vector3 = shoulder_origin + arm_direction * shoulder_projection + pole_direction * pole_height
	var final_upper_direction: Vector3 = (final_elbow_origin - shoulder_origin).normalized()

	shoulder_pose.basis = _align_basis_to_direction(shoulder_pose.basis, shoulder_local_to_elbow, final_upper_direction)
	skel.set_bone_global_pose(shoulder_idx, shoulder_pose)

	var elbow_after_shoulder_pose: Transform3D = skel.get_bone_global_pose(elbow_idx)
	var wrist_after_shoulder_pose: Transform3D = skel.get_bone_global_pose(wrist_idx)
	var actual_elbow_after_shoulder: Vector3 = elbow_after_shoulder_pose.origin
	var final_lower_direction: Vector3 = (solve_target - final_elbow_origin).normalized()

	elbow_after_shoulder_pose.basis = _align_basis_to_direction(elbow_after_shoulder_pose.basis, elbow_local_to_wrist, final_lower_direction)
	skel.set_bone_global_pose(elbow_idx, elbow_after_shoulder_pose)

	var final_elbow_pose: Transform3D = skel.get_bone_global_pose(elbow_idx)
	var final_wrist_pose: Transform3D = skel.get_bone_global_pose(wrist_idx)
	final_wrist_pose.basis = virtual_target.basis
	skel.set_bone_global_pose(wrist_idx, final_wrist_pose)

	var actual_elbow_after_elbow: Vector3 = final_elbow_pose.origin
	var final_wrist_origin: Vector3 = final_wrist_pose.origin
	var wrist_error_vector: Vector3 = virtual_target.origin - final_wrist_origin
	var wrist_error_distance: float = wrist_error_vector.length()
	var lower_chain_actual_direction: Vector3 = (final_wrist_origin - actual_elbow_after_elbow).normalized()
	var lower_chain_desired_direction: Vector3 = (solve_target - final_elbow_origin).normalized()
	var lower_chain_angle_error: float = lower_chain_actual_direction.angle_to(lower_chain_desired_direction)
	var lower_chain_local_after_elbow: Vector3 = final_elbow_pose.affine_inverse() * final_wrist_origin

	if should_emit_snapshot:
		var snapshot: Dictionary = _build_debug_snapshot(
			target_info,
			target_transform,
			virtual_target,
			capture_tag,
			should_log_snapshot,
			shoulder_pose,
			elbow_pose,
			wrist_pose,
			upper_length,
			lower_length,
			raw_target_distance,
			clamped_target_distance,
			max_reach,
			solve_target,
			elbow_origin,
			swung_elbow_origin,
			final_elbow_origin,
			actual_elbow_after_shoulder,
			actual_elbow_after_elbow,
			wrist_after_shoulder_pose,
			hinge_axis,
			current_alpha,
			required_alpha,
			final_wrist_pose,
			wrist_error_distance,
			wrist_error_vector,
			elbow_local_to_wrist,
			lower_chain_local_after_elbow,
			lower_chain_actual_direction,
			lower_chain_desired_direction,
			lower_chain_angle_error
		)
		latest_debug_snapshot = snapshot
		debug_snapshot_emitted.emit(snapshot)

	if debug_capture_once:
		debug_capture_once = false
		debug_compare_tag = ""

func _resolve_target_info(skel: Skeleton3D) -> Dictionary:
	if target_node == null or not is_instance_valid(target_node):
		return {
			"transform": Transform3D.IDENTITY,
			"target_source": "invalid_target",
			"target_node_path": "",
			"attachment_node_path": "",
			"attachment_bone_name": "",
			"composition_order": PackedStringArray(["invalid_target"])
		}

	var skeleton_inverse: Transform3D = skel.global_transform.affine_inverse()
	var local_offset: Transform3D = Transform3D.IDENTITY
	var current: Node3D = target_node
	var found_attachment: BoneAttachment3D = null

	while current != null and current != skel:
		if current is BoneAttachment3D:
			found_attachment = current as BoneAttachment3D
			break
		local_offset = current.transform * local_offset
		current = current.get_parent() as Node3D

	var target_transform: Transform3D
	var target_source: String = "global_target"
	var attachment_node_path: String = ""
	var attachment_bone_name: String = ""
	var composition_order: PackedStringArray = PackedStringArray()

	if found_attachment != null:
		attachment_node_path = str(found_attachment.get_path())
		attachment_bone_name = found_attachment.bone_name
		var target_bone_idx: int = skel.find_bone(found_attachment.bone_name)
		if target_bone_idx != -1:
			target_transform = skel.get_bone_global_pose(target_bone_idx) * local_offset
			target_source = "bone_attachment_pose"
			composition_order.append("bone_global_pose")
			composition_order.append("attachment_local_offset")
		else:
			target_transform = skeleton_inverse * target_node.global_transform
			target_source = "attachment_fallback_global"
			composition_order.append("fallback_global_transform")
	else:
		target_transform = skeleton_inverse * target_node.global_transform
		composition_order.append("global_transform")

	if target_rotation_offset != Vector3.ZERO:
		var offset_basis: Basis = Basis.from_euler(Vector3(
			deg_to_rad(target_rotation_offset.x),
			deg_to_rad(target_rotation_offset.y),
			deg_to_rad(target_rotation_offset.z)
		))
		target_transform.basis = target_transform.basis * offset_basis
		composition_order.append("rotation_offset")

	if target_position_offset != Vector3.ZERO:
		target_transform.origin += target_transform.basis * target_position_offset
		composition_order.append("position_offset")

	target_transform.basis = target_transform.basis.orthonormalized()
	return {
		"transform": target_transform,
		"target_source": target_source,
		"target_node_path": str(target_node.get_path()),
		"attachment_node_path": attachment_node_path,
		"attachment_bone_name": attachment_bone_name,
		"composition_order": composition_order
	}

func _capture_snapshot(target_transform: Transform3D, target_rotation: Quaternion, wrist_pose: Transform3D) -> void:
	var inverse_target: Transform3D = target_transform.affine_inverse()
	_snapshot_offset_pos = inverse_target * wrist_pose.origin

	var wrist_rotation: Quaternion = Quaternion(wrist_pose.basis.orthonormalized())
	_snapshot_offset_q = target_rotation.inverse() * wrist_rotation

func _build_virtual_target(target_transform: Transform3D, target_rotation: Quaternion, wrist_pose: Transform3D) -> Transform3D:
	var current_offset_pos: Vector3 = Vector3.ZERO
	var current_offset_q: Quaternion = Quaternion()

	if blend_weight < 0.999:
		current_offset_pos = _snapshot_offset_pos.lerp(Vector3.ZERO, blend_weight)
		current_offset_q = _snapshot_offset_q.slerp(Quaternion(), blend_weight)

	var virtual_target_rotation: Quaternion = target_rotation * current_offset_q
	var virtual_target_origin: Vector3 = target_transform * current_offset_pos
	var wrist_scale: Vector3 = wrist_pose.basis.get_scale()
	var virtual_target_basis: Basis = Basis(virtual_target_rotation).scaled(wrist_scale)

	return Transform3D(virtual_target_basis, virtual_target_origin)

func _apply_clavicle_assist(
	skel: Skeleton3D,
	shoulder_pose: Transform3D,
	elbow_pose: Transform3D,
	wrist_pose: Transform3D,
	target_position: Vector3
) -> Dictionary:
	var clavicle_pose: Transform3D = skel.get_bone_global_pose(clavicle_idx)
	var current_reach: float = shoulder_pose.origin.distance_to(target_position)
	var max_reach: float = shoulder_pose.origin.distance_to(elbow_pose.origin) + elbow_pose.origin.distance_to(wrist_pose.origin)
	var overstretch: float = maxf(0.0, current_reach - max_reach)
	if overstretch <= 0.0:
		return {
			"shoulder_pose": shoulder_pose,
			"elbow_pose": elbow_pose,
			"wrist_pose": wrist_pose
		}

	var shoulder_from_clavicle: Vector3 = shoulder_pose.origin - clavicle_pose.origin
	var target_from_clavicle: Vector3 = target_position - clavicle_pose.origin
	if shoulder_from_clavicle.length_squared() < MIN_AXIS_LENGTH_SQUARED or target_from_clavicle.length_squared() < MIN_AXIS_LENGTH_SQUARED:
		return {
			"shoulder_pose": shoulder_pose,
			"elbow_pose": elbow_pose,
			"wrist_pose": wrist_pose
		}

	var desired_rotation: Quaternion = _get_rotation_between(shoulder_from_clavicle.normalized(), target_from_clavicle.normalized())
	var rotation_angle: float = desired_rotation.get_angle()
	var rotation_axis: Vector3 = desired_rotation.get_axis()
	if rotation_angle <= 0.0 or rotation_axis.length_squared() < MIN_AXIS_LENGTH_SQUARED:
		return {
			"shoulder_pose": shoulder_pose,
			"elbow_pose": elbow_pose,
			"wrist_pose": wrist_pose
		}

	var assist_ratio: float = clampf(overstretch / maxf(clavicle_assist_full_overstretch, MIN_REACH_EPSILON), 0.0, 1.0)
	var assist_angle: float = minf(rotation_angle, deg_to_rad(clavicle_assist_max_degrees)) * assist_ratio
	if assist_angle <= 0.0:
		return {
			"shoulder_pose": shoulder_pose,
			"elbow_pose": elbow_pose,
			"wrist_pose": wrist_pose
		}

	var assist_rotation: Quaternion = Quaternion(rotation_axis.normalized(), assist_angle)
	clavicle_pose.basis = Basis(assist_rotation) * clavicle_pose.basis
	skel.set_bone_global_pose(clavicle_idx, clavicle_pose)

	return {
		"shoulder_pose": skel.get_bone_global_pose(shoulder_idx),
		"elbow_pose": skel.get_bone_global_pose(elbow_idx),
		"wrist_pose": skel.get_bone_global_pose(wrist_idx)
	}

func _build_solve_data(shoulder_pose: Transform3D, elbow_pose: Transform3D, wrist_pose: Transform3D, target_position: Vector3) -> Dictionary:
	var shoulder_origin: Vector3 = shoulder_pose.origin
	var upper_length: float = shoulder_origin.distance_to(elbow_pose.origin)
	var lower_length: float = elbow_pose.origin.distance_to(wrist_pose.origin)
	var max_reach: float = upper_length + lower_length - MIN_REACH_EPSILON
	var raw_target_distance: float = shoulder_origin.distance_to(target_position)
	var clamped_target_distance: float = clampf(raw_target_distance, MIN_REACH_EPSILON, max_reach)
	var solve_target: Vector3 = target_position

	if enable_soft_reach_clamp and raw_target_distance > max_reach:
		var overstretch: float = raw_target_distance - max_reach
		var clamp_range: float = maxf(soft_reach_buffer, MIN_REACH_EPSILON)
		var compression_ratio: float = clampf(overstretch / clamp_range, 0.0, 1.0)
		var allowed_overstretch: float = lerpf(overstretch, 0.0, compression_ratio)
		clamped_target_distance = minf(raw_target_distance, max_reach + allowed_overstretch)

	if raw_target_distance > MIN_REACH_EPSILON and clamped_target_distance < raw_target_distance - 0.0001:
		solve_target = shoulder_origin + (target_position - shoulder_origin).normalized() * clamped_target_distance

	return {
		"target": solve_target,
		"raw_target_distance": raw_target_distance,
		"clamped_target_distance": clamped_target_distance,
		"max_reach": max_reach,
		"upper_length": upper_length,
		"lower_length": lower_length
	}

func _align_basis_to_direction(current_basis: Basis, local_child_offset: Vector3, desired_global_direction: Vector3) -> Basis:
	if local_child_offset.length_squared() < MIN_AXIS_LENGTH_SQUARED or desired_global_direction.length_squared() < MIN_AXIS_LENGTH_SQUARED:
		return current_basis

	var current_child_direction: Vector3 = (current_basis * local_child_offset).normalized()
	var desired_direction: Vector3 = desired_global_direction.normalized()
	var correction: Quaternion = _get_rotation_between(current_child_direction, desired_direction)
	if correction.is_equal_approx(Quaternion()):
		return current_basis
	return Basis(correction) * current_basis

func _build_debug_snapshot(
	target_info: Dictionary,
	target_transform: Transform3D,
	virtual_target: Transform3D,
	capture_tag: String,
	should_log_snapshot: bool,
	shoulder_pose: Transform3D,
	elbow_pose: Transform3D,
	wrist_pose: Transform3D,
	upper_length: float,
	lower_length: float,
	raw_target_distance: float,
	clamped_target_distance: float,
	max_reach: float,
	solve_target: Vector3,
	elbow_origin: Vector3,
	swung_elbow_origin: Vector3,
	final_elbow_origin: Vector3,
	actual_elbow_after_shoulder: Vector3,
	actual_elbow_after_elbow: Vector3,
	wrist_after_shoulder_pose: Transform3D,
	hinge_axis: Vector3,
	current_alpha: float,
	required_alpha: float,
	final_wrist_pose: Transform3D,
	wrist_error_distance: float,
	wrist_error_vector: Vector3,
	elbow_local_to_wrist_before: Vector3,
	elbow_local_to_wrist_after: Vector3,
	lower_chain_actual_direction: Vector3,
	lower_chain_desired_direction: Vector3,
	lower_chain_angle_error: float
) -> Dictionary:
	var snapshot: Dictionary = {
		"tag": capture_tag,
		"frame": Engine.get_process_frames(),
		"debug": {
			"mode": debug_mode,
			"should_log": should_log_snapshot,
			"draw_gizmos": debug_draw_gizmos,
			"log_snapshots": debug_log_snapshots,
			"capture_once": debug_capture_once
		},
		"motion_context": {
			"blend_weight": blend_weight,
			"is_blending_in": _is_blending_in,
			"snapshot_offset_position": _snapshot_offset_pos,
			"snapshot_offset_rotation": _snapshot_offset_q
		},
		"target_space": {
			"target_source": str(target_info.get("target_source", "unknown")),
			"target_node_path": str(target_info.get("target_node_path", "")),
			"attachment_node_path": str(target_info.get("attachment_node_path", "")),
			"attachment_bone_name": str(target_info.get("attachment_bone_name", "")),
			"composition_order": target_info.get("composition_order", PackedStringArray()),
			"resolved_target_transform": target_transform,
			"resolved_target_basis_euler_degrees": _basis_to_degrees(target_transform.basis),
			"virtual_target_transform": virtual_target,
			"virtual_target_basis_euler_degrees": _basis_to_degrees(virtual_target.basis),
			"applied_rotation_offset": target_rotation_offset,
			"applied_position_offset": target_position_offset
		},
		"solver_inputs": {
			"shoulder_pose": shoulder_pose,
			"elbow_pose": elbow_pose,
			"wrist_pose": wrist_pose,
			"clavicle_pose": get_skeleton().get_bone_global_pose(clavicle_idx) if clavicle_idx != -1 else Transform3D.IDENTITY,
			"upper_length": upper_length,
			"lower_length": lower_length,
			"raw_target_distance": raw_target_distance,
			"clamped_target_distance": clamped_target_distance,
			"max_reach": max_reach,
			"solve_target": solve_target
		},
		"solver_stages": {
			"elbow_original": elbow_origin,
			"elbow_swung": swung_elbow_origin,
			"elbow_solved": final_elbow_origin,
			"elbow_after_shoulder": actual_elbow_after_shoulder,
			"elbow_after_elbow": actual_elbow_after_elbow,
			"wrist_after_shoulder_pose": wrist_after_shoulder_pose,
			"final_wrist_pose": final_wrist_pose,
			"elbow_local_to_wrist_before": elbow_local_to_wrist_before,
			"elbow_local_to_wrist_after": elbow_local_to_wrist_after,
			"lower_chain_actual_direction": lower_chain_actual_direction,
			"lower_chain_desired_direction": lower_chain_desired_direction,
			"lower_chain_angle_error_radians": lower_chain_angle_error,
			"lower_chain_angle_error_degrees": rad_to_deg(lower_chain_angle_error),
			"hinge_axis": hinge_axis,
			"current_alpha": current_alpha,
			"required_alpha": required_alpha
		},
		"error_metrics": {
			"wrist_error_distance": wrist_error_distance,
			"wrist_error_vector": wrist_error_vector,
			"elbow_solved_delta": actual_elbow_after_elbow - final_elbow_origin,
			"target_minus_final_wrist": virtual_target.origin - final_wrist_pose.origin
		}
	}
	return snapshot

func _should_emit_debug_snapshot() -> bool:
	return debug_mode != DEBUG_MODE_OFF and (debug_draw_gizmos or debug_log_snapshots or debug_capture_once)

func _should_log_snapshot() -> bool:
	if debug_mode == DEBUG_MODE_OFF:
		return false
	if debug_capture_once:
		return true
	if not debug_log_snapshots:
		return false
	_debug_time_accumulator += get_process_delta_time()
	if _debug_time_accumulator < maxf(0.05, debug_log_interval_seconds):
		return false
	_debug_time_accumulator = 0.0
	return true

func _basis_to_degrees(basis: Basis) -> Vector3:
	var euler_radians: Vector3 = basis.orthonormalized().get_euler()
	return Vector3(
		rad_to_deg(euler_radians.x),
		rad_to_deg(euler_radians.y),
		rad_to_deg(euler_radians.z)
	)

func _get_bone_name_or_none(bone_idx: int) -> String:
	var skel: Skeleton3D = get_skeleton()
	if skel == null or bone_idx == -1:
		return "<none>"
	return skel.get_bone_name(bone_idx)

func _get_rotation_between(from_dir: Vector3, to_dir: Vector3) -> Quaternion:
	var safe_from: Vector3 = from_dir.normalized()
	var safe_to: Vector3 = to_dir.normalized()
	var axis: Vector3 = safe_from.cross(safe_to)
	var angle: float = safe_from.angle_to(safe_to)
	if axis.length_squared() < MIN_AXIS_LENGTH_SQUARED or is_zero_approx(angle):
		return Quaternion()
	return Quaternion(axis.normalized(), angle)
