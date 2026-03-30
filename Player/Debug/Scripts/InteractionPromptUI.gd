extends Control
class_name InteractionPromptUI

var style_profile: UIStyleProfile

var panel: Panel
var accent_bar: ColorRect
var name_label: Label
var tooltip_label: Label
var connector_line: Line2D

func _ready() -> void:
	panel = get_node_or_null("Panel") as Panel
	accent_bar = get_node_or_null("Panel/AccentBar") as ColorRect
	name_label = get_node_or_null("Panel/MarginContainer/VBoxContainer/NameLabel") as Label
	tooltip_label = get_node_or_null("Panel/MarginContainer/VBoxContainer/TooltipLabel") as Label
	connector_line = get_node_or_null("Line2D") as Line2D
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_connector()

func apply_style(style: UIStyleProfile) -> void:
	style_profile = style
	if panel != null:
		panel.add_theme_stylebox_override("panel", style_profile.make_panel_style("default"))
	if accent_bar != null:
		accent_bar.color = style_profile.get_accent_color()
	if name_label != null:
		name_label.label_settings = style_profile.make_label_settings("title")
		name_label.uppercase = true
	if tooltip_label != null:
		tooltip_label.label_settings = style_profile.make_label_settings("body")
		tooltip_label.uppercase = true
	if connector_line != null:
		connector_line.width = max(1.0, float(style_profile.line_thickness - 1))
		connector_line.default_color = style_profile.make_rule_color(1.6)
		connector_line.visible = style_profile.uses_high_tier()
	_update_connector()

func set_prompt_data(prompt_data: Dictionary) -> void:
	var has_prompt := not prompt_data.is_empty()
	visible = has_prompt
	if not has_prompt:
		if name_label != null:
			name_label.text = ""
		if tooltip_label != null:
			tooltip_label.text = ""
		return

	if name_label != null:
		name_label.text = str(prompt_data.get("title", "")).to_upper()

	var prompt_segments: Array[String] = []
	var interact_label := str(prompt_data.get("interact_label", ""))
	var quick_action_label := str(prompt_data.get("quick_action_label", ""))
	var tooltip := str(prompt_data.get("tooltip", ""))
	if not interact_label.is_empty():
		prompt_segments.append(interact_label.to_upper())
	if not quick_action_label.is_empty():
		prompt_segments.append(quick_action_label.to_upper())
	if not tooltip.is_empty():
		prompt_segments.append(tooltip.to_upper())

	if tooltip_label != null:
		tooltip_label.text = "  //  ".join(prompt_segments)

	_update_connector()

func _update_connector() -> void:
	if connector_line == null:
		return
	connector_line.clear_points()
	if not visible:
		return

	var bottom_left := Vector2(0.0, size.y - 10.0)
	var knee := Vector2(26.0, size.y - 14.0)
	var panel_entry := Vector2(26.0, 16.0)
	connector_line.add_point(bottom_left)
	connector_line.add_point(knee)
	connector_line.add_point(panel_entry)
