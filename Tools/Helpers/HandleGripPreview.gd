@tool
extends Node3D
class_name HandleGripPreview

# ============================================================
#  HANDLE GRIP PREVIEW (Editor Tool)
# ============================================================
## Add this as a child of a Handle Marker3D inside an equipped
## weapon scene.  It renders a stylised ghost-hand in the
## editor so you can see exactly how the character's grip will
## land on the weapon — no need to run the game to check.
##
## All geometry is created/destroyed at editor time only.
## At runtime the node is simply invisible; no overhead.
##
## Usage:
##   1. Open e.g. weaponSceneEquipped.tscn
##   2. Select the Handle Marker3D node
##   3. Attach this script as a child Node3D (name it anything)
##   4. Assign a TunerRigPreset to see the actual character rig aligned to the handle
##   5. Move/rotate the Handle until the ghost hand lines up with your weapon's grip geometry
##   6. Save the scene — the preview is already stripped at runtime
## ============================================================

# Which hand pose to draw.  Flip for left-hand grips.
enum HandSide { RIGHT, LEFT }

@export var hand_side: HandSide = HandSide.RIGHT:
	set(v):
		hand_side = v
		_rebuild()

## Overall opacity of the ghost (0 = invisible, 1 = solid).
@export_range(0.0, 1.0) var ghost_opacity: float = 0.5:
	set(v):
		ghost_opacity = v
		_rebuild()

## Tint colour of the ghost hand.
@export var ghost_color: Color = Color(0.6, 0.85, 1.0, 1.0):
	set(v):
		ghost_color = v
		_rebuild()

## If true the preview shows, if false it hides without deletion.
@export var preview_visible: bool = true:
	set(v):
		preview_visible = v
		_apply_visibility()

## If the rig's weapon_socket bone is inherently turned (e.g. 90 degrees), 
## use this offset to match the bone's true local orientation.
@export var preview_rotation_offset: Vector3 = Vector3(0, 0, 0):
	set(v):
		preview_rotation_offset = v
		_rebuild()

## Optional: A TunerRigPreset to instance. If assigned, the preview will 
## load the actual character rig and precisely align its weapon socket 
## to the Handle node, providing a 100% accurate representation.
@export var rig_preset: Resource: # TunerRigPreset
	set(v):
		rig_preset = v
		_rebuild()

# ── Internal ──────────────────────────────────────────────────
var _root: Node3D   # holds all generated MeshInstance3D nodes

func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild()
	else:
		hide()        # completely invisible at runtime

func _notification(what: int) -> void:
	# Keep the preview alive when the editor replaces the scene
	if Engine.is_editor_hint() and what == NOTIFICATION_POSTINITIALIZE:
		_rebuild()

# ── Build ─────────────────────────────────────────────────────

func _rebuild() -> void:
	if not Engine.is_editor_hint():
		return
	_clear()
	_root = Node3D.new()
	_root.name = "__GhostHand__"
	# Apply the rotation offset to the root of the ghost hand
	_root.rotation_degrees = preview_rotation_offset
	add_child(_root)
	_build_hand()
	_apply_visibility()

func _clear() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	_root = null

func _apply_visibility() -> void:
	if is_instance_valid(_root):
		_root.visible = preview_visible

# ── Geometry ──────────────────────────────────────────────────

## Shared material; recreated whenever colour or opacity changes.
func _make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(ghost_color.r, ghost_color.g, ghost_color.b, ghost_opacity)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _add_box(parent: Node3D, pos: Vector3, rot_deg: Vector3,
		size: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)

func _add_capsule(parent: Node3D, pos: Vector3, rot_deg: Vector3,
		radius: float, height: float, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)

# ── Hand Layout ───────────────────────────────────────────────
## All measurements are approximate / stylised; tweak freely.
##
## Coordinate convention (local to the Handle Marker3D):
##   The wrist arrives FROM ABOVE (-Y pointing toward forearm).
##   The palm faces in the +Y direction (back of hand = -Y).
##   The fingers point in the +Z direction (toward the barrel).
##   X is lateral; mirrored for LEFT hand.

func _build_hand() -> void:
	if rig_preset != null and rig_preset.get("rig_scene") != null:
		_build_rig_hand()
	else:
		_build_stylised_hand()

