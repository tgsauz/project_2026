extends Node
class_name CharacterTunerController

# ============================================================
#  CHARACTER TUNER CONTROLLER
# ============================================================

const VISUALS_COMPONENT_SCRIPT_PATH := "res://Player/Scripts/VisualsComponent.gd"
const DEFAULT_RIG_PRESET_PATHS := [
	"res://Tools/CharacterTuner/Config/HumanTunerRigPreset.tres"
]

@export var character_rig_path: NodePath
@export var rig_mount_path: NodePath = NodePath("..")
@export var tuner_camera_path: NodePath = NodePath("../TunerCamera")
@export var rig_presets: Array[TunerRigPreset] = []

var visuals: VisualsComponent
var animation_tree: AnimationTree
var active_rig: Node3D
var active_adapter: TunerRigAdapter
var active_rig_preset_index: int = -1
var managed_rig_instance: Node3D
var using_legacy_rig: bool = false
var legacy_rig_node: Node3D
var preview_aiming: bool = false

var all_items: Array[ItemDefinition] = []
var active_slots: PackedStringArray = PackedStringArray()
var tuner_points: Array[AttachmentPointDefinition] = []
var slot_preview_state: Dictionary = {}
var copied_transform := {
	"position": Vector3.ZERO,
	"rotation_degrees": Vector3.ZERO,
	"scale": Vector3.ONE
}

signal item_list_updated
signal profile_changed(slot_name: String, profile: ItemVisualAttachmentProfile, status_text: String)
signal rig_presets_updated(active_index: int)

func _ready():
	call_deferred("_finish_startup")

func _finish_startup() -> void:
	_ensure_rig_presets_loaded()
	var rig_loaded := false
	if not rig_presets.is_empty():
		rig_loaded = select_rig_preset(0)
	if not rig_loaded:
		_activate_legacy_rig()
	_refresh_tuner_points()
	_scan_items()

func _scan_items() -> void:
	# force_reload bypasses Godot's resource cache so any .tres saved since startup
	# is read fresh from disk. This is intentional for an editor/tool context.
	ItemDefinitionRegistry.force_reload()
	all_items.clear()
	for definition in ItemDefinitionRegistry.get_all_definitions():
		if definition != null:
			all_items.append(definition)
	all_items.sort_custom(func(a: ItemDefinition, b: ItemDefinition): return a.display_name.naturalnocasecmp_to(b.display_name) < 0)
	print("[CharacterTuner] Item list refreshed from disk: %d items." % all_items.size())
	emit_signal("item_list_updated")

func rescan_items() -> void:
	_refresh_tuner_points()
	_scan_items()

func get_rig_preset_labels() -> PackedStringArray:
	var labels := PackedStringArray()
	for preset in rig_presets:
		if preset == null:
			continue
		labels.append(preset.get_display_name_or_default())
	return labels

func get_active_rig_preset_index() -> int:
	return active_rig_preset_index

func has_rig_presets() -> bool:
	return not rig_presets.is_empty()

