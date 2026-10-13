extends Node3D
class_name CharacterRigAssembly

@export var imported_model_path: NodePath = NodePath("ImportedModel")

var _skeleton: Skeleton3D

func _ready() -> void:
	var imported := get_node_or_null(imported_model_path) as Node3D
	if imported == null:
		push_error("CharacterRigAssembly: ImportedModel not found at path '%s'." % imported_model_path)
		return

	_skeleton = _find_skeleton(imported)
	if _skeleton == null:
		push_error("CharacterRigAssembly: Could not resolve Skeleton3D in ImportedModel.")
		return

	_create_runtime_nodes()

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child) as Skeleton3D
		if found != null:
			return found
	return null

func _create_runtime_nodes() -> void:
	# The gameplay IK stack and WeaponRoot are player-owned. When this rig
	# module is mounted without a CharacterBody3D host (e.g. the Character
	# Tuner authoring context) they are intentionally not built.
	if _find_ancestor(self, "CharacterBody3D") == null:
		return
	# Order: dependencies first, dependents last.
	# _ready() fires immediately on add_child(), so siblings referenced
	# via get_node("../Name") must already exist in the Skeleton3D.
	_create_ccdik()
	_create_look_at_target()
	_create_right_arm_ik()
	_create_left_arm_ik()
	_create_head_ccdik()
	_create_spine_look_at_controller()
	_create_full_body_ik_controller()
	_reorder_modifiers()
	_create_weapon_root()

func _create_look_at_target() -> void:
	var target := Node3D.new()
	target.name = "LookAtTarget"
	_skeleton.add_child(target)

	var mesh := MeshInstance3D.new()
	mesh.name = "TargetMesh"
	var sphere := SphereMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.0, 0.7, 0.0, 1.0)
	sphere.material = mat
	mesh.mesh = sphere
	mesh.scale = Vector3(0.25, 0.25, 0.25)
	target.add_child(mesh)

func _create_spine_look_at_controller() -> void:
	var slc := SpineLookAtController.new()
	slc.name = "SpineLookAtController"
	slc.character_controller_path = NodePath("../../../../../..")
	slc.aim_controller_path = NodePath("../../../../../../AimController")
	slc.look_at_target_path = NodePath("../LookAtTarget")
	slc.weapon_root_path = NodePath("../../../../../../WeaponRoot")
	slc.arc_radius = 2.0
	_skeleton.add_child(slc)

func _create_ccdik() -> void:
	var ccdik := CCDIK3D.new()
	ccdik.name = "CCDIK"
	_skeleton.add_child(ccdik)

func _create_full_body_ik_controller() -> void:
	var fbik := FullBodyIKController.new()
	fbik.name = "FullBodyIKController"
	fbik.aim_controller_path = NodePath("../../../../../../AimController")
	fbik.visuals_component_path = NodePath("../../../../..")
	fbik.character_controller_path = NodePath("../../../../../..")
	fbik.aim_target_path = NodePath("../../../../AimIKTarget")
	fbik.right_hand_target_path = NodePath("../../../../RightHandIKTarget")
	fbik.left_hand_target_path = NodePath("../../../../LeftHandIKTarget")
	_skeleton.add_child(fbik)

func _create_right_arm_ik() -> void:
	var ik := TwoBoneIK3D.new()
	ik.name = "RightArmIK"
	_skeleton.add_child(ik)

func _create_left_arm_ik() -> void:
	var ik := TwoBoneIK3D.new()
	ik.name = "LeftArmIK"
	_skeleton.add_child(ik)

func _create_head_ccdik() -> void:
	var ik := CCDIK3D.new()
	ik.name = "HeadCCDIK"
	ik.min_distance = 0.01
	_skeleton.add_child(ik)

## Reorders skeleton children so FullBodyIKController runs BEFORE
## RightArmIK/LeftArmIK in the modifier pipeline. Godot executes
## SkeletonModifier3D._process_modification_with_delta() in child-tree
## order. FBIK must set hand targets before arm IK solves.
func _reorder_modifiers() -> void:
	var fbik := _skeleton.get_node_or_null("FullBodyIKController")
	var right_arm_ik := _skeleton.get_node_or_null("RightArmIK")
	if fbik != null and right_arm_ik != null:
		var fbik_idx := _skeleton.get_children().find(fbik)
		var right_arm_idx := _skeleton.get_children().find(right_arm_ik)
		if fbik_idx > right_arm_idx:
			_skeleton.move_child(fbik, right_arm_idx)

func _create_weapon_root() -> void:
	var character_body := _find_ancestor(self, "CharacterBody3D") as Node3D
	if character_body == null:
		# No player host (e.g. the CharacterTuner reuses this rig module for
		# authoring). The WeaponRoot/WeaponController belong to the player
		# context only, so their absence here is expected, not an error.
		return
	_deferred_weapon_root_setup.call_deferred(character_body)

func _deferred_weapon_root_setup(character_body: Node3D) -> void:
	var weapon_root := Node3D.new()
	weapon_root.name = "WeaponRoot"
	character_body.add_child(weapon_root)
	weapon_root.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else null

	var controller := WeaponController.new()
	controller.name = "WeaponController"
	controller.aim_controller_path = NodePath("../../AimController")
	controller.fullbody_ik_path = NodePath("../../VisualsComponent/Rig/ImportedModel/Armature/Skeleton3D/FullBodyIKController")
	controller.visuals_component_path = NodePath("../../VisualsComponent")
	weapon_root.add_child(controller)
	controller.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else null

## Walks up from [param start] to find the first ancestor whose name
## matches [param ancestor_name]. Returns null if not found.
func _find_ancestor(start: Node, ancestor_name: String) -> Node:
	var node := start.get_parent()
	while node != null:
		if node.name == ancestor_name:
			return node
		node = node.get_parent()
	return null
