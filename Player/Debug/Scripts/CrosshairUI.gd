extends Control
class_name CrosshairUI

var style_profile: UIStyleProfile
var focus_active: bool = false

var center_rect: ColorRect
var top_bar: ColorRect
var right_bar: ColorRect
var bottom_bar: ColorRect
var left_bar: ColorRect
var outer_frame: ColorRect

func _ready() -> void:
	center_rect = get_node_or_null("ColorRect") as ColorRect
	top_bar = get_node_or_null("TopBar") as ColorRect
	right_bar = get_node_or_null("RightBar") as ColorRect
	bottom_bar = get_node_or_null("BottomBar") as ColorRect
	left_bar = get_node_or_null("LeftBar") as ColorRect
	outer_frame = get_node_or_null("OuterFrame") as ColorRect
	mouse_filter = Control.MOUSE_FILTER_IGNORE

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
