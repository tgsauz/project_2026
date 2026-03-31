## ItemTooltipUI
## Styled popup showing item details on hover. Follows mouse position.
extends PanelContainer
class_name ItemTooltipUI

var _name_label: Label
var _category_label: Label
var _weight_label: Label
var _desc_label: Label
var _condition_bar: ProgressBar

var style_profile: UIStyleProfile

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(220, 0)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)
	
	_name_label = Label.new()
	_name_label.text = ""
	vbox.add_child(_name_label)
	
	_category_label = Label.new()
	_category_label.text = ""
	vbox.add_child(_category_label)
	
	_weight_label = Label.new()
	_weight_label.text = ""
	vbox.add_child(_weight_label)
	
	_condition_bar = ProgressBar.new()
	_condition_bar.max_value = 1.0
	_condition_bar.value = 1.0
	_condition_bar.show_percentage = false
	_condition_bar.custom_minimum_size = Vector2(0, 6)
	_condition_bar.visible = false
	vbox.add_child(_condition_bar)
	
	_desc_label = Label.new()
	_desc_label.text = ""
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size = Vector2(200, 0)
	vbox.add_child(_desc_label)

func apply_style(style: UIStyleProfile) -> void:
	style_profile = style
	add_theme_stylebox_override("panel", style.make_panel_style("elevated"))
	_name_label.label_settings = style.make_label_settings("title")
	_category_label.label_settings = style.make_label_settings("accent")
	_weight_label.label_settings = style.make_label_settings("meta")
	_desc_label.label_settings = style.make_label_settings("body")
	_condition_bar.add_theme_stylebox_override("background", style.make_progress_background_style())
	_condition_bar.add_theme_stylebox_override("fill", style.make_progress_fill_style(style.get_accent_color()))

func show_tooltip(item_dict: Dictionary, screen_pos: Vector2) -> void:
	if item_dict.is_empty():
		hide_tooltip()
		return
	
	var item_name: String = item_dict.get("name", "Unknown")
	var item_id: String = item_dict.get("id", "")
	
	_name_label.text = item_name
	
	# Try to find the full definition for richer data
	var definition: ItemDefinition = null
	var instance: ItemInstance = null
	
	# Attempt to get the ItemInstance from InventoryComponent
	var root = get_tree().root.find_child("UIRoot", true, false)
	if root and root.get("player_character"):
		var inv = root.player_character.get_node_or_null("InventoryComponent")
		if inv and not item_id.is_empty():
			instance = inv.get_item_instance(item_id)
			if instance:
				definition = instance.definition
	
	# Fallback: registry lookup by name
	if definition == null:
		definition = ItemDefinitionRegistry.find_by_id(item_id)
	
	if definition:
		_category_label.text = "[%s]" % definition.category.to_upper()
		_weight_label.text = "Weight: %.1f kg" % definition.weight
		_desc_label.text = definition.tooltip_text if not definition.tooltip_text.is_empty() else ""
		_desc_label.visible = not definition.tooltip_text.is_empty()
	else:
		_category_label.text = ""
		_weight_label.text = "Qty: %d" % item_dict.get("quantity", 1)
		_desc_label.visible = false
	
	if instance and instance.condition < 1.0:
		_condition_bar.value = instance.condition
		_condition_bar.visible = true
	else:
		_condition_bar.visible = false
	
	# Position near mouse, clamped to viewport
	var vp_size = get_viewport_rect().size
	var tooltip_pos = screen_pos + Vector2(16, 16)
	tooltip_pos.x = min(tooltip_pos.x, vp_size.x - size.x - 10)
	tooltip_pos.y = min(tooltip_pos.y, vp_size.y - size.y - 10)
	global_position = tooltip_pos
	
	visible = true

func hide_tooltip() -> void:
	visible = false
