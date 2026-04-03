extends RefCounted
class_name RuntimeAttachmentNode

var node_id: String = ""
var definition: AttachmentPointDefinition
var parent_node_id: String = ""
var occupant_item_id: String = ""
var source_item_id: String = ""
var child_node_ids: PackedStringArray = PackedStringArray()

func to_dictionary() -> Dictionary:
	return {
		"node_id": node_id,
		"display_name": definition.get_display_name_or_default() if definition != null else node_id,
		"parent_node_id": parent_node_id,
		"occupant_item_id": occupant_item_id,
		"source_item_id": source_item_id,
		"visible": definition.visible if definition != null else true,
		"anchor_bone_name": definition.anchor_bone_name if definition != null else "",
		"anchor_local_position": definition.anchor_local_position if definition != null else Vector3.ZERO,
		"anchor_local_rotation": definition.anchor_local_rotation if definition != null else Vector3.ZERO,
		"debug_color": definition.debug_color if definition != null else Color.WHITE,
		"is_hand_slot": definition.is_hand_slot if definition != null else false,
		"sort_order": definition.sort_order if definition != null else 0
	}
