extends Control
class_name StatusClusterUI

# ============================================================
# REFERENCES
# ============================================================

var style_profile: UIStyleProfile
var controller: CharacterController
var inventory: InventoryComponent
var fade_controller: UIFadeController
var layout_manager: ResponsiveLayoutManager

var panel: Panel
var header_label: Label
var stamina_value_label: Label
var stamina_bar: ProgressBar
var load_value_label: Label
var load_bar: ProgressBar
var weight_label: Label
var divider: ColorRect

# ============================================================
# CONFIG
# ============================================================

# Anchor position within the screen ("top_left", "top_right", "bottom_left", etc.)
@export var anchor_position: String = "top_right"
@export var use_responsive_layout: bool = true

func _ready() -> void:
	panel = get_node_or_null("Panel") as Panel
	header_label = get_node_or_null("Panel/VBoxContainer/HeaderLabel") as Label
	stamina_value_label = get_node_or_null("Panel/VBoxContainer/StaminaRow/StaminaValueLabel") as Label
	stamina_bar = get_node_or_null("Panel/VBoxContainer/ProgressBar") as ProgressBar
	load_value_label = get_node_or_null("Panel/VBoxContainer/LoadRow/LoadValueLabel") as Label
	load_bar = get_node_or_null("Panel/VBoxContainer/LoadBar") as ProgressBar
	weight_label = get_node_or_null("Panel/VBoxContainer/WeightLabel") as Label
	divider = get_node_or_null("Panel/VBoxContainer/Divider") as ColorRect
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func bind_character(new_character: Node) -> void:
	controller = new_character as CharacterController
	if controller == null:
		inventory = null
		return
	inventory = controller.get_inventory_component()

func apply_style(style: UIStyleProfile) -> void:
	style_profile = style
	
	# Get layout manager from UIRoot
	if layout_manager == null:
		var ui_root = get_node_or_null("/root/UIRoot") as UIRoot
		if ui_root != null:
			layout_manager = ui_root.get_layout_manager()
	
	# Initialize fade controller now that style_profile is set
	if fade_controller == null:
		fade_controller = UIFadeController.new(self, style_profile)
	
	if panel != null:
		panel.add_theme_stylebox_override("panel", style_profile.make_panel_style("default"))
	if header_label != null:
		header_label.label_settings = style_profile.make_label_settings("accent")
		header_label.uppercase = true
	if stamina_value_label != null:
		stamina_value_label.label_settings = style_profile.make_label_settings("body")
		stamina_value_label.uppercase = true
	if load_value_label != null:
		load_value_label.label_settings = style_profile.make_label_settings("body")
		load_value_label.uppercase = true
	if weight_label != null:
		weight_label.label_settings = style_profile.make_label_settings("meta")
		weight_label.uppercase = true
	if divider != null:
		divider.color = style_profile.make_rule_color(1.5)

	_style_progress_bar(stamina_bar, style_profile.get_accent_color())
	_style_progress_bar(load_bar, style_profile.warning_color)

	for path in [
		"Panel/VBoxContainer/StaminaRow/StaminaCaptionLabel",
		"Panel/VBoxContainer/LoadRow/LoadCaptionLabel"
	]:
		var label := get_node_or_null(path) as Label
		if label != null:
			label.label_settings = style_profile.make_label_settings("meta")
			label.uppercase = true
	
	# Apply responsive layout if enabled
	if use_responsive_layout and layout_manager != null:
		_update_responsive_position()

## Called by ResponsiveLayoutManager when breakpoint changes
func on_breakpoint_changed(_new_breakpoint: ResponsiveLayoutManager.Breakpoint) -> void:
	if use_responsive_layout and layout_manager != null:
		_update_responsive_position()

func _process(_delta: float) -> void:
	if controller == null:
		return

	var stamina_ratio := 0.0
	if controller.stamina_max > 0.0:
		stamina_ratio = controller.stamina / controller.stamina_max
	stamina_ratio = clamp(stamina_ratio, 0.0, 1.0)

	if stamina_bar != null:
		stamina_bar.value = stamina_ratio * 100.0
	if stamina_value_label != null:
		stamina_value_label.text = "%.0f%%" % (stamina_ratio * 100.0)

	var load_ratio : float = clamp(controller.load_factor, 0.0, 1.0)
	if load_bar != null:
		load_bar.value = load_ratio * 100.0
	if load_value_label != null:
		load_value_label.text = "%.0f%%" % (load_ratio * 100.0)

	if weight_label != null and inventory != null:
		weight_label.text = "MASS  %.1f KG" % inventory.get_total_weight()
	
	# Observe stamina and load for fade-out when stable
	if fade_controller != null:
		fade_controller.observe_value(stamina_ratio + load_ratio)
		# Manually call _process() since fade_controller is RefCounted
		fade_controller._process(_delta)

func _style_progress_bar(bar: ProgressBar, fill_color: Color) -> void:
	if bar == null or style_profile == null:
		return
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.add_theme_stylebox_override("background", style_profile.make_progress_background_style())
	bar.add_theme_stylebox_override("fill", style_profile.make_progress_fill_style(fill_color))

# ============================================================
# RESPONSIVE LAYOUT
# ============================================================

func _update_responsive_position(animate: bool = false) -> void:
	if layout_manager == null or not use_responsive_layout:
		return
	
	var target_pos = layout_manager.get_anchored_position(anchor_position)
	
	if animate and style_profile.uses_high_tier():
		# Smooth animation on HIGH tier
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "position", target_pos, layout_manager.transition_duration)
	else:
		# Instant placement on LOW tier or initial setup
		position = target_pos