func select_rig_preset(index: int) -> bool:
	if index < 0 or index >= rig_presets.size():
		push_warning("[CharacterTuner] Invalid rig preset index: %d" % index)
		return false

	var preset := rig_presets[index]
	if preset == null or preset.rig_scene == null:
		push_warning("[CharacterTuner] Rig preset at index %d is missing rig_scene." % index)
		return false

	if active_rig_preset_index == index and active_rig != null and visuals != null:
		return true

	var rig_instance := preset.rig_scene.instantiate() as Node3D
	if rig_instance == null:
		push_warning("[CharacterTuner] Failed to instantiate rig scene for preset index %d." % index)
		return false

	var mount := _resolve_rig_mount()
	if mount == null:
		push_warning("[CharacterTuner] Could not resolve rig mount node.")
		rig_instance.queue_free()
		return false

	if managed_rig_instance != null and is_instance_valid(managed_rig_instance):
		managed_rig_instance.queue_free()
	if active_adapter != null and is_instance_valid(active_adapter):
		active_adapter.queue_free()
	managed_rig_instance = rig_instance
	mount.add_child(rig_instance)

	var adapter := _build_adapter_for_preset(preset, rig_instance)
	if adapter == null:
		push_warning("[CharacterTuner] Missing adapter for preset '%s'. Falling back to legacy assumptions." % preset.get_display_name_or_default())

	active_adapter = adapter
	active_rig = rig_instance
	using_legacy_rig = false
	active_rig_preset_index = index
	_set_legacy_rig_visible(false)

	_configure_runtime_for_active_rig()
	_refresh_tuner_points()
	_restore_slot_previews_after_rig_change()
	emit_signal("item_list_updated")
	_update_camera_target()
	emit_signal("rig_presets_updated", active_rig_preset_index)
	return true

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
	if slot_name.is_empty():
		push_warning("[CharacterTuner] Cannot equip item: slot_name is empty.")
		return

	if definition == null:
		if visuals != null:
			visuals.clear_runtime_visual(slot_name)
		slot_preview_state[slot_name] = {
			"item": null,
			"profile": null
		}
		_refresh_animation_preview_state()
		emit_signal("profile_changed", slot_name, null, "Item cleared")
		return

	var profile = definition.get_attachment_profile(slot_name)
	var profile_state := "Existing profile in resource"

	if profile == null:
		profile = ItemVisualAttachmentProfile.new()
		profile.slot_name = slot_name
		profile_state = "New unsaved profile"
	elif definition.resource_path.is_empty():
		profile_state = "External resource-backed profile"

	# ── Diagnostic: confirm what position is actually loaded from the profile ──
	var profile_path: String = profile.resource_path if not profile.resource_path.is_empty() else "<inline/new>"
	print("[CharacterTuner] equip_item: slot='%s' item='%s' profile='%s' state='%s' pos=%s rot=%s scale=%s" % [
		slot_name,
		definition.display_name,
		profile_path,
		profile_state,
		str(profile.position),
		str(profile.rotation_degrees),
		str(profile.scale)
	])

	var entry = {
		"item_id": "TUNER",
		"definition": definition,
		"attachment_profile": profile,
		"equipped_visual_scene": definition.equipped_visual_scene
	}

	if visuals != null:
		visuals.set_runtime_visual(slot_name, entry)
	else:
		push_warning("[CharacterTuner] VisualsComponent missing while equipping '%s' into '%s'." % [definition.display_name, slot_name])

	slot_preview_state[slot_name] = {
		"item": definition,
		"profile": profile
	}

	_refresh_animation_preview_state()
	emit_signal("profile_changed", slot_name, profile, profile_state)

func get_selected_item_for_slot(slot_name: String) -> ItemDefinition:
	if not slot_preview_state.has(slot_name):
		return null
	var entry := slot_preview_state[slot_name] as Dictionary
	return entry.get("item", null) as ItemDefinition

func get_selected_profile_for_slot(slot_name: String) -> ItemVisualAttachmentProfile:
	if not slot_preview_state.has(slot_name):
		return null
	var entry := slot_preview_state[slot_name] as Dictionary
	return entry.get("profile", null) as ItemVisualAttachmentProfile

func save_profile(slot_name: String, definition: ItemDefinition, current_profile: ItemVisualAttachmentProfile):
	if definition == null or current_profile == null:
		push_error("[CharacterTuner] Cannot save: definition or profile is null")
		return

	current_profile.slot_name = slot_name

	var existing = definition.get_attachment_profile(slot_name)
	var should_save_definition := false
	var should_save_profile := false
	var profile_to_save: ItemVisualAttachmentProfile = null

	if existing == null:
		definition.attachment_profiles.append(current_profile)
		should_save_definition = true
		if not current_profile.resource_path.is_empty():
			should_save_profile = true
			profile_to_save = current_profile
	else:
		existing.position = current_profile.position
		existing.rotation_degrees = current_profile.rotation_degrees
		existing.scale = current_profile.scale
		profile_to_save = existing
		if existing.resource_path.is_empty():
			# Inline sub-resource lives inside the item definition file.
			should_save_definition = true
		else:
			# External profile must be saved directly.
			should_save_profile = true

	var saved_any := false
	if should_save_profile and profile_to_save != null:
		if _save_resource_with_log(profile_to_save, "[CharacterTuner] Profile save failed for slot '%s'" % slot_name):
			saved_any = true

	if should_save_definition:
		if _save_resource_with_log(definition, "[CharacterTuner] Definition save failed for slot '%s'" % slot_name):
			saved_any = true

	if saved_any:
		print("[CharacterTuner] SUCCESSFULLY SAVED profile for %s" % slot_name)
		_verify_saved_profile_on_disk(slot_name, definition, current_profile)
		# Reload this definition from disk so in-memory data matches the saved file.
		# This prevents a stale cache from serving wrong positions on the next equip.
		_reload_definition_from_disk(definition)