func _build_rig_hand() -> void:
	var rig_scene := rig_preset.get("rig_scene") as PackedScene
	if rig_scene == null:
		_build_stylised_hand()
		return
		
	var rig_instance := rig_scene.instantiate() as Node3D
	_root.add_child(rig_instance)
	
	var skeleton := _find_skeleton_recursive(rig_instance)
	if skeleton == null:
		push_warning("[HandleGripPreview] Rig scene has no Skeleton3D.")
		rig_instance.queue_free()
		_build_stylised_hand()
		return
		
	var bone_name := "weapon_socket_r" if hand_side == HandSide.RIGHT else "weapon_socket_l"
	var bone_idx := skeleton.find_bone(bone_name)
	
	if bone_idx == -1:
		push_warning("[HandleGripPreview] Skeleton missing bone: " + bone_name)
		rig_instance.queue_free()
		_build_stylised_hand()
		return

	# Apply ghost material to the rig
	var mat := _make_material()
	_apply_ghost_material(rig_instance, mat)
	
	# Compute the bone's transform relative to the rig_instance root.
	# bone_pose is local to the skeleton. We need it local to rig_instance.
	var bone_to_rig := _get_relative_transform(rig_instance, skeleton) * skeleton.get_bone_global_pose(bone_idx)
	
	# To place the bone exactly at the preview root (0,0,0), we invert the offset.
	rig_instance.transform = bone_to_rig.affine_inverse()

func _find_skeleton_recursive(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found = _find_skeleton_recursive(child)
		if found:
			return found
	return null

func _get_relative_transform(root: Node3D, target: Node3D) -> Transform3D:
	var t := Transform3D()
	var current := target
	while current != null and current != root:
		t = current.transform * t
		current = current.get_parent() as Node3D
	return t

func _apply_ghost_material(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_ghost_material(child, mat)

func _build_stylised_hand() -> void:
	var mat := _make_material()
	var mirror: float = -1.0 if hand_side == HandSide.LEFT else 1.0

	# ── Palm ──────────────────────────────────────────────────
	# Centred at the Handle origin; the bone sits here.
	_add_box(_root,
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.082, 0.026, 0.075),
		mat)

	# ── Wrist ─────────────────────────────────────────────────
	# Slightly behind the palm (-Z) and the forearm connects upward (-Y)
	_add_box(_root,
		Vector3(0.0, -0.012, -0.048),
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.068, 0.024, 0.040),
		mat)

	# ── Thumb ─────────────────────────────────────────────────
	# Lateral side, angled slightly toward the barrel (+Z)
	var thumb_x := 0.045 * mirror
	_add_capsule(_root,
		Vector3(thumb_x, 0.008, -0.022),
		Vector3(0.0, 0.0, 75.0 * mirror),
		0.012, 0.048,
		mat)
	# Thumb tip
	_add_capsule(_root,
		Vector3(thumb_x * 1.35, 0.012, 0.006),
		Vector3(0.0, 0.0, 60.0 * mirror),
		0.010, 0.032,
		mat)

	# ── Index finger ──────────────────────────────────────────
	var index_x := 0.028 * mirror
	_add_capsule(_root,
		Vector3(index_x, 0.0, 0.058),
		Vector3(90.0, 0.0, 0.0),
		0.010, 0.052,
		mat)

	# ── Middle finger ─────────────────────────────────────────
	var middle_x := 0.008 * mirror
	_add_capsule(_root,
		Vector3(middle_x, 0.0, 0.062),
		Vector3(90.0, 0.0, 0.0),
		0.011, 0.056,
		mat)

	# ── Ring finger ───────────────────────────────────────────
	var ring_x := -0.012 * mirror
	_add_capsule(_root,
		Vector3(ring_x, 0.0, 0.058),
		Vector3(90.0, 0.0, 0.0),
		0.010, 0.050,
		mat)

	# ── Pinky ─────────────────────────────────────────────────
	var pinky_x := -0.030 * mirror
	_add_capsule(_root,
		Vector3(pinky_x, 0.0, 0.052),
		Vector3(90.0, 0.0, 0.0),
		0.009, 0.040,
		mat)

	# ── Forward axis indicator ────────────────────────────────
	# A thin cyan rod pointing toward the barrel (+Z) so you can
	# eyeball barrel alignment without needing another gizmo.
	var arrow_mat := StandardMaterial3D.new()
	arrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow_mat.albedo_color = Color(0.0, 1.0, 0.9, 0.9)
	var arrow_mi := MeshInstance3D.new()
	var arrow_box := BoxMesh.new()
	arrow_box.size = Vector3(0.004, 0.004, 0.12)
	arrow_mi.mesh = arrow_box
	arrow_mi.material_override = arrow_mat
	arrow_mi.position = Vector3(0.0, 0.014, 0.085)
	_root.add_child(arrow_mi)
