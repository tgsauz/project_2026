extends Node
class_name LeftHandIKComponent

const DEBUG_MODE_OFF: String = "off"
const DEBUG_MODE_BASIC: String = "basic"
const DEBUG_MODE_FULL: String = "full"
const DEBUG_HISTORY_LIMIT: int = 6

@export_category("Binding")
@export var source_slot_name: String = "right_hand"
@export var grip_node_name: String = "LGRIP"
@export var handle_node_name: String = "Handle"

@export_category("Bones")
@export var root_bone_candidates: PackedStringArray = PackedStringArray(["upperarm_l", "arm_l", "shoulder_l", "clavicle_l"])
@export var tip_bone_candidates: PackedStringArray = PackedStringArray(["hand_l", "LeftHand"])
@export var clavicle_bone_candidates: PackedStringArray = PackedStringArray(["clavicle_l", "shoulder_l"])

@export_category("Blend")
@export var ik_in_speed: float = 10.0
@export var ik_out_speed: float = 12.0
@export var stop_threshold: float = 0.02

@export_category("Offsets")
@export var hand_position_offset: Vector3 = Vector3.ZERO
@export var hand_rotation_offset: Vector3 = Vector3.ZERO

@export_category("Diagnostics")
@export_enum("off", "basic", "full") var debug_mode: String = DEBUG_MODE_OFF
@export var debug_draw_gizmos: bool = false
@export var debug_log_snapshots: bool = false
@export var debug_compare_tag: String = ""

@export_category("Reach")
@export var enable_soft_reach_clamp: bool = true
@export_range(0.0, 0.5, 0.01) var soft_reach_buffer: float = 0.08
@export var enable_clavicle_assist: bool = true
@export_range(0.0, 45.0, 0.5) var clavicle_assist_max_degrees: float = 12.0
@export_range(0.01, 0.5, 0.01) var clavicle_assist_full_overstretch: float = 0.18

var visuals_component: VisualsComponent
var skeleton: Skeleton3D
var ik_node: LeftHandModifier3D
var grip_target: Node3D
var _active_weapon_visual: Node3D
var _debug_gizmo_root: LeftHandIKDebugGizmo3D

var _current_weight: float = 0.0
var _desired_weight: float = 0.0
var _pending_debug_capture: bool = false
var _debug_snapshot_history: Array[Dictionary] = []
var _debug_snapshots_by_tag: Dictionary = {}

func _ready() -> void:
	process_priority = 100
	set_process(true)
	call_deferred("_initialize_component")

func _process(delta: float) -> void:
	if ik_node == null:
		return

	_sync_debug_settings()
	_update_target_transform()
	_update_blend(delta)
	_update_debug_gizmos_visibility()

func _initialize_component() -> void:
	visuals_component = get_parent() as VisualsComponent
	if visuals_component == null:
		push_warning("LeftHandIKComponent expects a VisualsComponent parent.")
		return

	skeleton = visuals_component.skeleton
	if skeleton == null:
		push_warning("LeftHandIKComponent could not resolve the runtime skeleton from VisualsComponent.")
		return

	if not _ensure_runtime_nodes():
		return

	if not visuals_component.equipped_visual_attached.is_connected(_on_equipped_visual_attached):
		visuals_component.equipped_visual_attached.connect(_on_equipped_visual_attached)
	if not visuals_component.equipped_visual_detached.is_connected(_on_equipped_visual_detached):
		visuals_component.equipped_visual_detached.connect(_on_equipped_visual_detached)

	_sync_from_current_visual()

func capture_debug_snapshot(compare_tag: String = "") -> void:
	_pending_debug_capture = true
	debug_compare_tag = compare_tag
	if ik_node != null:
		ik_node.request_debug_snapshot(compare_tag)

