extends Node

# ============================================================
#  CHARACTER TUNER CONTROLLER
# ============================================================

@export var character_rig_path: NodePath
@onready var visuals: VisualsComponent = _resolve_visuals_component()
@onready var animation_tree: AnimationTree = _resolve_animation_tree()

var all_items: Array[ItemDefinition] = []
var active_slots: PackedStringArray = PackedStringArray()
var tuner_points: Array[AttachmentPointDefinition] = []
var copied_transform := {
	"position": Vector3.ZERO,
	"rotation_degrees": Vector3.ZERO,
	"scale": Vector3.ONE
}

signal item_list_updated
signal profile_changed(slot_name: String, profile: ItemVisualAttachmentProfile, status_text: String)

func _ready():
	_refresh_tuner_points()
	_scan_items()
	
func _scan_items():
	ItemDefinitionRegistry.initialize()
	all_items.clear()
	for definition in ItemDefinitionRegistry.get_all_definitions():
		if definition != null:
			all_items.append(definition)
	all_items.sort_custom(func(a: ItemDefinition, b: ItemDefinition): return a.display_name.naturalnocasecmp_to(b.display_name) < 0)
	emit_signal("item_list_updated")

func rescan_items() -> void:
	_refresh_tuner_points()
	_scan_items()

func _refresh_tuner_points() -> void:
	tuner_points = AttachmentLayoutLibrary.collect_tuner_points()
	active_slots = PackedStringArray()
	for point in tuner_points:
		active_slots.append(point.node_id)

func get_items_for_slot(slot_name: String) -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	var point := _find_tuner_point(slot_name)
	for item in all_items:
		if item == null:
			continue
		if item.allowed_slots.has(slot_name) or _matches_dynamic_point(item, point):
			result.append(item)
	return result

func get_slot_label(slot_name: String) -> String:
	var point := _find_tuner_point(slot_name)
	if point == null:
		return slot_name.replace("_", " ").capitalize()
	var suffix := " [Gear]" if not point.parent_node_id.is_empty() else ""
	return point.get_display_name_or_default() + suffix

func equip_item(slot_name: String, definition: ItemDefinition):
	if visuals == null:
		return
	if definition == null:
		visuals.clear_runtime_visual(slot_name)
		return

	var profile = definition.get_attachment_profile(slot_name)
	var profile_state := "Existing profile in resource"
	
	# If no profile exists, let's create a temporary one for tuning
	if profile == null:
		profile = ItemVisualAttachmentProfile.new()
		profile.slot_name = slot_name
		profile_state = "New unsaved profile"
	elif definition.resource_path.is_empty():
		profile_state = "External resource-backed profile"
	
	var entry = {
		"item_id": "TUNER",
		"definition": definition,
		"attachment_profile": profile,
		"equipped_visual_scene": definition.equipped_visual_scene
	}
	
	visuals.set_runtime_visual(slot_name, entry)
	emit_signal("profile_changed", slot_name, profile, profile_state)

func save_profile(slot_name: String, definition: ItemDefinition, current_profile: ItemVisualAttachmentProfile):
	if definition == null or current_profile == null: 
		push_error("[CharacterTuner] Cannot save: definition or profile is null")
		return
	
	# Ensure the profile has the correct slot name before saving
	current_profile.slot_name = slot_name
	
	var existing = definition.get_attachment_profile(slot_name)
	if existing == null:
		# If this was a temporary profile created during tuning, add it
		definition.attachment_profiles.append(current_profile)
	else:
		# Update existing values
		existing.position = current_profile.position
		existing.rotation_degrees = current_profile.rotation_degrees
		existing.scale = current_profile.scale
	
	var err = ResourceSaver.save(definition, definition.resource_path)
	if err == OK:
		print("[CharacterTuner] SUCCESSFULLY SAVED profile for %s to %s" % [slot_name, definition.resource_path])
	else:
		push_error("[CharacterTuner] FAILED TO SAVE profile. Error code: %d" % err)

func update_offset(slot_name: String, pos: Vector3, rot: Vector3, sca: Vector3):
	if visuals == null:
		return
	var visual = visuals.get_active_visual(slot_name, "TUNER")
	if is_instance_valid(visual):
		visual.position = pos
		visual.rotation_degrees = rot
		visual.scale = sca

func set_animation_blend(lateral: float, forward: float):
	if animation_tree:
		animation_tree.set("parameters/Locomotion/BlendSpace2D/blend_position", Vector2(lateral, forward))

func copy_profile_transform(profile: ItemVisualAttachmentProfile) -> void:
	if profile == null:
		return
	copied_transform = {
		"position": profile.position,
		"rotation_degrees": profile.rotation_degrees,
		"scale": profile.scale
	}

func paste_profile_transform(profile: ItemVisualAttachmentProfile) -> void:
	if profile == null:
		return
	profile.position = copied_transform.get("position", Vector3.ZERO)
	profile.rotation_degrees = copied_transform.get("rotation_degrees", Vector3.ZERO)
	profile.scale = copied_transform.get("scale", Vector3.ONE)

func mirror_profile_for_slot(slot_name: String, profile: ItemVisualAttachmentProfile) -> void:
	if profile == null:
		return
	if slot_name != "left_hand" and slot_name != "right_hand":
		return

	profile.position.x = -profile.position.x
	profile.rotation_degrees.y = -profile.rotation_degrees.y
	profile.rotation_degrees.z = -profile.rotation_degrees.z

func set_anchor_debug_enabled(enabled: bool) -> void:
	if visuals == null:
		return
	visuals.show_attachment_debug_gizmos = enabled
	visuals._refresh_attachment_debug_gizmos()

func _resolve_visuals_component() -> VisualsComponent:
	var rig = get_node_or_null(character_rig_path)
	if rig == null:
		return null
	return rig.get_node_or_null("Visuals") as VisualsComponent

func _resolve_animation_tree() -> AnimationTree:
	var rig = get_node_or_null(character_rig_path)
	if rig == null:
		return null
	return rig.get_node_or_null("Visuals/Rig/AnimationTree") as AnimationTree

func _find_tuner_point(slot_name: String) -> AttachmentPointDefinition:
	for point in tuner_points:
		if point != null and point.node_id == slot_name:
			return point
	return null

func _matches_dynamic_point(item: ItemDefinition, point: AttachmentPointDefinition) -> bool:
	if item == null or point == null:
		return false
	if not point.accepted_categories.is_empty() and not point.accepted_categories.has(item.category):
		return false
	if point.accepted_item_tags.is_empty():
		return true
	for tag in item.attachment_tags:
		if point.accepted_item_tags.has(tag):
			return true
	return false
