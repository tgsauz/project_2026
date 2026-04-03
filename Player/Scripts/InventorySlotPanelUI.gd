## InventorySlotPanelUI
## Selected attachment-node panel showing the principal item and direct actions.
extends PanelContainer
class_name InventorySlotPanelUI

signal item_action_requested(action_id: String, item_dict: Dictionary)
signal anchor_changed(global_pos: Vector2)

var _inventory_component: InventoryComponent
var _current_slot: String = ""
var _current_item: Dictionary = {}
var _current_contents: Array[Dictionary] = []

var style_profile: UIStyleProfile
var fade_controller: UIFadeController

var _root_margin: MarginContainer
var _content_vbox: VBoxContainer
var _slot_label: Label
var _item_name_label: Label
var _accent_bar: ColorRect
var _meta_label: Label
var _actions_row: HFlowContainer
var _contents_label: Label
var _contents_list: ItemList

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 24
	offset_top = 24

	_root_margin = MarginContainer.new()
	_root_margin.add_theme_constant_override("margin_left", 18)
	_root_margin.add_theme_constant_override("margin_top", 16)
	_root_margin.add_theme_constant_override("margin_right", 18)
	_root_margin.add_theme_constant_override("margin_bottom", 16)
	add_child(_root_margin)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 10)
	_root_margin.add_child(_content_vbox)

	_slot_label = Label.new()
	_slot_label.text = "Attachment Node"
	_content_vbox.add_child(_slot_label)

	_item_name_label = Label.new()
	_item_name_label.text = "Empty"
	_item_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_vbox.add_child(_item_name_label)

	_accent_bar = ColorRect.new()
	_accent_bar.custom_minimum_size = Vector2(120, 3)
	_content_vbox.add_child(_accent_bar)

	_meta_label = Label.new()
	_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_vbox.add_child(_meta_label)

	_actions_row = HFlowContainer.new()
	_actions_row.add_theme_constant_override("h_separation", 8)
	_actions_row.add_theme_constant_override("v_separation", 8)
	_content_vbox.add_child(_actions_row)

	_contents_label = Label.new()
	_contents_label.text = "Contents"
	_contents_label.visible = false
	_content_vbox.add_child(_contents_label)

	_contents_list = ItemList.new()
	_contents_list.auto_height = true
	_contents_list.max_columns = 1
	_contents_list.visible = false
	_content_vbox.add_child(_contents_list)

	_refresh_responsive_size()

func apply_style(style: UIStyleProfile) -> void:
	style_profile = style
	if fade_controller == null:
		fade_controller = UIFadeController.new(self, style)
	else:
		fade_controller.style_profile = style

	add_theme_stylebox_override("panel", style_profile.make_panel_style("elevated"))
	_slot_label.label_settings = style_profile.make_label_settings("meta")
	_item_name_label.label_settings = style_profile.make_label_settings("title")
	_meta_label.label_settings = style_profile.make_label_settings("body")
	_contents_label.label_settings = style_profile.make_label_settings("accent")
	_accent_bar.color = style_profile.get_accent_color()
	_contents_list.add_theme_stylebox_override("panel", style_profile.make_panel_style())
	var font = style_profile.get_font()
	if font:
		_contents_list.add_theme_font_override("font", font)
	_contents_list.add_theme_font_size_override("font_size", style_profile.small_font_size)
	_contents_list.add_theme_color_override("font_color", style_profile.primary_text_color)
	_refresh_action_button_styles()

func set_inventory_component(inv: InventoryComponent) -> void:
	_inventory_component = inv

func set_slot_state(slot_name: String, slot_state: Dictionary) -> void:
	_current_slot = slot_name
	_current_item = {}
	_current_contents.clear()

	_slot_label.text = slot_name.replace("_", " ").capitalize()

	var main_item = slot_state.get("item", null) if slot_state != null else null
	if main_item == null:
		_item_name_label.text = "Empty"
		_meta_label.text = "No principal item is attached to this node."
		_rebuild_action_buttons([])
		_set_contents([])
	else:
		_current_item = normalize_item_payload(main_item, _inventory_component)
		_item_name_label.text = _current_item.get("display_name", "Unknown Item")
		_meta_label.text = _build_meta_text(main_item)
		_rebuild_action_buttons(_get_actions_for_item(_current_item))
		_set_contents(_collect_container_contents(main_item))

	_refresh_responsive_size()
	visible = true
	if fade_controller:
		fade_controller.fade_in()
	call_deferred("_emit_anchor_changed")

func clear() -> void:
	_current_slot = ""
	_current_item = {}
	_current_contents.clear()
	_slot_label.text = "Attachment Node"
	_item_name_label.text = "Empty"
	_meta_label.text = ""
	_rebuild_action_buttons([])
	_set_contents([])
	visible = false
	call_deferred("_emit_anchor_changed")

func get_accent_anchor_global_position() -> Vector2:
	if not visible:
		return Vector2.ZERO
	var rect := _accent_bar.get_global_rect()
	return Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y * 0.5)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh_responsive_size()
		call_deferred("_emit_anchor_changed")

func _refresh_responsive_size() -> void:
	var viewport_width := get_viewport_rect().size.x
	var preferred_width := clampf(viewport_width * 0.28, 260.0, 380.0)
	custom_minimum_size = Vector2(preferred_width, 0.0)
	size = Vector2(preferred_width, size.y)