func _save_resource_with_log(resource: Resource, context: String) -> bool:
	if resource == null:
		push_error("%s: resource is null." % context)
		return false
	if resource.resource_path.is_empty():
		push_error("%s: resource path is empty." % context)
		return false

	var err := ResourceSaver.save(resource, resource.resource_path)
	if err != OK:
		push_error("%s. Error code: %d Path: %s" % [context, err, resource.resource_path])
		return false
	return true

func _verify_saved_profile_on_disk(slot_name: String, definition: ItemDefinition, expected_profile: ItemVisualAttachmentProfile) -> void:
	if expected_profile == null:
		return

	var disk_profile: ItemVisualAttachmentProfile = null
	if not expected_profile.resource_path.is_empty():
		disk_profile = ResourceLoader.load(expected_profile.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemVisualAttachmentProfile
	else:
		if definition == null or definition.resource_path.is_empty():
			return
		var disk_definition := ResourceLoader.load(definition.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition
		if disk_definition != null:
			disk_profile = disk_definition.get_attachment_profile(slot_name)

	if disk_profile == null:
		push_warning("[CharacterTuner] Disk verification failed: profile missing after save for slot '%s'." % slot_name)
		return

	var pos_match := _vector3_approx_eq(disk_profile.position, expected_profile.position)
	var rot_match := _vector3_approx_eq(disk_profile.rotation_degrees, expected_profile.rotation_degrees)
	var scale_match := _vector3_approx_eq(disk_profile.scale, expected_profile.scale)
	if not pos_match or not rot_match or not scale_match:
		push_warning("[CharacterTuner] Disk profile mismatch for slot '%s'. Expected pos=%s rot=%s scale=%s | Disk pos=%s rot=%s scale=%s" % [
			slot_name,
			expected_profile.position,
			expected_profile.rotation_degrees,
			expected_profile.scale,
			disk_profile.position,
			disk_profile.rotation_degrees,
			disk_profile.scale
		])
	else:
		print("[CharacterTuner] Disk verification passed for slot '%s'." % slot_name)

func _vector3_approx_eq(a: Vector3, b: Vector3) -> bool:
	return is_equal_approx(a.x, b.x) and is_equal_approx(a.y, b.y) and is_equal_approx(a.z, b.z)

func _reload_definition_from_disk(definition: ItemDefinition) -> void:
	# After saving, reload the definition fresh from disk and update the in-memory
	# slot_preview_state so subsequent equip calls use the canonical saved values.
	if definition == null or definition.resource_path.is_empty():
		return
	var fresh := ResourceLoader.load(definition.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition
	if fresh == null:
		push_warning("[CharacterTuner] Could not reload definition from disk: %s" % definition.resource_path)
		return
	# Update the registry cache so future lookups return the fresh copy.
	ItemDefinitionRegistry._cache[fresh.id] = fresh
	# Update any slot_preview_state entry that still points at this definition.
	for slot_name in slot_preview_state.keys():
		var entry := slot_preview_state[slot_name] as Dictionary
		var stored_def := entry.get("item", null) as ItemDefinition
		if stored_def != null and stored_def.resource_path == definition.resource_path:
			var fresh_profile := fresh.get_attachment_profile(slot_name) as ItemVisualAttachmentProfile
			slot_preview_state[slot_name] = {
				"item": fresh,
				"profile": fresh_profile if fresh_profile != null else entry.get("profile")
			}
			print("[CharacterTuner] Reloaded in-memory profile for slot='%s' pos=%s" % [slot_name, str(fresh_profile.position) if fresh_profile != null else "<none>"])
			# Notify the UI so sliders reflect the saved (authoritative) values immediately.
			var status := "Saved \u2714" if fresh_profile != null else "Saved (no profile for slot)"
			emit_signal("profile_changed", slot_name, fresh_profile, status)
	# Also refresh the all_items list entry so the dropdown uses the fresh object.
	for i in range(all_items.size()):
		if all_items[i] != null and all_items[i].resource_path == definition.resource_path:
			all_items[i] = fresh
			break

func update_offset(slot_name: String, pos: Vector3, rot: Vector3, sca: Vector3):
	if visuals == null:
		return
	var visual = visuals.get_active_visual(slot_name, "TUNER")
	if is_instance_valid(visual):
		visual.position = pos
		visual.rotation_degrees = rot
		visual.scale = sca
		if slot_preview_state.has(slot_name):
			var entry := slot_preview_state[slot_name] as Dictionary
			var profile := entry.get("profile", null) as ItemVisualAttachmentProfile
			if profile != null:
				profile.position = pos
				profile.rotation_degrees = rot
				profile.scale = sca

func set_animation_blend(lateral: float, forward: float):
	if animation_tree == null:
		push_warning("[CharacterTuner] AnimationTree is not available for current rig.")
		return
	var blend_position := Vector2(lateral, forward)
	for state_name in ["Unarmed", "Armed", "Aiming"]:
		animation_tree.set("parameters/%s/BlendSpace2D/blend_position" % state_name, blend_position)
	_refresh_animation_preview_state()

func set_preview_aiming(enabled: bool) -> void:
	preview_aiming = enabled
	_refresh_animation_preview_state()

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
	var is_sided = slot_name.ends_with("_left") or slot_name.ends_with("_right") or slot_name.begins_with("left_") or slot_name.begins_with("right_")
	if not is_sided:
		return
	profile.position.x = -profile.position.x
	profile.rotation_degrees.y = -profile.rotation_degrees.y
	profile.rotation_degrees.z = -profile.rotation_degrees.z

func set_anchor_debug_enabled(enabled: bool) -> void:
	if visuals == null:
		return
	visuals.show_attachment_debug_gizmos = enabled
	visuals._refresh_attachment_debug_gizmos()

func _refresh_tuner_points() -> void:
	if active_adapter != null:
		tuner_points = active_adapter.get_tuner_points()
	else:
		if not using_legacy_rig:
			push_warning("[CharacterTuner] No active rig adapter found. Using legacy tuner points fallback.")
		tuner_points = AttachmentLayoutLibrary.collect_tuner_points()

	active_slots = PackedStringArray()
	for point in tuner_points:
		if point == null or point.node_id.is_empty():
			continue
		active_slots.append(point.node_id)
	_sync_tuner_points_with_visuals()

func _sync_tuner_points_with_visuals() -> void:
	if visuals == null:
		return
	visuals.register_tuner_attachment_points(tuner_points)

func _ensure_rig_presets_loaded() -> void:
	if not rig_presets.is_empty():
		return
	for path in DEFAULT_RIG_PRESET_PATHS:
		var preset := load(path) as TunerRigPreset
		if preset != null:
			rig_presets.append(preset)

func _resolve_rig_mount() -> Node3D:
	if not rig_mount_path.is_empty():
		return get_node_or_null(rig_mount_path) as Node3D
	var parent := get_parent() as Node3D
	return parent

func _build_adapter_for_preset(preset: TunerRigPreset, rig_root: Node3D) -> TunerRigAdapter:
	if preset == null:
		return null
	var adapter_script := preset.adapter_script
	if adapter_script == null:
		adapter_script = load("res://Tools/CharacterTuner/DefaultTunerRigAdapter.gd") as Script
	if adapter_script == null:
		return null
	var adapter_node := Node.new()
	adapter_node.name = "ActiveTunerRigAdapter"
	adapter_node.set_script(adapter_script)
	var typed_adapter := adapter_node as TunerRigAdapter
	if typed_adapter == null:
		push_warning("[CharacterTuner] Adapter script does not implement TunerRigAdapter.")
		adapter_node.queue_free()
		return null
	add_child(typed_adapter)
	typed_adapter.configure(rig_root, preset.rig_profile)
	return typed_adapter

func _configure_runtime_for_active_rig() -> void:
	if active_rig == null:
		visuals = null
		animation_tree = null
		return

	var host := active_rig
	var skeleton_path := NodePath()
	if active_adapter != null:
		var adapter_host := active_adapter.get_visuals_host_root()
		if adapter_host != null:
			host = adapter_host
		skeleton_path = active_adapter.get_skeleton_path()
		animation_tree = active_adapter.get_animation_tree()
	else:
		animation_tree = _resolve_animation_tree_legacy(active_rig)

	visuals = _ensure_visuals_component_for_host(host, skeleton_path)
	if animation_tree == null:
		animation_tree = _resolve_animation_tree_legacy(active_rig)
	_refresh_animation_preview_state()

func _activate_legacy_rig() -> void:
	if active_adapter != null and is_instance_valid(active_adapter):
		active_adapter.queue_free()
	active_adapter = null
	var rig := get_node_or_null(character_rig_path) as Node3D
	if rig == null:
		push_warning("[CharacterTuner] Legacy rig path could not be resolved: %s" % str(character_rig_path))
		return
	legacy_rig_node = rig
	active_rig = rig
	active_adapter = null
	active_rig_preset_index = -1
	using_legacy_rig = true
	_set_legacy_rig_visible(true)
	visuals = _ensure_visuals_component_for_host(active_rig, NodePath())
	animation_tree = _resolve_animation_tree_legacy(active_rig)
	_update_camera_target()
	emit_signal("rig_presets_updated", active_rig_preset_index)

func _set_legacy_rig_visible(visible: bool) -> void:
	if legacy_rig_node == null or not is_instance_valid(legacy_rig_node):
		legacy_rig_node = get_node_or_null(character_rig_path) as Node3D
	if legacy_rig_node == null:
		return
	legacy_rig_node.visible = visible

func _ensure_visuals_component_for_host(host: Node3D, skeleton_path: NodePath) -> VisualsComponent:
	if host == null:
		return null

	var existing := host.get_node_or_null("VisualsComponent") as VisualsComponent
	if existing != null:
		existing.configure_tuner_context(host, skeleton_path)
		existing.refresh_tuner_context()
		return existing

	var vis_node = Node.new()
	vis_node.name = "VisualsComponent"
	vis_node.script = load(VISUALS_COMPONENT_SCRIPT_PATH) as Script
	var typed_visuals := vis_node as VisualsComponent
	if typed_visuals != null:
		typed_visuals.configure_tuner_context(host, skeleton_path)
	host.add_child(vis_node)

	var resolved := host.get_node_or_null("VisualsComponent") as VisualsComponent
	if resolved != null:
		resolved.configure_tuner_context(host, skeleton_path)
		resolved.refresh_tuner_context()
	return resolved

func _resolve_animation_tree_legacy(rig: Node3D) -> AnimationTree:
	if rig == null:
		return null
	var direct := rig.get_node_or_null("Rig/AnimationTree") as AnimationTree
	if direct != null:
		return direct
	var fallback := rig.get_node_or_null("AnimationTree") as AnimationTree
	if fallback != null:
		return fallback
	return rig.find_child("AnimationTree", true, false) as AnimationTree

func _restore_slot_previews_after_rig_change() -> void:
	for slot_name in slot_preview_state.keys():
		var slot := str(slot_name)
		var entry := slot_preview_state[slot] as Dictionary
		var definition := entry.get("item", null) as ItemDefinition
		if definition == null:
			continue
		if active_slots.has(slot):
			equip_item(slot, definition)

func _update_camera_target() -> void:
	var camera := get_node_or_null(tuner_camera_path) as Node
	if camera == null:
		return
	camera.set("target", active_rig)

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

func _refresh_animation_preview_state() -> void:
	if animation_tree == null:
		return
	var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if playback == null:
		return
	var target_state := _get_preview_animation_state()
	if playback.get_current_node() != target_state:
		playback.travel(target_state)

func _get_preview_animation_state() -> String:
	if preview_aiming and _has_preview_weapon_in_hand():
		return "Aiming"
	if _has_preview_weapon_in_hand():
		return "Armed"
	return "Unarmed"

func _has_preview_weapon_in_hand() -> bool:
	for slot_name in ["right_hand", "left_hand"]:
		var entry := slot_preview_state.get(slot_name, {}) as Dictionary
		var definition := entry.get("item", null) as ItemDefinition
		if definition != null and definition.category == ItemDefinition.CATEGORY_WEAPON:
			return true
	return false
