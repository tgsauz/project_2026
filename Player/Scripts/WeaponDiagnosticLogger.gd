extends RefCounted
class_name WeaponDiagnosticLogger

# ============================================================
# WEAPON DIAGNOSTIC LOGGER
# Temporal instrumentation for weapon positioning diagnosis.
# Captures transforms, relationships, and layer stack results
# every frame to Debug/weapon_diag.log.
#
# Usage:
#   debug_weapon_diagnostic = true  (WeaponController @export)
#   Toggle at runtime via F12.
#
# No gameplay logic. No behavioral modification.
# ============================================================

const EPSILON: float = 0.001
const DEG_EPSILON: float = 0.1

var _file: FileAccess
var _enabled: bool = false
var _frame_count: int = 0
var _test_label: String = ""
var _pre_write_visual_local_pos: Vector3 = Vector3.ZERO
var _pre_write_visual_local_fwd: Vector3 = Vector3.FORWARD
var _pre_write_visual_parent: String = ""

# ============================================================
# LIFECYCLE
# ============================================================

func open() -> void:
	if _enabled:
		return
	_enabled = true
	_frame_count = 0
	var log_path: String = _resolve_log_path()
	_file = FileAccess.open(log_path, FileAccess.WRITE)
	if _file == null:
		push_error("WeaponDiagnosticLogger: Cannot open %s (error %d)" % [log_path, FileAccess.get_open_error()])
		_enabled = false
		return
	_file.store_line("================================================================")
	_file.store_line("WEAPON DIAGNOSTIC LOG")
	_file.store_line("Engine: Godot %s" % Engine.get_version_info().get("string", "unknown"))
	_file.store_line("Path: %s" % log_path)
	_file.store_line("================================================================")
	_file.store_line("")
	flush()

func close() -> void:
	if not _enabled:
		return
	if _file != null:
		_file.store_line("")
		_file.store_line("================================================================")
		_file.store_line("END OF LOG — %d frames captured" % _frame_count)
		_file.store_line("================================================================")
		_file = null
	_enabled = false
	_frame_count = 0

func is_enabled() -> bool:
	return _enabled

func set_test_label(label: String) -> void:
	_test_label = label
	if _file != null:
		_file.store_line("")
		_file.store_line("================================================================")
		_file.store_line("TEST: %s" % label)
		_file.store_line("================================================================")
		_file.store_line("")

func flush() -> void:
	if _file != null:
		_file.flush()

# ============================================================
# FRAME CAPTURE
# ============================================================

func begin_frame(state: AimState, weapon_root: Node3D, weapon_visual: Node3D, layer_results: Array[Dictionary]) -> void:
	if not _enabled or _file == null:
		return
	_frame_count += 1

	_file.store_line("")
	_file.store_line("----------------------------------------")
	_file.store_line("Frame %d" % _frame_count)
	_file.store_line("----------------------------------------")

	_log_aim_state(state)
	_log_weapon_root(weapon_root)

	if weapon_visual != null:
		var visual_parent: Node = weapon_visual.get_parent()
		_pre_write_visual_parent = String(visual_parent.name) if visual_parent != null else "null"
		_pre_write_visual_local_pos = weapon_visual.position
		_pre_write_visual_local_fwd = -weapon_visual.global_transform.basis.z.normalized()
		_log_weapon_visual(weapon_visual, "post_set")
	else:
		_file.store_line("")
		_file.store_line("Weapon Visual: NOT EQUIPPED")
		_pre_write_visual_parent = "none"
		_pre_write_visual_local_pos = Vector3.ZERO
		_pre_write_visual_local_fwd = Vector3.FORWARD

	_log_layer_stack(layer_results)

func end_frame(weapon_visual: Node3D) -> void:
	if not _enabled or _file == null:
		return

	_file.store_line("")
	_file.store_line("--- Process Order ---")

	if weapon_visual != null and weapon_visual.is_inside_tree():
		var end_local_pos: Vector3 = weapon_visual.position
		var end_local_fwd: Vector3 = -weapon_visual.global_transform.basis.z.normalized()
		var end_parent: Node = weapon_visual.get_parent()
		var end_parent_name: String = String(end_parent.name) if end_parent != null else "null"

		_file.store_line("visual_parent:          %s" % end_parent_name)
		_file.store_line("visual_local_pos:       %s" % _v3(end_local_pos))
		_file.store_line("visual_local_fwd:       %s" % _v3(end_local_fwd))

		var pos_changed: bool = end_local_pos.distance_to(_pre_write_visual_local_pos) > EPSILON
		var fwd_changed: bool = end_local_fwd.distance_to(_pre_write_visual_local_fwd) > EPSILON
		var parent_changed: bool = end_parent_name != _pre_write_visual_parent

		if pos_changed or fwd_changed or parent_changed:
			_file.store_line("")
			_file.store_line("*** CONFLICT DETECTED ***")
			_file.store_line("  parent changed: %s -> %s" % [_pre_write_visual_parent, end_parent_name])
			_file.store_line("  local_pos:      %s -> %s" % [_v3(_pre_write_visual_local_pos), _v3(end_local_pos)])
			_file.store_line("  local_fwd:      %s -> %s" % [_v3(_pre_write_visual_local_fwd), _v3(end_local_fwd)])
		else:
			_file.store_line("STATUS: OK (no overwrite detected)")
	else:
		_file.store_line("weapon_visual: null or not in tree")

	flush()

