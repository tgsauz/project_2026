extends Resource
class_name ItemDefinition

# ============================================================
#  ITEM CLASSIFICATION
# ============================================================

const CATEGORY_WEAPON := "weapon"
const CATEGORY_AMMO := "ammo"
const CATEGORY_MEDICAL := "medical"
const CATEGORY_EQUIPMENT := "equipment"
const CATEGORY_CLOTHING := "clothing"

# ============================================================
#  CORE METADATA
# ============================================================

@export var id: String
@export var display_name: String
@export_multiline var tooltip_text: String
@export_enum("weapon", "ammo", "medical", "equipment", "clothing") var category: String = CATEGORY_EQUIPMENT
@export var weight: float = 1.0

@export_category("Interaction")
@export var interaction_verb: String = "Pick up"
@export var interaction_key_hint: String = "F"
@export var world_pickup_enabled: bool = true

@export_category("Stacking")
@export var stackable: bool = false
@export var max_stack: int = 1

@export_category("Equipment")
@export var allowed_slots: PackedStringArray = PackedStringArray()
@export var visible_when_equipped: bool = false
@export_enum("left_hand", "right_hand", "torso", "head", "belt", "lower_back", "back_mount", "shoulder_mount", "left_pocket", "right_pocket") var preferred_slot: String = "torso"
@export var equipped_visual_scene: PackedScene
@export var is_skinned_mesh: bool = false
@export var visual_profile_id: String = ""
@export var attachment_profiles: Array = []
@export var reserve_secondary_hand: bool = false
@export_enum("left_hand", "right_hand", "torso", "head", "belt", "lower_back", "back_mount", "shoulder_mount", "left_pocket", "right_pocket") var secondary_hand_slot: String = "left_hand"

@export_category("Container")
@export var is_container: bool = false
@export var container_capacity: int = 0
@export var container_max_weight: float = 0.0
@export var container_allowed_categories: PackedStringArray = PackedStringArray()

@export_category("Placeholder Visual")
@export_enum("none", "box", "long_box", "pouch") var placeholder_visual_shape: String = "box"
@export var placeholder_visual_size: Vector3 = Vector3(0.3, 0.2, 0.1)
@export var placeholder_visual_color: Color = Color(0.32, 0.38, 0.46, 1.0)

# ============================================================
#  HELPERS
# ============================================================

func get_interaction_label() -> String:
	return "%s [%s]" % [interaction_verb, interaction_key_hint]

func can_fit_in_slot(slot_name: String) -> bool:
	if allowed_slots.is_empty():
		return false
	return allowed_slots.has(slot_name)

func can_store_category(target_category: String) -> bool:
	if container_allowed_categories.is_empty():
		return true
	return container_allowed_categories.has(target_category)

func supports_slot(target_slot: String) -> bool:
	return allowed_slots.has(target_slot)

func supports_hand_slot() -> bool:
	return supports_slot("right_hand") or supports_slot("left_hand")

func is_hand_slot(target_slot: String) -> bool:
	return target_slot == "right_hand" or target_slot == "left_hand"

func should_show_in_slot(target_slot: String) -> bool:
	if is_hand_slot(target_slot):
		return true
	return visible_when_equipped

func get_attachment_profile(target_slot: String) -> ItemVisualAttachmentProfile:
	for profile in attachment_profiles:
		if profile != null and profile.applies_to_slot(target_slot):
			return profile
	return null

func get_visual_state_for_slot(target_slot: String) -> String:
	var profile := get_attachment_profile(target_slot)
	if profile != null:
		return profile.visual_state
	if is_hand_slot(target_slot):
		return "held"
	return "mounted"
