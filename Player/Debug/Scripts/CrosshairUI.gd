extends Control
class_name CrosshairUI

var style_profile: UIStyleProfile
var focus_active: bool = false
var cursor_mode: bool = false

var center_rect: ColorRect
var top_bar: ColorRect
var right_bar: ColorRect
var bottom_bar: ColorRect
var left_bar: ColorRect
var outer_frame: ColorRect

var _cursor_tween: Tween

var _orig_top_pos: Vector2
var _orig_top_size: Vector2
var _orig_right_pos: Vector2
var _orig_right_size: Vector2
var _orig_bottom_pos: Vector2
var _orig_bottom_size: Vector2
var _orig_left_pos: Vector2
var _orig_left_size: Vector2
var _orig_anchors: Dictionary
var _orig_offsets: Dictionary
func _ready() -> void:
	center_rect = get_node_or_null("ColorRect") as ColorRect
	top_bar = get_node_or_null("TopBar") as ColorRect
	right_bar = get_node_or_null("RightBar") as ColorRect
	bottom_bar = get_node_or_null("BottomBar") as ColorRect
	left_bar = get_node_or_null("LeftBar") as ColorRect
	outer_frame = get_node_or_null("OuterFrame") as ColorRect
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if top_bar: _orig_top_pos = top_bar.position; _orig_top_size = top_bar.size
	if right_bar: _orig_right_pos = right_bar.position; _orig_right_size = right_bar.size
	if bottom_bar: _orig_bottom_pos = bottom_bar.position; _orig_bottom_size = bottom_bar.size
	if left_bar: _orig_left_pos = left_bar.position; _orig_left_size = left_bar.size

func _process(_delta: float) -> void:
	if cursor_mode:
		global_position = get_global_mouse_position()

func set_cursor_mode(is_active: bool) -> void:
	if cursor_mode == is_active:
		return
	cursor_mode = is_active
	
	if is_active:
		_orig_anchors = {"l": anchor_left, "t": anchor_top, "r": anchor_right, "b": anchor_bottom}
		_orig_offsets = {"l": offset_left, "t": offset_top, "r": offset_right, "b": offset_bottom}
		# Ensure the crosshair ignores layout anchors while following mouse
		set_anchors_preset(Control.PRESET_TOP_LEFT)
	else:
		anchor_left = _orig_anchors.get("l", 0.5)
		anchor_top = _orig_anchors.get("t", 0.5)
		anchor_right = _orig_anchors.get("r", 0.5)
		anchor_bottom = _orig_anchors.get("b", 0.5)
		offset_left = _orig_offsets.get("l", -16)
		offset_top = _orig_offsets.get("t", -16)
		offset_right = _orig_offsets.get("r", 16)
		offset_bottom = _orig_offsets.get("b", 16)
		
	if _cursor_tween:
		_cursor_tween.kill()
		
	_cursor_tween = create_tween()
	_cursor_tween.set_trans(Tween.TRANS_QUAD)
	_cursor_tween.set_ease(Tween.EASE_OUT)
	_cursor_tween.set_parallel(true)
	
	if is_active:
		# Animate to square pattern (4 dots)
		if center_rect: _cursor_tween.tween_property(center_rect, "modulate:a", 0.0, 0.2)
		if outer_frame: _cursor_tween.tween_property(outer_frame, "modulate:a", 0.0, 0.2)
		
		# Move bars into 4 dots
		if top_bar: 
			_cursor_tween.tween_property(top_bar, "position", Vector2(-6, -6), 0.2)
			_cursor_tween.tween_property(top_bar, "size", Vector2(4, 4), 0.2)
		if right_bar:
			_cursor_tween.tween_property(right_bar, "position", Vector2(2, -6), 0.2)
			_cursor_tween.tween_property(right_bar, "size", Vector2(4, 4), 0.2)
		if bottom_bar:
			_cursor_tween.tween_property(bottom_bar, "position", Vector2(2, 2), 0.2)
			_cursor_tween.tween_property(bottom_bar, "size", Vector2(4, 4), 0.2)
		if left_bar:
			_cursor_tween.tween_property(left_bar, "position", Vector2(-6, 2), 0.2)
			_cursor_tween.tween_property(left_bar, "size", Vector2(4, 4), 0.2)
	else:
		# Return to normal line pattern
		if center_rect: _cursor_tween.tween_property(center_rect, "modulate:a", 1.0, 0.2)
		if outer_frame: _cursor_tween.tween_property(outer_frame, "modulate:a", 1.0, 0.2)
		
		if top_bar: 
			_cursor_tween.tween_property(top_bar, "position", _orig_top_pos, 0.2)
			_cursor_tween.tween_property(top_bar, "size", _orig_top_size, 0.2)
		if right_bar:
			_cursor_tween.tween_property(right_bar, "position", _orig_right_pos, 0.2)
			_cursor_tween.tween_property(right_bar, "size", _orig_right_size, 0.2)
		if bottom_bar:
			_cursor_tween.tween_property(bottom_bar, "position", _orig_bottom_pos, 0.2)
			_cursor_tween.tween_property(bottom_bar, "size", _orig_bottom_size, 0.2)
		if left_bar:
			_cursor_tween.tween_property(left_bar, "position", _orig_left_pos, 0.2)
			_cursor_tween.tween_property(left_bar, "size", _orig_left_size, 0.2)


func apply_style(style: UIStyleProfile) -> void:
	style_profile = style
	_apply_palette()

func set_focus_active(is_active: bool) -> void:
	focus_active = is_active
	_apply_palette()

func _apply_palette() -> void:
	if style_profile == null:
		return

	var active_color := style_profile.get_accent_color() if focus_active else style_profile.primary_text_color
	for node in [center_rect, top_bar, right_bar, bottom_bar, left_bar]:
		if node != null:
			node.color = active_color

	if outer_frame != null:
		outer_frame.visible = style_profile.uses_high_tier()
		outer_frame.color = style_profile.make_rule_color(1.2)