# ============================================================
# LOG SECTIONS
# ============================================================

func _log_aim_state(state: AimState) -> void:
	_file.store_line("")
	_file.store_line("--- AimState ---")
	if state == null or not state.is_valid:
		_file.store_line("  INVALID (null or is_valid=false)")
		return
	_file.store_line("  sequence:      %d" % state.sequence)
	_file.store_line("  look_pitch:    %.2f deg" % rad_to_deg(state.look_pitch))
	_file.store_line("  look_yaw:      %.2f deg" % rad_to_deg(state.look_yaw))
	_file.store_line("  aim_direction: %s" % _v3(state.aim_direction))
	_file.store_line("  eye_position:  %s" % _v3(state.eye_position))
	_file.store_line("  ads_weight:    %.4f" % state.ads_weight)
	_file.store_line("  aim_orient_w:  %.4f" % state.aim_orientation_weight)
	_file.store_line("  fov_target:    %.2f" % state.fov_target)
	_file.store_line("  camera_mode:   %s" % ("FPS" if state.camera_mode else "TPS"))

func _log_weapon_root(weapon_root: Node3D) -> void:
	_file.store_line("")
	_file.store_line("--- WeaponRoot ---")
	if weapon_root == null:
		_file.store_line("  NULL")
		return
	var parent: Node = weapon_root.get_parent()
	_file.store_line("  parent:     %s" % (String(parent.name) if parent != null else "null"))
	_file.store_line("  global_pos: %s" % _v3(weapon_root.global_position))
	_file.store_line("  global_fwd: %s" % _v3(-weapon_root.global_transform.basis.z.normalized()))
	_file.store_line("  local_pos:  %s" % _v3(weapon_root.position))
	_file.store_line("  local_fwd:  %s" % _v3(-weapon_root.transform.basis.z.normalized()))

func _log_weapon_visual(visual: Node3D, label: String) -> void:
	_file.store_line("")
	_file.store_line("--- Weapon Visual [%s] ---" % label)
	_file.store_line("  name:       %s" % visual.name)
	var parent: Node = visual.get_parent()
	_file.store_line("  parent:     %s" % (String(parent.name) if parent != null else "null"))
	_file.store_line("  global_pos: %s" % _v3(visual.global_position))
	_file.store_line("  global_fwd: %s" % _v3(-visual.global_transform.basis.z.normalized()))
	_file.store_line("  local_pos:  %s" % _v3(visual.position))
	_file.store_line("  local_fwd:  %s" % _v3(-visual.transform.basis.z.normalized()))

	var local_delta_pos: float = visual.position.length()
	var local_fwd_angle: float = rad_to_deg(acos(clampf(
		Vector3.FORWARD.dot(-visual.transform.basis.z.normalized()), -1.0, 1.0)))
	_file.store_line("  LOCAL偏差:  pos=%.6f  angle=%.2f deg" % [local_delta_pos, local_fwd_angle])

func _log_grip_markers(marker_rgrip: Node3D, marker_lgrip: Node3D) -> void:
	_file.store_line("")
	_file.store_line("--- Grip Markers ---")
	if marker_rgrip != null and marker_rgrip.is_inside_tree():
		_file.store_line("  RGRIP  global=%s  local=%s" % [_v3(marker_rgrip.global_position), _v3(marker_rgrip.position)])
	else:
		_file.store_line("  RGRIP: not found")
	if marker_lgrip != null and marker_lgrip.is_inside_tree():
		_file.store_line("  LGRIP  global=%s  local=%s" % [_v3(marker_lgrip.global_position), _v3(marker_lgrip.position)])
	else:
		_file.store_line("  LGRIP: not found")

