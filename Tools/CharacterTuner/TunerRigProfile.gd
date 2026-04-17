extends Resource
class_name TunerRigProfile

enum SlotSourceMode {
	DEFAULT_LAYOUT_PLUS_MODIFIERS = 0,
	PROFILE_LAYOUT_ONLY = 1,
	PROFILE_LAYOUT_PLUS_MODIFIERS = 2,
	PROFILE_CUSTOM_ONLY = 3
}

@export var display_name: String = ""
@export var visuals_host_path: NodePath = NodePath(".")
@export var skeleton_path: NodePath = NodePath("Rig/Armature/Skeleton3D")
@export var animation_tree_path: NodePath = NodePath("Rig/AnimationTree")
@export var slot_source_mode: int = SlotSourceMode.DEFAULT_LAYOUT_PLUS_MODIFIERS
@export var attachment_layout: AttachmentLayoutDefinition
@export var custom_tuner_points: Array[AttachmentPointDefinition] = []
@export var sort_points_by_order: bool = true