func _ensure_runtime_nodes() -> bool:
	var root_bone_name: String = _resolve_first_existing_bone(root_bone_candidates)
	var tip_bone_name: String = _resolve_first_existing_bone(tip_bone_candidates)
	if root_bone_name.is_empty() or tip_bone_name.is_empty():
		push_warning("LeftHandIKComponent: could not resolve a valid left-arm bone chain. Checked root candidates: %s | tip candidates: %s" % [str(root_bone_candidates), str(tip_bone_candidates)])
		return false

	var root_idx: int = skeleton.find_bone(root_bone_name)
	var tip_idx: int = skeleton.find_bone(tip_bone_name)
	if not _is_bone_ancestor(root_idx, tip_idx):
		push_warning("LeftHandIKComponent: bone chain invalid. '%s' must be an ancestor of '%s'." % [root_bone_name, tip_bone_name])
		return false

	ik_node = skeleton.get_node_or_null("LeftHandModifier") as LeftHandModifier3D
	if ik_node == null:
		ik_node = LeftHandModifier3D.new()
		ik_node.name = "LeftHandModifier"
		skeleton.add_child(ik_node)

	var clavicle_bone_name: String = _resolve_optional_clavicle_bone(root_idx)
	if not ik_node.setup(root_bone_name, tip_bone_name, clavicle_bone_name):
		push_warning("LeftHandIKComponent: LeftHandModifier3D setup failed. Check bone names.")
		return false

	if not ik_node.debug_snapshot_emitted.is_connected(_on_modifier_debug_snapshot_emitted):
		ik_node.debug_snapshot_emitted.connect(_on_modifier_debug_snapshot_emitted)

	_ensure_debug_gizmo_root()
	_sync_debug_settings()
	ik_node.blend_weight = 0.0
	ik_node.reset_blend_state()
	ik_node.active = true
	return true

func _sync_from_current_visual() -> void:
	if visuals_component == null:
		return

	var entry: Dictionary = visuals_component.get_active_visual_entry(source_slot_name)
	if entry.is_empty():
		_clear_grip_target()
		return

	var item_id: String = str(entry.get("item_id", ""))
	var visual: Node3D = visuals_component.get_active_visual(source_slot_name, item_id) as Node3D
	_try_bind_weapon_visual(visual, entry)

func _on_equipped_visual_attached(slot_name: String, _item_id: String, visual: Node3D, entry: Dictionary) -> void:
	if slot_name != source_slot_name:
		return
	_try_bind_weapon_visual(visual, entry)

func _on_equipped_visual_detached(slot_name: String, _item_id: String) -> void:
	if slot_name != source_slot_name:
		return
	_sync_from_current_visual()

func _try_bind_weapon_visual(visual: Node3D, entry: Dictionary) -> void:
	if visual == null or not is_instance_valid(visual):
		_clear_grip_target()
		return

	var definition: ItemDefinition = entry.get("definition", null) as ItemDefinition
	if definition == null or definition.category != ItemDefinition.CATEGORY_WEAPON:
		_clear_grip_target()
		return

	var resolved_grip: Node3D = visual.find_child(grip_node_name, true, false) as Node3D
	if resolved_grip == null:
		push_warning("LeftHandIKComponent could not find grip node '%s' on '%s'." % [grip_node_name, visual.name])
		_clear_grip_target()
		return

	_active_weapon_visual = visual
	grip_target = resolved_grip
	_desired_weight = 1.0
	if ik_node != null:
		ik_node.reset_blend_state()

func _clear_grip_target() -> void:
	grip_target = null
	_active_weapon_visual = null
	_desired_weight = 0.0
	if ik_node != null:
		ik_node.target_node = null
		ik_node.reset_blend_state()
	if _debug_gizmo_root != null:
		_debug_gizmo_root.set_gizmos_enabled(false)

func _update_target_transform() -> void:
	if grip_target == null:
		return
	if not is_instance_valid(grip_target):
		_clear_grip_target()
		return

	if ik_node != null:
		ik_node.target_node = grip_target
		ik_node.target_rotation_offset = hand_rotation_offset
		ik_node.target_position_offset = hand_position_offset
		if _pending_debug_capture:
			ik_node.request_debug_snapshot(debug_compare_tag)
			_pending_debug_capture = false

