extends SceneTree

const PLAYER_SCENE := preload("res://Player/PlayerCharacter.tscn")
const WORLD_SCENE := preload("res://World/testing_world.tscn")
const TEST_ITEM := preload("res://World/Items/SquareItem.tres")

var failure_count := 0

# ============================================================
#  ENTRYPOINT
# ============================================================

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_player_scene_boot()
	await _test_world_scene_boot()
	await _test_interaction_flow()

	if failure_count > 0:
		push_error("Dependency smoke tests failed with %d issue(s)." % failure_count)
		quit(1)
		return

	print("Dependency smoke tests passed.")
	quit(0)

# ============================================================
#  TESTS
# ============================================================

func _test_player_scene_boot() -> void:
	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame

	_assert(player is CharacterController, "Player root should use CharacterController.")
	_assert(player.get_inventory_component() != null, "CharacterController should resolve InventoryComponent.")
	_assert(player.interaction != null, "CharacterController should resolve InteractionComponent.")
	_assert(player.animation_tree != null and player.animation_tree.active, "CharacterController should resolve and activate AnimationTree.")
	_assert(player.camera_controller != null, "CharacterController should resolve CameraController.")
	_assert(player.visuals_component != null, "CharacterController should resolve VisualsComponent.")

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

func _test_interaction_flow() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)

	var player := PLAYER_SCENE.instantiate() as CharacterController
	world_root.add_child(player)
	await process_frame
	await physics_frame

	var camera := player.get_node("Visuals/Rig/CAMERARIG/FPSPIVOT/FPSCAMERA") as Camera3D
	var interaction := player.interaction
	var inventory := player.get_inventory_component()

	_assert(camera != null, "Smoke interaction test requires FPS camera.")
	_assert(interaction != null, "Smoke interaction test requires InteractionComponent.")
	_assert(inventory != null, "Smoke interaction test requires InventoryComponent.")

	var item := WorldItem.new()
	item.item_resource = TEST_ITEM
	item.consume_on_interact = false
	item.freeze = true

	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.5, 0.5, 0.5)
	collision_shape.shape = box_shape
	item.add_child(collision_shape)

	world_root.add_child(item)
	item.global_position = camera.global_position + (-camera.global_basis.z * 2.0)

	await physics_frame

	var initial_weight := inventory.get_total_weight()
	interaction.set_camera(camera)
	interaction.call("_update_focus")
	interaction.try_interact()

	_assert(interaction.current_item == item, "InteractionComponent should focus the spawned WorldItem.")
	_assert(inventory.get_total_weight() > initial_weight, "Interacting should add item weight to inventory.")

	world_root.queue_free()
	await process_frame

# ============================================================
#  ASSERTIONS
# ============================================================

func _assert(condition: bool, message: String) -> void:
	if condition:
		return

	failure_count += 1
	push_error(message)
