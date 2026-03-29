extends Resource
class_name ItemVisualAttachmentProfile

@export var slot_name: String = ""
@export_enum("held", "mounted", "stowed_visible") var visual_state: String = "mounted"
@export var position: Vector3 = Vector3.ZERO
@export var rotation_degrees: Vector3 = Vector3.ZERO
@export var scale: Vector3 = Vector3.ONE
@export var secondary_slot_name: String = ""

func applies_to_slot(target_slot_name: String) -> bool:
	return slot_name == target_slot_name