func _update_blend(delta: float) -> void:
	var blend_speed: float = ik_in_speed if _desired_weight >= _current_weight else ik_out_speed
	_current_weight = lerp(_current_weight, _desired_weight, 1.0 - exp(-blend_speed * delta))

	if abs(_current_weight - _desired_weight) < 0.001:
		_current_weight = _desired_weight

	if ik_node != null:
		ik_node.blend_weight = _current_weight
		ik_node.active = _current_weight > 0.001

func _sync_debug_settings() -> void:
	if ik_node == null:
		return

	ik_node.debug_mode = debug_mode
	ik_node.debug_draw_gizmos = debug_draw_gizmos
	ik_node.debug_log_snapshots = debug_log_snapshots
	ik_node.debug_compare_tag = debug_compare_tag
	ik_node.enable_soft_reach_clamp = enable_soft_reach_clamp
	ik_node.soft_reach_buffer = soft_reach_buffer
	ik_node.enable_clavicle_assist = enable_clavicle_assist
	ik_node.clavicle_assist_max_degrees = clavicle_assist_max_degrees
	ik_node.clavicle_assist_full_overstretch = clavicle_assist_full_overstretch

func _ensure_debug_gizmo_root() -> void:
	if visuals_component == null:
		return
	if _debug_gizmo_root != null and is_instance_valid(_debug_gizmo_root):
		return

	_debug_gizmo_root = visuals_component.get_node_or_null("LeftHandIKDiagnostics") as LeftHandIKDebugGizmo3D
	if _debug_gizmo_root == null:
		_debug_gizmo_root = LeftHandIKDebugGizmo3D.new()
		_debug_gizmo_root.name = "LeftHandIKDiagnostics"
		visuals_component.add_child(_debug_gizmo_root)
	_debug_gizmo_root.set_gizmos_enabled(false)

func _update_debug_gizmos_visibility() -> void:
	if _debug_gizmo_root == null:
		return
	var enabled: bool = debug_mode != DEBUG_MODE_OFF and debug_draw_gizmos
	_debug_gizmo_root.set_gizmos_enabled(enabled)

func _on_modifier_debug_snapshot_emitted(modifier_snapshot: Dictionary) -> void:
	var merged_snapshot: Dictionary = modifier_snapshot.duplicate(true)
	var attachment_snapshot: Dictionary = _build_attachment_snapshot()
	var resolved_target: Variant = (merged_snapshot.get("target_space", {}) as Dictionary).get("resolved_target_transform", null)
	var grip_global: Variant = attachment_snapshot.get("grip_global_transform", null)
	if resolved_target is Transform3D and grip_global is Transform3D and skeleton != null:
		var resolved_target_global: Transform3D = skeleton.global_transform * (resolved_target as Transform3D)
		attachment_snapshot["resolved_target_global_transform"] = resolved_target_global
		attachment_snapshot["resolved_target_delta_from_grip"] = (grip_global as Transform3D).affine_inverse() * resolved_target_global
		attachment_snapshot["resolved_target_grip_origin_delta"] = resolved_target_global.origin - (grip_global as Transform3D).origin
	merged_snapshot["attachment_space"] = attachment_snapshot

	_append_snapshot_history(merged_snapshot)

	if debug_draw_gizmos and _debug_gizmo_root != null and debug_mode != DEBUG_MODE_OFF:
		_debug_gizmo_root.apply_snapshot(merged_snapshot)

	var debug_info: Dictionary = merged_snapshot.get("debug", {}) as Dictionary
	if bool(debug_info.get("should_log", false)):
		_emit_grouped_snapshot_logs(merged_snapshot)

	var tag: String = str(merged_snapshot.get("tag", ""))
	if not tag.is_empty():
		_debug_snapshots_by_tag[tag] = merged_snapshot.duplicate(true)
		_emit_snapshot_diff_if_ready(tag)

