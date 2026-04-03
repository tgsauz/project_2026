extends Resource
class_name AttachmentLayoutDefinition

@export var layout_id: String = ""
@export var display_name: String = ""
@export var attachment_points: Array[AttachmentPointDefinition] = []

func get_point(node_id: String) -> AttachmentPointDefinition:
	for point in attachment_points:
		if point != null and point.node_id == node_id:
			return point
	return null

func get_root_points() -> Array[AttachmentPointDefinition]:
	var roots: Array[AttachmentPointDefinition] = []
	for point in attachment_points:
		if point != null and point.parent_node_id.is_empty():
			roots.append(point)
	roots.sort_custom(func(a: AttachmentPointDefinition, b: AttachmentPointDefinition): return a.sort_order < b.sort_order)
	return roots

func get_all_point_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for point in attachment_points:
		if point != null and not point.node_id.is_empty() and not ids.has(point.node_id):
			ids.append(point.node_id)
	return ids
