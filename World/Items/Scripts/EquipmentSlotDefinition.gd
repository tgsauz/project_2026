extends Resource
class_name EquipmentSlotDefinition

@export var slot_name: String = ""
@export var display_name: String = ""
@export var accepted_categories: PackedStringArray = PackedStringArray()
@export var visible: bool = true
@export var anchor_bone_name: String = ""
@export var anchor_local_position: Vector3 = Vector3.ZERO
@export var anchor_local_rotation: Vector3 = Vector3.ZERO
@export var debug_color: Color = Color.WHITE
@export var is_hand_slot: bool = false
@export var tuner_enabled: bool = true

func to_inventory_config() -> Dictionary:
	return {
		"display_name": display_name if not display_name.is_empty() else slot_name.replace("_", " ").capitalize(),
		"accepted_categories": accepted_categories,
		"visible": visible
	}
