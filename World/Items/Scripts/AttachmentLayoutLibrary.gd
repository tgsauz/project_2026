extends RefCounted
class_name AttachmentLayoutLibrary

const DEFAULT_LAYOUT_PATH := "res://World/Items/Config/DefaultPlayerAttachmentLayout.tres"

static var _default_layout: AttachmentLayoutDefinition

static func get_default_layout() -> AttachmentLayoutDefinition:
	if _default_layout == null:
		_default_layout = load(DEFAULT_LAYOUT_PATH) as AttachmentLayoutDefinition
		if _default_layout == null:
			push_error("AttachmentLayoutLibrary: Failed to load default layout at %s" % DEFAULT_LAYOUT_PATH)
	return _default_layout

static func get_default_root_node_ids() -> PackedStringArray:
	var layout := get_default_layout()
	if layout == null:
		return PackedStringArray()
	var ids := PackedStringArray()
	for point in layout.get_root_points():
		ids.append(point.node_id)
	return ids

static func get_default_point(node_id: String) -> AttachmentPointDefinition:
	var layout := get_default_layout()
	if layout == null:
		return null
	return layout.get_point(node_id)

static func get_base_known_point_ids() -> PackedStringArray:
	var seen := {}
	var ids := PackedStringArray()
	var layout := get_default_layout()
	if layout == null:
		return ids

	for point_id in layout.get_all_point_ids():
		if seen.has(point_id):
			continue
		ids.append(point_id)
		seen[point_id] = true
	return ids

static func append_modifier_point_ids(ids: PackedStringArray, modifier: EquipmentAttachmentModifier) -> PackedStringArray:
	if modifier == null:
		return ids

	var merged := PackedStringArray(ids)
	for point in modifier.attachment_points:
		if point == null or point.node_id.is_empty() or merged.has(point.node_id):
			continue
		merged.append(point.node_id)
	return merged

static func get_all_known_point_ids() -> PackedStringArray:
	var ids := get_base_known_point_ids()
	for definition in ItemDefinitionRegistry.get_all_definitions():
		if definition == null:
			continue
		ids = append_modifier_point_ids(ids, definition.attachment_modifier)
	return ids

static func has_known_point(node_id: String) -> bool:
	return get_all_known_point_ids().has(node_id)

static func collect_tuner_points() -> Array[AttachmentPointDefinition]:
	var points: Array[AttachmentPointDefinition] = []
	var seen := {}
	var layout := get_default_layout()
	if layout != null:
		for point in layout.attachment_points:
			if point != null and point.tuner_enabled and not seen.has(point.node_id):
				points.append(point)
				seen[point.node_id] = true

	var definitions = ItemDefinitionRegistry.get_all_definitions()
	for definition in definitions:
		if definition == null or definition.attachment_modifier == null:
			continue
		for point in definition.attachment_modifier.attachment_points:
			if point != null and point.tuner_enabled and not seen.has(point.node_id):
				points.append(point)
				seen[point.node_id] = true
	points.sort_custom(func(a: AttachmentPointDefinition, b: AttachmentPointDefinition): return a.sort_order < b.sort_order)
	return points
