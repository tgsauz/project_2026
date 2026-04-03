extends Resource
class_name EquipmentAttachmentModifier

@export var modifier_id: String = ""
@export var display_name: String = ""
@export var host_node_id: String = ""
@export var attachment_points: Array[AttachmentPointDefinition] = []

func get_point(node_id: String) -> AttachmentPointDefinition:
	for point in attachment_points:
		if point != null and point.node_id == node_id:
			return point
	return null
