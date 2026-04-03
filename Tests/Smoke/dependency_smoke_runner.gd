extends SceneTree

const PLAYER_SCENE := preload("res://Player/PlayerCharacter.tscn")
const WORLD_SCENE := preload("res://World/testing_world.tscn")
const TUNER_SCENE := preload("res://Tools/CharacterTuner/CharacterTuner.tscn")
const TEST_POUCH := preload("res://World/Items/simplePouch.tres")
const TEST_BELT := preload("res://World/Items/simpleBelt.tres")
const TEST_VEST := preload("res://World/Items/simpleBPVest.tres")
const TEST_BACKPACK := preload("res://World/Items/simpleBackpack.tres")
const TEST_MEDICAL := preload("res://World/Items/TestMedicalItem.tres")
const TEST_WEAPON := preload("res://World/Items/TestWeaponItem.tres")

var failure_count := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_attachment_layout_contract()
	await _test_player_scene_boot()
	await _test_world_scene_boot()
	await _test_attachment_modifier_flow()
	await _test_storage_capacity_flow()
	await _test_visual_attachment_flow()
	await _test_serialization_flow()
	await _test_tuner_recursive_scan()

	if failure_count > 0:
		push_error("Dependency smoke tests failed with %d issue(s)." % failure_count)
		quit(1)
		return

	print("Dependency smoke tests passed.")
	quit(0)

func _test_attachment_layout_contract() -> void:
	var layout := AttachmentLayoutLibrary.get_default_layout()
	_assert(layout != null, "Default attachment layout should load.")
	if layout == null:
		return

	var root_ids := AttachmentLayoutLibrary.get_default_root_node_ids()
	var baseline_nodes := ["left_hand", "right_hand", "torso", "belt", "back_mount", "lower_back", "shoulder_mount", "left_pocket", "right_pocket"]
	for node_id in baseline_nodes:
		_assert(root_ids.has(node_id), "Default body layout is missing root node '%s'." % node_id)

	var unique_ids := {}
	for node_id in AttachmentLayoutLibrary.get_all_known_point_ids():
		_assert(not unique_ids.has(node_id), "Attachment layout contains duplicate point '%s'." % node_id)
		unique_ids[node_id] = true

func _test_player_scene_boot() -> void:
	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame

	var inventory := player.get_inventory_component()

	_assert(player is CharacterController, "Player root should use CharacterController.")
	_assert(inventory != null, "CharacterController should resolve InventoryComponent.")
	_assert(player.interaction != null, "CharacterController should resolve InteractionComponent.")
	_assert(player.animation_tree != null and player.animation_tree.active, "CharacterController should resolve and activate AnimationTree.")
	_assert(player.camera_controller != null, "CharacterController should resolve CameraController.")
	_assert(player.visuals_component != null, "CharacterController should resolve VisualsComponent.")
	_assert(inventory.slot_names == AttachmentLayoutLibrary.get_default_root_node_ids(), "Default player inventory should initialize from the shared attachment layout.")

	player.queue_free()
	await process_frame

func _test_world_scene_boot() -> void:
	var world := WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node("CharacterBody3D") as CharacterController
	var ui_root := world.get_node("CharacterBody3D/UIRoot")
	var debug_stats := world.get_node("CharacterBody3D/UIRoot/DebugLayer/DebugStatsUI")

	_assert(player != null, "Testing world should instantiate a CharacterController player.")
	_assert(ui_root != null, "Testing world should instantiate UIRoot.")
	_assert(debug_stats.controller == player, "DebugStatsUI should bind to the player controller.")
	_assert(debug_stats.speed_label != null, "DebugStatsUI should resolve SpeedLabel locally.")
	_assert(debug_stats.velocity_label != null, "DebugStatsUI should resolve VelocityLabel locally.")
	_assert(debug_stats.load_label != null, "DebugStatsUI should resolve LoadLabel locally.")
	_assert(debug_stats.weight_label != null, "DebugStatsUI should resolve WeightLabel locally.")

	world.queue_free()
	await process_frame

func _test_attachment_modifier_flow() -> void:
	var player := PLAYER_SCENE.instantiate() as CharacterController
	root.add_child(player)
	await process_frame

	var inventory := player.get_inventory_component()
	var belt := ItemInstance.create_from_definition(TEST_BELT, 1)
	var vest := ItemInstance.create_from_definition(TEST_VEST, 1)
	var pouch := ItemInstance.create_from_definition(TEST_POUCH, 1)

	_assert(inventory.attach_item(belt, "belt"), "Belt should attach to waist root node.")
	_assert(inventory.get_attachment_node("belt").get("item", null) == belt, "Belt root node should now be occupied.")
	_assert(not inventory.get_attachment_children("belt").is_empty(), "Belt should contribute child attachment nodes.")
	_assert(inventory.can_attach_item(pouch, "belt_slot_01"), "Pouch should be accepted by belt attachment nodes.")
	_assert(inventory.attach_item(pouch, "belt_slot_01"), "Pouch should attach to a belt child node.")

	_assert(inventory.attach_item(vest, "torso"), "Vest should attach to torso.")
	_assert(inventory.get_attachment_node("vest_pouch_left").get("node_id", "") == "vest_pouch_left", "Vest should contribute its left pouch node.")
	_assert(not inventory.can_attach_item(ItemInstance.create_from_definition(TEST_WEAPON, 1), "vest_pouch_left"), "Weapon should be rejected from vest medical/pouch node.")

	player.queue_free()
	await process_frame

