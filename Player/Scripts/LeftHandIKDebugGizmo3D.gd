extends Node3D
class_name LeftHandIKDebugGizmo3D

const MARKER_SIZE: float = 0.025
const LINE_THICKNESS: float = 0.012

var _point_gizmos: Dictionary = {}
var _line_gizmos: Dictionary = {}

func apply_snapshot(snapshot: Dictionary) -> void:
	visible = true

	var actual_color: Color = Color(0.2, 0.55, 1.0, 1.0)
	var target_color: Color = Color(0.2, 1.0, 0.2, 1.0)
	var solved_color: Color = Color(1.0, 0.86, 0.2, 1.0)
	var error_color: Color = Color(1.0, 0.2, 0.2, 1.0)

	_update_transform_gizmo("ShoulderActual", _read_transform(snapshot, ["solver_inputs", "shoulder_pose"]), actual_color)
	_update_transform_gizmo("ElbowActual", _read_transform(snapshot, ["solver_inputs", "elbow_pose"]), actual_color)
	_update_transform_gizmo("WristActual", _read_transform(snapshot, ["solver_inputs", "wrist_pose"]), actual_color)
	_update_transform_gizmo("ElbowSolved", Transform3D(Basis.IDENTITY, _read_vector(snapshot, ["solver_stages", "elbow_solved"])), solved_color)
	_update_transform_gizmo("Handle", _read_transform(snapshot, ["attachment_space", "handle_global_transform"]), target_color)
	_update_transform_gizmo("Grip", _read_transform(snapshot, ["attachment_space", "grip_global_transform"]), target_color)
	_update_transform_gizmo("ResolvedTarget", _read_transform(snapshot, ["target_space", "resolved_target_transform"]), target_color)
	_update_transform_gizmo("VirtualTarget", _read_transform(snapshot, ["target_space", "virtual_target_transform"]), solved_color)
	_update_transform_gizmo("FinalWrist", _read_transform(snapshot, ["solver_stages", "final_wrist_pose"]), actual_color)

	_update_line("ActualUpperArm", _read_vector(snapshot, ["solver_inputs", "shoulder_pose", "origin"]), _read_vector(snapshot, ["solver_inputs", "elbow_pose", "origin"]), actual_color)
	_update_line("ActualLowerArm", _read_vector(snapshot, ["solver_inputs", "elbow_pose", "origin"]), _read_vector(snapshot, ["solver_inputs", "wrist_pose", "origin"]), actual_color)
	_update_line("SolvedUpperArm", _read_vector(snapshot, ["solver_inputs", "shoulder_pose", "origin"]), _read_vector(snapshot, ["solver_stages", "elbow_solved"]), solved_color)
	_update_line("ErrorLine", _read_vector(snapshot, ["solver_stages", "final_wrist_pose", "origin"]), _read_vector(snapshot, ["target_space", "virtual_target_transform", "origin"]), error_color)

func set_gizmos_enabled(enabled: bool) -> void:
	visible = enabled

func _update_transform_gizmo(gizmo_name: String, transform_value: Variant, base_color: Color) -> void:
	if not (transform_value is Transform3D):
		_hide_point(gizmo_name)
		return

	var gizmo_transform: Transform3D = transform_value as Transform3D
	var root: Node3D = _ensure_point_gizmo(gizmo_name, base_color)
	root.visible = true
	root.global_transform = gizmo_transform

func _hide_point(gizmo_name: String) -> void:
	var root: Node3D = _point_gizmos.get(gizmo_name, null) as Node3D
	if root != null:
		root.visible = false