func _build_attachment_snapshot() -> Dictionary:
	var weapon_root_transform: Variant = null
	var handle_local_transform: Variant = null
	var handle_global_transform: Variant = null
	var grip_local_transform: Variant = null
	var grip_global_transform: Variant = null
	var attachment_root_transform: Variant = null
	var attachment_bone_name: String = ""
	var attachment_delta_transform: Variant = null
	var grip_to_handle_delta: Variant = null

	if _active_weapon_visual != null and is_instance_valid(_active_weapon_visual):
		weapon_root_transform = _active_weapon_visual.global_transform

		var handle_node: Node3D = _active_weapon_visual.find_child(handle_node_name, true, false) as Node3D
		if handle_node != null:
			handle_local_transform = handle_node.transform
			handle_global_transform = handle_node.global_transform

		if grip_target != null and is_instance_valid(grip_target):
			grip_local_transform = grip_target.transform
			grip_global_transform = grip_target.global_transform

		var current: Node = _active_weapon_visual
		while current != null:
			if current is BoneAttachment3D:
				var attachment: BoneAttachment3D = current as BoneAttachment3D
				attachment_root_transform = attachment.global_transform
				attachment_bone_name = attachment.bone_name
				if skeleton != null:
					var attachment_bone_idx: int = skeleton.find_bone(attachment.bone_name)
					if attachment_bone_idx != -1:
						var attachment_bone_pose: Transform3D = skeleton.get_bone_global_pose(attachment_bone_idx)
						attachment_delta_transform = attachment_bone_pose.affine_inverse() * attachment.global_transform
				break
			current = current.get_parent()

	if handle_global_transform is Transform3D and grip_global_transform is Transform3D:
		grip_to_handle_delta = (handle_global_transform as Transform3D).affine_inverse() * (grip_global_transform as Transform3D)

	return {
		"weapon_root_global_transform": weapon_root_transform,
		"handle_local_transform": handle_local_transform,
		"handle_global_transform": handle_global_transform,
		"grip_local_transform": grip_local_transform,
		"grip_global_transform": grip_global_transform,
		"attachment_root_global_transform": attachment_root_transform,
		"attachment_bone_name": attachment_bone_name,
		"attachment_root_delta_from_bone": attachment_delta_transform,
		"grip_to_handle_delta": grip_to_handle_delta,
		"hand_rotation_offset": hand_rotation_offset,
		"hand_position_offset": hand_position_offset
	}

func _append_snapshot_history(snapshot: Dictionary) -> void:
	_debug_snapshot_history.append(snapshot)
	while _debug_snapshot_history.size() > DEBUG_HISTORY_LIMIT:
		_debug_snapshot_history.remove_at(0)

