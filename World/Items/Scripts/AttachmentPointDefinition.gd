extends Resource
class_name AttachmentPointDefinition

@export var node_id: String = ""
@export var display_name: String = ""
@export var parent_node_id: String = ""
@export var accepted_categories: PackedStringArray = PackedStringArray()
@export var accepted_item_tags: PackedStringArray = PackedStringArray()
@export var visible: bool = true
@export var anchor_bone_name: String = ""
@export var anchor_local_position: Vector3 = Vector3.ZERO
@export var anchor_local_rotation: Vector3 = Vector3.ZERO
@export var debug_color: Color = Color.WHITE
@export var is_hand_slot: bool = false
@export var tuner_enabled: bool = true
@export var sort_order: int = 0

func get_display_name_or_default() -> String:
	if not display_name.is_empty():
		return display_name
	return node_id.replace("_", " ").capitalize()
