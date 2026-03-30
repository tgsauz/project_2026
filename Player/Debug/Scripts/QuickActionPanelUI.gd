extends Panel
class_name QuickActionPanelUI

var style_profile: UIStyleProfile

var accent_bar: ColorRect
var title_label: Label
var actions_container: VBoxContainer
var divider: ColorRect
var footer_label: Label

func _ready() -> void:
	accent_bar = get_node_or_null("AccentBar") as ColorRect
	title_label = get_node_or_null("MarginContainer/VBoxContainer/TitleLabel") as Label
	actions_container = get_node_or_null("MarginContainer/VBoxContainer/ActionsLabel") as VBoxContainer
	divider = get_node_or_null("MarginContainer/VBoxContainer/Divider") as ColorRect
	footer_label = get_node_or_null("MarginContainer/VBoxContainer/FooterLabel") as Label
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func apply_style(style: UIStyleProfile) -> void:
	style_profile = style
	add_theme_stylebox_override("panel", style_profile.make_panel_style("elevated"))
	if accent_bar != null:
		accent_bar.color = style_profile.get_accent_color()
	if title_label != null:
		title_label.label_settings = style_profile.make_label_settings("title")
		title_label.uppercase = true
	if footer_label != null:
		footer_label.label_settings = style_profile.make_label_settings("meta")
		footer_label.uppercase = true
	if divider != null:
		divider.color = style_profile.make_rule_color(2.0)

func set_actions(prompt_data: Dictionary, actions: Array, selected_index: int, is_open: bool) -> void:
	visible = is_open
	if not is_open:
		_clear_action_rows()
		if title_label != null:
			title_label.text = ""
		return

	if title_label != null:
		title_label.text = str(prompt_data.get("title", "Actions")).to_upper()
	if footer_label != null:
		footer_label.text = "F / ENTER EXECUTE    Q CLOSE"

	_clear_action_rows()
	for action_index in range(actions.size()):
		var action: Dictionary = actions[action_index]
		var row := Label.new()
		row.clip_text = true
		row.text = "%s %s" % [
			">" if action_index == selected_index else "-",
			str(action.get("label", "")).to_upper()
		]
		if style_profile != null:
			row.label_settings = style_profile.make_label_settings("selected" if action_index == selected_index else "body")
		actions_container.add_child(row)

func _clear_action_rows() -> void:
	if actions_container == null:
		return
	for child in actions_container.get_children():
		child.queue_free()