func _emit_grouped_snapshot_logs(snapshot: Dictionary) -> void:
	var target_space: Dictionary = snapshot.get("target_space", {}) as Dictionary
	var attachment_space: Dictionary = snapshot.get("attachment_space", {}) as Dictionary
	var solver_inputs: Dictionary = snapshot.get("solver_inputs", {}) as Dictionary
	var solver_stages: Dictionary = snapshot.get("solver_stages", {}) as Dictionary
	var error_metrics: Dictionary = snapshot.get("error_metrics", {}) as Dictionary
	var tag: String = str(snapshot.get("tag", ""))
	var mode: String = str((snapshot.get("debug", {}) as Dictionary).get("mode", DEBUG_MODE_OFF))

	print("[LeftHandIK][target]%s source=%s target=%s virtual=%s order=%s" % [
		_tag_suffix(tag),
		str(target_space.get("target_source", "")),
		str(target_space.get("resolved_target_transform", Transform3D.IDENTITY)),
		str(target_space.get("virtual_target_transform", Transform3D.IDENTITY)),
		str(target_space.get("composition_order", PackedStringArray()))
	])
	print("[LeftHandIK][attachment]%s weapon=%s handle=%s grip=%s attach_root=%s bone=%s offsets={rot:%s,pos:%s}" % [
		_tag_suffix(tag),
		str(attachment_space.get("weapon_root_global_transform", null)),
		str(attachment_space.get("handle_global_transform", null)),
		str(attachment_space.get("grip_global_transform", null)),
		str(attachment_space.get("attachment_root_global_transform", null)),
		str(attachment_space.get("attachment_bone_name", "")),
		str(attachment_space.get("hand_rotation_offset", Vector3.ZERO)),
		str(attachment_space.get("hand_position_offset", Vector3.ZERO))
	])
	print("[LeftHandIK][attachment-delta]%s grip_to_handle=%s resolved_from_grip=%s grip_origin_delta=%s" % [
		_tag_suffix(tag),
		str(attachment_space.get("grip_to_handle_delta", null)),
		str(attachment_space.get("resolved_target_delta_from_grip", null)),
		str(attachment_space.get("resolved_target_grip_origin_delta", Vector3.ZERO))
	])
	print("[LeftHandIK][solver]%s shoulder=%s elbow=%s wrist=%s solved_elbow=%s final_wrist=%s wrist_error=%.4f elbow_delta=%s" % [
		_tag_suffix(tag),
		str((solver_inputs.get("shoulder_pose", Transform3D.IDENTITY) as Transform3D).origin),
		str((solver_inputs.get("elbow_pose", Transform3D.IDENTITY) as Transform3D).origin),
		str((solver_inputs.get("wrist_pose", Transform3D.IDENTITY) as Transform3D).origin),
		str(solver_stages.get("elbow_solved", Vector3.ZERO)),
		str((solver_stages.get("final_wrist_pose", Transform3D.IDENTITY) as Transform3D).origin),
		float(error_metrics.get("wrist_error_distance", 0.0)),
		str(error_metrics.get("elbow_solved_delta", Vector3.ZERO))
	])
	print("[LeftHandIK][lower-chain]%s local_before=%s local_after=%s actual_dir=%s desired_dir=%s angle_deg=%.3f" % [
		_tag_suffix(tag),
		str(solver_stages.get("elbow_local_to_wrist_before", Vector3.ZERO)),
		str(solver_stages.get("elbow_local_to_wrist_after", Vector3.ZERO)),
		str(solver_stages.get("lower_chain_actual_direction", Vector3.ZERO)),
		str(solver_stages.get("lower_chain_desired_direction", Vector3.ZERO)),
		float(solver_stages.get("lower_chain_angle_error_degrees", 0.0))
	])

	if mode == DEBUG_MODE_FULL:
		print("[LeftHandIK][full]%s motion=%s" % [_tag_suffix(tag), str(snapshot.get("motion_context", {}))])
		print("[LeftHandIK][full]%s target_space=%s" % [_tag_suffix(tag), str(target_space)])
		print("[LeftHandIK][full]%s attachment_space=%s" % [_tag_suffix(tag), str(attachment_space)])
		print("[LeftHandIK][full]%s solver_inputs=%s" % [_tag_suffix(tag), str(solver_inputs)])
		print("[LeftHandIK][full]%s solver_stages=%s" % [_tag_suffix(tag), str(solver_stages)])
		print("[LeftHandIK][full]%s error_metrics=%s" % [_tag_suffix(tag), str(error_metrics)])