func _log_skeleton_bones(skeleton: Skeleton3D, bone_data: Array[Dictionary]) -> void:
	_file.store_line("")
	_file.store_line("--- Skeleton Bones ---")
	_file.store_line("  %-14s %-22s %-22s %s" % ["bone", "global_pos", "global_fwd", "parent"])
	for bd in bone_data:
		var idx: int = bd.get("idx", -1)
		var bname: String = bd.get("name", "?")
		if idx == -1 or skeleton == null:
			_file.store_line("  %-14s %s" % [bname, "NOT FOUND"])
			continue
		var gpose: Transform3D = skeleton.get_bone_global_pose(idx)
		var gpos: Vector3 = skeleton.global_transform * gpose.origin
		var gfwd: Vector3 = -(skeleton.global_transform.basis * gpose.basis).z
		var parent_idx: int = skeleton.get_bone_parent(idx)
		var parent_name: String = skeleton.get_bone_name(parent_idx) if parent_idx != -1 else "[root]"
		_file.store_line("  %-14s %-22s %-22s %s" % [bname, _v3(gpos), _v3(gfwd), parent_name])

func _log_ik_targets(targets: Array[Dictionary]) -> void:
	_file.store_line("")
	_file.store_line("--- IK Targets ---")
	for t in targets:
		var tname: String = t.get("name", "?")
		var pos: Vector3 = t.get("pos", Vector3.ZERO)
		var fwd: Vector3 = t.get("fwd", Vector3.FORWARD)
		_file.store_line("  %-18s pos=%s  fwd=%s" % [tname, _v3(pos), _v3(fwd)])

func _log_layer_stack(layer_results: Array[Dictionary]) -> void:
	_file.store_line("")
	_file.store_line("--- Layer Stack ---")
	if layer_results.is_empty():
		_file.store_line("  (no layers)")
		return
	for lr in layer_results:
		var lrlabel: String = lr.get("label", "?")
		var lrorigin: Vector3 = lr.get("origin", Vector3.ZERO)
		var lrfwd: Vector3 = lr.get("fwd", Vector3.FORWARD)
		var lrweight: float = lr.get("weight", -1.0)
		if lrweight >= 0.0:
			_file.store_line("  %-8s origin=%s fwd=%s  w=%.4f" % [lrlabel, _v3(lrorigin), _v3(lrfwd), lrweight])
		else:
			_file.store_line("  %-8s origin=%s fwd=%s" % [lrlabel, _v3(lrorigin), _v3(lrfwd)])

func _log_relative_transforms(relatives: Array[Dictionary]) -> void:
	_file.store_line("")
	_file.store_line("--- Relative Transforms ---")
	for r in relatives:
		var rlabel: String = r.get("label", "?")
		var rdelta: Vector3 = r.get("delta_pos", Vector3.ZERO)
		var rangle: float = r.get("angle_deg", 0.0)
		_file.store_line("  %-24s dpos=%s  angle=%.2f deg" % [rlabel, _v3(rdelta), rangle])

# ============================================================
# PUBLIC DATA-COLLECTION HELPERS
# ============================================================

