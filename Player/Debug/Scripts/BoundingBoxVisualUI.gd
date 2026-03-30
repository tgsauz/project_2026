extends Control
class_name BoundingBoxVisualUI

# ============================================================
# DESCRIPTION
# ============================================================
# Projects 3D target bounds as a screen-space outline.
# Works with interaction target updates from UIRoot.
# Supports tier gating via UIStyleProfile.bounding_box_enabled.
# ============================================================

var style_profile: UIStyleProfile
var tracked_target: Node = null
var tracking_camera: Camera3D = null

@export var box_color: Color = Color(0.2, 0.78, 0.95, 0.75)
@export var line_width: float = 2.0
@export var offscreen_alpha: float = 0.25

var debug_line: Line2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	anchors_preset = Control.PRESET_FULL_RECT
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	set_process(true)

	debug_line = Line2D.new()
	debug_line.width = line_width
	debug_line.default_color = box_color
	debug_line.z_index = 1000
	add_child(debug_line)

func apply_style(style: UIStyleProfile) -> void:
	style_profile = style
	# Color tinting API changed in Godot 4.x; avoid unsupported method.
	var raw_accent = style_profile.get_accent_color()
	box_color = Color(raw_accent.r, raw_accent.g, raw_accent.b, raw_accent.a * 0.75)
	if debug_line != null:
		debug_line.default_color = box_color
		debug_line.width = max(1.0, float(style_profile.line_thickness))

func set_target(target: Node) -> void:
	tracked_target = target
	visible = tracked_target != null and style_profile != null and style_profile.is_bounding_box_supported()

func _process(_delta: float) -> void:
	if not style_profile or not style_profile.is_bounding_box_supported():
		visible = false
		return

	if tracked_target == null or not is_instance_valid(tracked_target):
		visible = false
		return

	if tracking_camera == null:
		tracking_camera = get_viewport().get_camera_3d()
		if tracking_camera == null:
			visible = false
			return

	var world_corners: Array[Vector3] = []
	if tracked_target is Node3D:
		var nd = tracked_target as Node3D
		if nd.has_method("get_aabb"):
			var local_aabb: AABB = nd.get_aabb()
			var local_corners = [
				local_aabb.position,
				local_aabb.position + Vector3(local_aabb.size.x, 0, 0),
				local_aabb.position + Vector3(local_aabb.size.x, local_aabb.size.y, 0),
				local_aabb.position + Vector3(0, local_aabb.size.y, 0),
				local_aabb.position + Vector3(0, 0, local_aabb.size.z),
				local_aabb.position + Vector3(local_aabb.size.x, 0, local_aabb.size.z),
				local_aabb.position + Vector3(local_aabb.size.x, local_aabb.size.y, local_aabb.size.z),
				local_aabb.position + Vector3(0, local_aabb.size.y, local_aabb.size.z)
			]
			for lc in local_corners:
				world_corners.append(nd.global_transform.xform(lc))
		else:
			var fallback_world = nd.global_transform.origin
			world_corners = [
				fallback_world + Vector3(-0.3, -0.3, -0.3),
				fallback_world + Vector3(0.3, -0.3, -0.3),
				fallback_world + Vector3(0.3, 0.3, -0.3),
				fallback_world + Vector3(-0.3, 0.3, -0.3),
				fallback_world + Vector3(-0.3, -0.3, 0.3),
				fallback_world + Vector3(0.3, -0.3, 0.3),
				fallback_world + Vector3(0.3, 0.3, 0.3),
				fallback_world + Vector3(-0.3, 0.3, 0.3)
			]
	else:
		visible = false
		return

	var proj: Array[Vector2] = []
	var viewport = get_viewport()
	var viewport_size = viewport.get_visible_rect().size
	
	# Godot 4.6 world-to-screen conversion using built-in viewport method
	for corner in world_corners:
		# Use Viewport's built-in camera projection
		# This handles all the matrix math internally and is the stable API
		var screen_pos = viewport.get_camera_3d().unproject_position(corner)
		proj.append(screen_pos)

	if proj.size() == 0:
		visible = false
		return

	var minx = proj[0].x
	var miny = proj[0].y
	var maxx = proj[0].x
	var maxy = proj[0].y
	for p in proj:
		minx = min(minx, p.x)
		miny = min(miny, p.y)
		maxx = max(maxx, p.x)
		maxy = max(maxy, p.y)

	if maxx < 0 or maxy < 0 or minx > viewport_size.x or miny > viewport_size.y:
		visible = false
		return

	visible = true

	# Update rectangle line in screen coords
	debug_line.position = Vector2.ZERO
	debug_line.clear_points()
	debug_line.add_point(Vector2(minx, miny))
	debug_line.add_point(Vector2(maxx, miny))
	debug_line.add_point(Vector2(maxx, maxy))
	debug_line.add_point(Vector2(minx, maxy))
	debug_line.add_point(Vector2(minx, miny))

	if tracked_target.has_method("get_interaction_prompt_data"):
		# Optionally update interaction prompt position if desired
		pass