func _emit_snapshot_diff_if_ready(new_tag: String) -> void:
	var tags: PackedStringArray = PackedStringArray()
	for key in _debug_snapshots_by_tag.keys():
		tags.append(str(key))
	if tags.size() < 2:
		return

	var previous_tag: String = ""
	for snapshot in _debug_snapshot_history:
		var snapshot_tag: String = str(snapshot.get("tag", ""))
		if snapshot_tag.is_empty() or snapshot_tag == new_tag:
			continue
		previous_tag = snapshot_tag
	if previous_tag.is_empty():
		return

	var older: Dictionary = _debug_snapshots_by_tag.get(previous_tag, {}) as Dictionary
	var newer: Dictionary = _debug_snapshots_by_tag.get(new_tag, {}) as Dictionary
	if older.is_empty() or newer.is_empty():
		return

	var older_target: Transform3D = ((older.get("target_space", {}) as Dictionary).get("virtual_target_transform", Transform3D.IDENTITY) as Transform3D)
	var newer_target: Transform3D = ((newer.get("target_space", {}) as Dictionary).get("virtual_target_transform", Transform3D.IDENTITY) as Transform3D)
	var older_handle: Variant = (older.get("attachment_space", {}) as Dictionary).get("handle_global_transform", null)
	var newer_handle: Variant = (newer.get("attachment_space", {}) as Dictionary).get("handle_global_transform", null)
	var older_grip: Variant = (older.get("attachment_space", {}) as Dictionary).get("grip_global_transform", null)
	var newer_grip: Variant = (newer.get("attachment_space", {}) as Dictionary).get("grip_global_transform", null)
	var older_error: float = float((older.get("error_metrics", {}) as Dictionary).get("wrist_error_distance", 0.0))
	var newer_error: float = float((newer.get("error_metrics", {}) as Dictionary).get("wrist_error_distance", 0.0))
	var older_elbow_delta: Vector3 = (older.get("error_metrics", {}) as Dictionary).get("elbow_solved_delta", Vector3.ZERO) as Vector3
	var newer_elbow_delta: Vector3 = (newer.get("error_metrics", {}) as Dictionary).get("elbow_solved_delta", Vector3.ZERO) as Vector3

	print("[LeftHandIK][diff] %s -> %s target_move=%.4f handle_move=%.4f grip_move=%.4f wrist_error_delta=%.4f elbow_delta_change=%.4f" % [
		previous_tag,
		new_tag,
		older_target.origin.distance_to(newer_target.origin),
		_transform_origin_delta(older_handle, newer_handle),
		_transform_origin_delta(older_grip, newer_grip),
		newer_error - older_error,
		older_elbow_delta.distance_to(newer_elbow_delta)
	])

func _transform_origin_delta(a: Variant, b: Variant) -> float:
	if a is Transform3D and b is Transform3D:
		return (a as Transform3D).origin.distance_to((b as Transform3D).origin)
	return 0.0

func _tag_suffix(tag: String) -> String:
	return "" if tag.is_empty() else "[%s]" % tag

func _resolve_first_existing_bone(candidates: PackedStringArray) -> String:
	if skeleton == null:
		return ""

	for bone_name_variant in candidates:
		var bone_name: String = str(bone_name_variant)
		if bone_name.is_empty():
			continue
		if skeleton.find_bone(bone_name) != -1:
			return bone_name
	return ""

func _resolve_optional_clavicle_bone(root_idx: int) -> String:
	if skeleton == null or root_idx == -1:
		return ""

	var parent_idx: int = skeleton.get_bone_parent(root_idx)
	for bone_name_variant in clavicle_bone_candidates:
		var bone_name: String = str(bone_name_variant)
		if bone_name.is_empty():
			continue
		var bone_idx: int = skeleton.find_bone(bone_name)
		if bone_idx != -1 and bone_idx == parent_idx:
			return bone_name
	return ""

func _is_bone_ancestor(ancestor_idx: int, bone_idx: int) -> bool:
	if skeleton == null or ancestor_idx == -1 or bone_idx == -1:
		return false

	var current_idx: int = skeleton.get_bone_parent(bone_idx)
	while current_idx != -1:
		if current_idx == ancestor_idx:
			return true
		current_idx = skeleton.get_bone_parent(current_idx)
	return false