func _update_line(line_name: String, from_position_value: Variant, to_position_value: Variant, color: Color) -> void:
	if not (from_position_value is Vector3) or not (to_position_value is Vector3):
		_hide_line(line_name)
		return

	var from_vec: Vector3 = from_position_value as Vector3
	var to_vec: Vector3 = to_position_value as Vector3
	var direction: Vector3 = to_vec - from_vec
	var length: float = direction.length()
	if length < 0.0001:
		_hide_line(line_name)
		return

	var root: Node3D = _ensure_line_gizmo(line_name, color)
	root.visible = true
	root.global_transform = Transform3D(_basis_from_y_axis(direction.normalized()), from_vec.lerp(to_vec, 0.5))

	var marker: MeshInstance3D = root.get_node_or_null("Body") as MeshInstance3D
	if marker != null and marker.mesh is BoxMesh:
		var mesh: BoxMesh = marker.mesh as BoxMesh
		mesh.size = Vector3(LINE_THICKNESS, length, LINE_THICKNESS)

func _hide_line(line_name: String) -> void:
	var root: Node3D = _line_gizmos.get(line_name, null) as Node3D
	if root != null:
		root.visible = false

func _ensure_point_gizmo(gizmo_name: String, base_color: Color) -> Node3D:
	var root: Node3D = _point_gizmos.get(gizmo_name, null) as Node3D
	if root != null:
		return root

	root = Node3D.new()
	root.name = gizmo_name
	add_child(root)
	_point_gizmos[gizmo_name] = root

	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.name = "Marker"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE * MARKER_SIZE
	marker.mesh = box
	marker.material_override = _create_material(base_color)
	root.add_child(marker)

	root.add_child(_create_axis_mesh("XAxis", Vector3(MARKER_SIZE * 0.8, 0.0, 0.0), Vector3(MARKER_SIZE * 1.6, MARKER_SIZE * 0.18, MARKER_SIZE * 0.18), Color(1.0, 0.2, 0.2, 1.0)))
	root.add_child(_create_axis_mesh("YAxis", Vector3(0.0, MARKER_SIZE * 0.8, 0.0), Vector3(MARKER_SIZE * 0.18, MARKER_SIZE * 1.6, MARKER_SIZE * 0.18), Color(0.2, 1.0, 0.2, 1.0)))
	root.add_child(_create_axis_mesh("ZAxis", Vector3(0.0, 0.0, MARKER_SIZE * 0.8), Vector3(MARKER_SIZE * 0.18, MARKER_SIZE * 0.18, MARKER_SIZE * 1.6), Color(0.2, 0.55, 1.0, 1.0)))
	return root

func _ensure_line_gizmo(line_name: String, color: Color) -> Node3D:
	var root: Node3D = _line_gizmos.get(line_name, null) as Node3D
	if root != null:
		return root

	root = Node3D.new()
	root.name = line_name
	add_child(root)
	_line_gizmos[line_name] = root

	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = BoxMesh.new()
	body.material_override = _create_material(color)
	root.add_child(body)
	return root

func _create_axis_mesh(axis_name: String, local_position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var axis: MeshInstance3D = MeshInstance3D.new()
	axis.name = axis_name
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	axis.mesh = box
	axis.position = local_position
	axis.material_override = _create_material(color)
	return axis

func _create_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

func _basis_from_y_axis(direction: Vector3) -> Basis:
	var y_axis: Vector3 = direction.normalized()
	var guide: Vector3 = Vector3.FORWARD
	if absf(y_axis.dot(guide)) > 0.98:
		guide = Vector3.RIGHT
	var x_axis: Vector3 = guide.cross(y_axis).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)

func _read_transform(snapshot: Dictionary, path: Array[String]) -> Variant:
	var value: Variant = _read_variant(snapshot, path)
	return value

func _read_vector(snapshot: Dictionary, path: Array[String]) -> Variant:
	var value: Variant = _read_variant(snapshot, path)
	return value

func _read_variant(source: Variant, path: Array[String]) -> Variant:
	var current: Variant = source
	for segment in path:
		if current is Dictionary:
			var dict: Dictionary = current as Dictionary
			if not dict.has(segment):
				return null
			current = dict[segment]
		elif current is Transform3D and segment == "origin":
			current = (current as Transform3D).origin
		else:
			return null
	return current