func collect_grip_markers(weapon_visual: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = [null, null]
	if weapon_visual == null:
		return result
	var rgrip: Node3D = weapon_visual.find_child("RGRIP", true, false) as Node3D
	var lgrip: Node3D = weapon_visual.find_child("LGRIP", true, false) as Node3D
	result[0] = rgrip
	result[1] = lgrip
	return result

func collect_skeleton_bones(skeleton: Skeleton3D) -> Array[Dictionary]:
	var bones: Array[Dictionary] = []
	if skeleton == null:
		return bones
	for bname in ["spine_02", "clavicle_r", "hand_r", "hand_l", "ik_hand_gun"]:
		bones.append({"name": bname, "idx": skeleton.find_bone(bname)})
	return bones

func collect_ik_targets(ik_controller: FullBodyIKController) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if ik_controller == null:
		return targets

	var rh_target: Node3D = ik_controller.get("_right_hand_target") as Node3D
	if rh_target != null and rh_target.is_inside_tree():
		targets.append({
			"name": "RightHandIK",
			"pos": rh_target.global_position,
			"fwd": -rh_target.global_transform.basis.z.normalized()
		})
	else:
		targets.append({"name": "RightHandIK", "pos": Vector3.ZERO, "fwd": Vector3.ZERO})

	var lh_target: Node3D = ik_controller.get("_left_hand_target") as Node3D
	if lh_target != null and lh_target.is_inside_tree():
		targets.append({
			"name": "LeftHandIK",
			"pos": lh_target.global_position,
			"fwd": -lh_target.global_transform.basis.z.normalized()
		})
	else:
		targets.append({"name": "LeftHandIK", "pos": Vector3.ZERO, "fwd": Vector3.ZERO})

	var aim_target: Node3D = ik_controller.get("_aim_target") as Node3D
	if aim_target != null and aim_target.is_inside_tree():
		targets.append({
			"name": "AimIK",
			"pos": aim_target.global_position,
			"fwd": -aim_target.global_transform.basis.z.normalized()
		})
	else:
		targets.append({"name": "AimIK", "pos": Vector3.ZERO, "fwd": Vector3.ZERO})

	return targets

func collect_relative_transforms(weapon_root: Node3D, weapon_visual: Node3D, marker_rgrip: Node3D, marker_lgrip: Node3D, skeleton: Skeleton3D) -> Array[Dictionary]:
	var relatives: Array[Dictionary] = []
	if weapon_root == null:
		return relatives

	var wr_xform: Transform3D = weapon_root.global_transform

	if skeleton != null:
		var sp2_idx: int = skeleton.find_bone("spine_02")
		if sp2_idx != -1:
			var sp2_pos: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(sp2_idx).origin
			var delta: Vector3 = sp2_pos - wr_xform.origin
			relatives.append({"label": "WRoot->spine_02", "delta_pos": delta, "angle_deg": _angle_between_fwd(wr_xform, sp2_pos)})

		var gun_idx: int = skeleton.find_bone("ik_hand_gun")
		if gun_idx != -1:
			var gun_pos: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(gun_idx).origin
			var delta: Vector3 = gun_pos - wr_xform.origin
			relatives.append({"label": "WRoot->ik_hand_gun", "delta_pos": delta, "angle_deg": _angle_between_fwd(wr_xform, gun_pos)})

		var clav_idx: int = skeleton.find_bone("clavicle_r")
		if clav_idx != -1:
			var clav_pos: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(clav_idx).origin
			var delta: Vector3 = clav_pos - wr_xform.origin
			relatives.append({"label": "WRoot->clavicle_r", "delta_pos": delta, "angle_deg": _angle_between_fwd(wr_xform, clav_pos)})

	if weapon_visual != null and weapon_visual.is_inside_tree():
		var local_pos: Vector3 = weapon_visual.position
		var local_angle: float = rad_to_deg(acos(clampf(
			Vector3.FORWARD.dot(-weapon_visual.transform.basis.z.normalized()), -1.0, 1.0)))
		relatives.append({"label": "Visual->WRoot", "delta_pos": local_pos, "angle_deg": local_angle})

	if marker_rgrip != null and marker_rgrip.is_inside_tree() and skeleton != null:
		var hand_r_idx: int = skeleton.find_bone("hand_r")
		if hand_r_idx != -1:
			var hand_r_pos: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(hand_r_idx).origin
			var delta: Vector3 = hand_r_pos - marker_rgrip.global_position
			relatives.append({"label": "RGRIP->hand_r", "delta_pos": delta, "angle_deg": _angle_between(marker_rgrip.global_transform, hand_r_pos)})

	if marker_lgrip != null and marker_lgrip.is_inside_tree() and skeleton != null:
		var hand_l_idx: int = skeleton.find_bone("hand_l")
		if hand_l_idx != -1:
			var hand_l_pos: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(hand_l_idx).origin
			var delta: Vector3 = hand_l_pos - marker_lgrip.global_position
			relatives.append({"label": "LGRIP->hand_l", "delta_pos": delta, "angle_deg": _angle_between(marker_lgrip.global_transform, hand_l_pos)})

	return relatives

func log_grip_markers(marker_rgrip: Node3D, marker_lgrip: Node3D) -> void:
	_log_grip_markers(marker_rgrip, marker_lgrip)

func log_skeleton_bones(skeleton: Skeleton3D, bone_data: Array[Dictionary]) -> void:
	_log_skeleton_bones(skeleton, bone_data)

func log_ik_targets(targets: Array[Dictionary]) -> void:
	_log_ik_targets(targets)

func log_relative_transforms(relatives: Array[Dictionary]) -> void:
	_log_relative_transforms(relatives)

# ============================================================
# HELPERS
# ============================================================

static func _v3(v: Vector3) -> String:
	return "(%.4f, %.4f, %.4f)" % [v.x, v.y, v.z]

static func _angle_between_fwd(from_xform: Transform3D, target_pos: Vector3) -> float:
	var to_dir: Vector3 = (target_pos - from_xform.origin).normalized()
	var from_fwd: Vector3 = -from_xform.basis.z
	return rad_to_deg(acos(clampf(from_fwd.dot(to_dir), -1.0, 1.0)))

static func _angle_between(from_xform: Transform3D, target_pos: Vector3) -> float:
	var to_dir: Vector3 = (target_pos - from_xform.origin).normalized()
	var from_fwd: Vector3 = -from_xform.basis.z
	return rad_to_deg(acos(clampf(from_fwd.dot(to_dir), -1.0, 1.0)))

static func _resolve_log_path() -> String:
	var project_root: String = ProjectSettings.globalize_path("res://")
	var debug_dir: String = project_root.path_join("Debug")
	if not DirAccess.dir_exists_absolute(debug_dir):
		DirAccess.make_dir_recursive_absolute(debug_dir)
	return debug_dir.path_join("weapon_diag.log")
