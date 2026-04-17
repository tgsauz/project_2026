extends Node
class_name TunerRigAdapter

var rig_root: Node3D
var rig_profile: TunerRigProfile

func configure(target_rig_root: Node3D, profile: TunerRigProfile) -> void:
	rig_root = target_rig_root
	rig_profile = profile

func get_visuals_host_root() -> Node3D:
	if rig_root == null:
		return null
	if rig_profile == null or rig_profile.visuals_host_path.is_empty():
		return rig_root
	var host := rig_root.get_node_or_null(rig_profile.visuals_host_path) as Node3D
	if host == null:
		push_warning("[TunerRigAdapter] visuals_host_path could not be resolved: %s" % str(rig_profile.visuals_host_path))
		return rig_root
	return host

func get_skeleton_path() -> NodePath:
	if rig_profile == null:
		return NodePath()
	return rig_profile.skeleton_path

func get_animation_tree() -> AnimationTree:
	if rig_root == null:
		return null
	if rig_profile == null or rig_profile.animation_tree_path.is_empty():
		return rig_root.find_child("AnimationTree", true, false) as AnimationTree
	var tree := rig_root.get_node_or_null(rig_profile.animation_tree_path) as AnimationTree
	if tree != null:
		return tree
	push_warning("[TunerRigAdapter] animation_tree_path could not be resolved: %s" % str(rig_profile.animation_tree_path))
	return rig_root.find_child("AnimationTree", true, false) as AnimationTree

func get_tuner_points() -> Array[AttachmentPointDefinition]:
	if rig_profile == null:
		return AttachmentLayoutLibrary.collect_tuner_points()

	var points: Array[AttachmentPointDefinition] = []
	var seen := {}

	match rig_profile.slot_source_mode:
		TunerRigProfile.SlotSourceMode.DEFAULT_LAYOUT_PLUS_MODIFIERS:
			_collect_layout_points(AttachmentLayoutLibrary.get_default_layout(), points, seen)
			_collect_modifier_points(points, seen)
		TunerRigProfile.SlotSourceMode.PROFILE_LAYOUT_ONLY:
			_collect_layout_points(_resolve_profile_layout(), points, seen)
		TunerRigProfile.SlotSourceMode.PROFILE_LAYOUT_PLUS_MODIFIERS:
			_collect_layout_points(_resolve_profile_layout(), points, seen)
			_collect_modifier_points(points, seen)
		TunerRigProfile.SlotSourceMode.PROFILE_CUSTOM_ONLY:
			pass
		_:
			_collect_layout_points(AttachmentLayoutLibrary.get_default_layout(), points, seen)
			_collect_modifier_points(points, seen)

	for point in rig_profile.custom_tuner_points:
		_add_point_if_valid(point, points, seen)

	if rig_profile.sort_points_by_order:
		points.sort_custom(func(a: AttachmentPointDefinition, b: AttachmentPointDefinition): return a.sort_order < b.sort_order)
	return points

func _resolve_profile_layout() -> AttachmentLayoutDefinition:
	if rig_profile == null or rig_profile.attachment_layout == null:
		return AttachmentLayoutLibrary.get_default_layout()
	return rig_profile.attachment_layout

func _collect_layout_points(layout: AttachmentLayoutDefinition, points: Array[AttachmentPointDefinition], seen: Dictionary) -> void:
	if layout == null:
		return
	for point in layout.attachment_points:
		_add_point_if_valid(point, points, seen)

func _collect_modifier_points(points: Array[AttachmentPointDefinition], seen: Dictionary) -> void:
	ItemDefinitionRegistry.initialize()
	for definition in ItemDefinitionRegistry.get_all_definitions():
		if definition == null or definition.attachment_modifier == null:
			continue
		for point in definition.attachment_modifier.attachment_points:
			_add_point_if_valid(point, points, seen)

func _add_point_if_valid(point: AttachmentPointDefinition, points: Array[AttachmentPointDefinition], seen: Dictionary) -> void:
	if point == null or point.node_id.is_empty() or not point.tuner_enabled:
		return
	if seen.has(point.node_id):
		return
	seen[point.node_id] = true
	points.append(point)
