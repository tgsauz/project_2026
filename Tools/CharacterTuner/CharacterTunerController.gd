extends Node

# ============================================================
#  CHARACTER TUNER CONTROLLER
# ============================================================

@export var character_rig_path: NodePath
@onready var visuals: VisualsComponent = get_node(character_rig_path).get_node("Visuals")
@onready var animation_tree: AnimationTree = get_node(character_rig_path).get_node("Visuals/Rig/AnimationTree")

var all_items: Array[ItemDefinition] = []
var active_slots: Array[String] = ["right_hand", "left_hand", "back_mount", "lower_back", "torso", "head", "belt"]

signal item_list_updated
signal profile_changed(slot_name: String, profile: ItemVisualAttachmentProfile)

func _ready():
	_scan_items()
	
func _scan_items():
	all_items.clear()
	var path = "res://World/Items/"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var res = load(path + file_name)
				if res is ItemDefinition:
					all_items.append(res)
			file_name = dir.get_next()
	
	emit_signal("item_list_updated")

func get_items_for_slot(slot_name: String) -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for item in all_items:
		if item.allowed_slots.has(slot_name):
			result.append(item)
	return result

func equip_item(slot_name: String, definition: ItemDefinition):
	if definition == null:
		visuals.clear_runtime_visual(slot_name)
		return

	var profile = definition.get_attachment_profile(slot_name)
	
	# If no profile exists, let's create a temporary one for tuning
	if profile == null:
		profile = ItemVisualAttachmentProfile.new()
		profile.slot_name = slot_name
	
	var entry = {
		"item_id": "TUNER",
		"definition": definition,
		"attachment_profile": profile,
		"equipped_visual_scene": definition.equipped_visual_scene
	}
	
	visuals.set_runtime_visual(slot_name, entry)
	emit_signal("profile_changed", slot_name, profile)

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
	var visual = visuals.get_active_visual(slot_name, "TUNER")
	if is_instance_valid(visual):
		visual.position = pos
		visual.rotation_degrees = rot
		visual.scale = sca

func set_animation_blend(lateral: float, forward: float):
	if animation_tree:
		animation_tree.set("parameters/Locomotion/BlendSpace2D/blend_position", Vector2(lateral, forward))