func _build_meta_text(main_item: ItemInstance) -> String:
	if main_item == null or main_item.definition == null:
		return ""
	var lines: Array[String] = []
	lines.append("[%s]" % main_item.definition.category.to_upper())
	lines.append("Weight %.1f kg" % main_item.get_total_weight())
	if main_item.is_container():
		var capacity := main_item.definition.get_storage_capacity()
		var used := _inventory_component.get_storage_usage(main_item.instance_id) if _inventory_component != null else main_item.contained_item_ids.size()
		lines.append("Storage %d / %d" % [used, capacity])
	return "  |  ".join(lines)

func _get_actions_for_item(item_dict: Dictionary) -> Array:
	if _inventory_component == null:
		return []
	var item_id := str(item_dict.get("id", ""))
	if item_id.is_empty():
		return []
	return _inventory_component.get_item_actions(item_id)

func _rebuild_action_buttons(actions: Array) -> void:
	for child in _actions_row.get_children():
		child.queue_free()

	for action in actions:
		var button := Button.new()
		button.text = str(action.get("label", "Action"))
		button.custom_minimum_size = Vector2(92, 34)
		button.pressed.connect(_on_action_pressed.bind(str(action.get("id", ""))))
		_actions_row.add_child(button)
		_apply_action_button_style(button)

func _refresh_action_button_styles() -> void:
	for child in _actions_row.get_children():
		_apply_action_button_style(child as Button)

func _apply_action_button_style(button: Button) -> void:
	if button == null or style_profile == null:
		return
	var font = style_profile.get_font()
	if font:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", style_profile.small_font_size)
	button.add_theme_color_override("font_color", style_profile.primary_text_color)
	button.add_theme_color_override("font_hover_color", style_profile.get_accent_color())
	button.add_theme_stylebox_override("normal", style_profile.make_panel_style())
	button.add_theme_stylebox_override("hover", style_profile.make_panel_style("elevated"))
	button.add_theme_stylebox_override("pressed", style_profile.make_panel_style("elevated"))

func _set_contents(contents: Array[Dictionary]) -> void:
	_current_contents = contents
	_contents_list.clear()
	if _current_contents.is_empty():
		_contents_label.visible = false
		_contents_list.visible = false
		return

	_contents_label.visible = true
	_contents_list.visible = true
	for i in range(_current_contents.size()):
		var item_dict := _current_contents[i]
		_contents_list.add_item(str(item_dict.get("display_name", "Unknown Item")))
		if style_profile != null:
			_contents_list.set_item_custom_fg_color(i, style_profile.primary_text_color)

func _collect_container_contents(main_item: ItemInstance) -> Array[Dictionary]:
	var contents: Array[Dictionary] = []
	if main_item == null or not main_item.is_container() or _inventory_component == null:
		return contents
	for nested_id in main_item.contained_item_ids:
		var nested_item = _inventory_component.get_item_instance(str(nested_id))
		if nested_item != null:
			contents.append(normalize_item_payload(nested_item, _inventory_component))
	return contents

func _on_action_pressed(action_id: String) -> void:
	if action_id.is_empty() or _current_item.is_empty():
		return
	item_action_requested.emit(action_id, _current_item.duplicate(true))

func _emit_anchor_changed() -> void:
	anchor_changed.emit(get_accent_anchor_global_position())

static func normalize_item_payload(item_data, inventory: InventoryComponent = null) -> Dictionary:
	if item_data is ItemInstance:
		var instance := item_data as ItemInstance
		return {
			"id": instance.instance_id,
			"display_name": instance.get_display_name(),
			"name": instance.get_display_name(),
			"quantity": instance.stack_count,
			"slot": instance.owning_slot,
			"category": instance.definition.category if instance.definition != null else "",
			"weight": instance.definition.weight if instance.definition != null else 0.0
		}

	if item_data is Dictionary:
		var item_dict := item_data as Dictionary
		if item_dict.has("display_name") and item_dict.has("id"):
			return item_dict.duplicate(true)

		var item_id := str(item_dict.get("id", item_dict.get("instance_id", "")))
		var definition: ItemDefinition = item_dict.get("definition", null)
		var quantity := int(item_dict.get("quantity", item_dict.get("stack_count", 1)))
		if definition == null and inventory != null and not item_id.is_empty():
			var instance = inventory.get_item_instance(item_id)
			if instance != null:
				definition = instance.definition
				quantity = instance.stack_count

		var display_name := str(item_dict.get("name", item_dict.get("display_name", "Unknown")))
		if display_name == "Unknown" and definition != null:
			display_name = definition.display_name

		return {
			"id": item_id,
			"display_name": display_name,
			"name": display_name,
			"quantity": quantity,
			"slot": str(item_dict.get("slot", "")),
			"category": definition.category if definition != null else str(item_dict.get("category", "")),
			"weight": definition.weight if definition != null else float(item_dict.get("weight", 0.0))
		}

	return {
		"id": "",
		"display_name": "Unknown Item",
		"name": "Unknown Item",
		"quantity": 1,
		"slot": "",
		"category": "",
		"weight": 0.0
	}