func _test_storage_capacity_flow() -> void:
	var player := PLAYER_SCENE.instantiate() as CharacterController
	root.add_child(player)
	await process_frame

	var inventory := player.get_inventory_component()
	var pouch := ItemInstance.create_from_definition(TEST_POUCH, 1)
	var medical_a := ItemInstance.create_from_definition(TEST_MEDICAL, 1)
	var medical_b := ItemInstance.create_from_definition(TEST_MEDICAL, 1)
	var weapon := ItemInstance.create_from_definition(TEST_WEAPON, 1)

	_assert(inventory.attach_item(ItemInstance.create_from_definition(TEST_BELT, 1), "belt"), "Storage test requires an equipped belt.")
	_assert(inventory.attach_item(pouch, "belt_slot_01"), "Pouch should mount on the belt for storage test.")
	_assert(inventory.store_item_in_container(medical_a, pouch.instance_id), "Pouch should accept a size-1 medical item.")
	_assert(inventory.store_item_in_container(medical_b, pouch.instance_id), "Pouch should accept another size-1 medical item.")
	_assert(not inventory.store_item_in_container(weapon, pouch.instance_id), "Pouch capacity 3 should reject a size-3 weapon after storing two size-1 items.")
	_assert(inventory.get_storage_usage(pouch.instance_id) == 2, "Pouch storage usage should report used size units.")
	_assert(inventory.get_storage_capacity(pouch.instance_id) == 3, "Pouch storage capacity should report authored size units.")

	var backpack := ItemInstance.create_from_definition(TEST_BACKPACK, 1)
	_assert(inventory.attach_item(backpack, "back_mount"), "Backpack should mount on back.")
	_assert(inventory.store_item_in_container(weapon, backpack.instance_id), "Backpack should accept a size-3 weapon.")

	player.queue_free()
	await process_frame

func _test_visual_attachment_flow() -> void:
	var player := PLAYER_SCENE.instantiate() as CharacterController
	root.add_child(player)
	await process_frame

	var inventory := player.get_inventory_component()
	var visuals := player.visuals_component
	var belt := ItemInstance.create_from_definition(TEST_BELT, 1)
	var pouch := ItemInstance.create_from_definition(TEST_POUCH, 1)

	_assert(inventory.attach_item(belt, "belt"), "Visual test requires equipped belt.")
	_assert(inventory.attach_item(pouch, "belt_slot_01"), "Visual test requires attached pouch.")
	await process_frame

	var positions := visuals.get_attachment_point_world_positions()
	_assert(positions.has("belt_slot_01"), "VisualsComponent should expose contributed attachment-node world positions.")

	var belt_visual := visuals.get_active_visual("belt", belt.instance_id)
	_assert(belt_visual != null, "Belt should create a runtime visual entry.")

	inventory.drop_item(belt.instance_id)
	await process_frame
	_assert(not inventory.attachment_graph.has_node("belt_slot_01"), "Dropping host equipment should remove contributed child nodes.")

	player.queue_free()
	await process_frame

func _test_serialization_flow() -> void:
	var player := PLAYER_SCENE.instantiate() as CharacterController
	root.add_child(player)
	await process_frame

	var inventory := player.get_inventory_component()
	var belt := ItemInstance.create_from_definition(TEST_BELT, 1)
	var pouch := ItemInstance.create_from_definition(TEST_POUCH, 1)
	var medical := ItemInstance.create_from_definition(TEST_MEDICAL, 1)

	_assert(inventory.attach_item(belt, "belt"), "Serialization test requires a belt.")
	_assert(inventory.attach_item(pouch, "belt_slot_01"), "Serialization test requires a pouch.")
	_assert(inventory.store_item_in_container(medical, pouch.instance_id), "Serialization test requires pouch contents.")

	var snapshot := inventory.serialize()
	inventory.clear()
	inventory.deserialize(snapshot)

	_assert(inventory.get_attachment_node("belt").get("occupant_item_id", "") != "", "Deserialization should restore belt occupancy.")
	_assert(inventory.attachment_graph.has_node("belt_slot_01"), "Deserialization should restore contributed attachment nodes.")

	player.queue_free()
	await process_frame

func _test_tuner_recursive_scan() -> void:
	var tuner := TUNER_SCENE.instantiate()
	root.add_child(tuner)
	await process_frame

	var controller = tuner.get_node("TunerController")
	_assert(controller != null, "CharacterTuner scene should expose TunerController.")
	if controller != null:
		_assert(controller.active_slots.has("belt_slot_01"), "CharacterTuner should expose modifier-contributed attachment nodes.")
		_assert(_contains_definition(controller.get_items_for_slot("belt_slot_01"), "simple_pouch"), "CharacterTuner should list compatible dynamic-node items.")

		var found_nested := false
		for definition in controller.all_items:
			if definition != null and definition.id == "nested_tuner_medical":
				found_nested = true
				break
		_assert(found_nested, "CharacterTuner should discover nested item definitions recursively.")

	tuner.queue_free()
	await process_frame

func _assert(condition: bool, message: String) -> void:
	if condition:
		return

	failure_count += 1
	push_error(message)

func _contains_definition(definitions: Array, definition_id: String) -> bool:
	for definition in definitions:
		if definition != null and definition.id == definition_id:
			return true
	return false
