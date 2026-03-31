## InventoryOverlayUI
## Renders 2D lines from attachment points with hover detection and click handling
extends Control

class_name InventoryOverlayUI

## Emitted when a line/slot is hovered
signal slot_line_hovered(slot_name: String)
## Emitted when a line/slot is clicked
signal slot_line_clicked(slot_name: String)
## Emitted when the user clicks the open background area to close the active accordions
signal deselected

@export var line_width: float = 2.0
@export var hover_line_width: float = 4.0
@export var line_color_idle: Color = Color.DIM_GRAY
@export var line_color_hover: Color = Color.WHITE
@export var update_frequency: int = 60  # Updates per second

var _character: Node3D
var _camera: Camera3D
var _attachment_lines: Array[Dictionary] = []
var _selected_line: String = ""
var _update_timer: float = 0.0
var _update_interval: float = 1.0 / update_frequency

var style_profile: UIStyleProfile
var fade_controller: UIFadeController

var _scroll_container: ScrollContainer
var _slot_menu: VBoxContainer
var _buttons: Dictionary = {}

var _encumbrance_container: VBoxContainer
var _weight_label: Label
var _weight_bar: ProgressBar

var _active_filter: String = ""

func _ready() -> void:
	# Make it full screen to capture background clicks
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_ui()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		deselected.emit()

func _setup_ui() -> void:
	_scroll_container = ScrollContainer.new()
	_scroll_container.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_scroll_container.offset_left = 50
	_scroll_container.offset_right = 350
	_scroll_container.offset_top = 50
	_scroll_container.offset_bottom = -50
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Stop scroll container from stealing all background clicks
	_scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_scroll_container)

	_slot_menu = VBoxContainer.new()
	_slot_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_menu.alignment = BoxContainer.ALIGNMENT_BEGIN
	_slot_menu.add_theme_constant_override("separation", 15)
	_scroll_container.add_child(_slot_menu)
	
	_encumbrance_container = VBoxContainer.new()
	_encumbrance_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_encumbrance_container.offset_left = -250
	_encumbrance_container.offset_right = -50
	_encumbrance_container.offset_top = -100
	_encumbrance_container.offset_bottom = -50
	
	_weight_label = Label.new()
	_weight_label.text = "Load: 0.0 / 20.0"
	_weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_encumbrance_container.add_child(_weight_label)
	
	_weight_bar = ProgressBar.new()
	_weight_bar.max_value = 1.0
	_weight_bar.value = 0.0
	_weight_bar.show_percentage = false
	_weight_bar.custom_minimum_size = Vector2(200, 10)
	_encumbrance_container.add_child(_weight_bar)
	
	add_child(_encumbrance_container)

	_camera = get_viewport().get_camera_3d()
	if not _camera:
		push_error("InventoryOverlayUI: Could not find camera")

func apply_style(style: UIStyleProfile) -> void:
	style_profile = style
	if fade_controller == null:
		fade_controller = UIFadeController.new(self, style)
	else:
		fade_controller.style_profile = style
	
	# Style encumbrance elements
	if _weight_label:
		_weight_label.label_settings = style_profile.make_label_settings("meta")
	if _weight_bar:
		_weight_bar.add_theme_stylebox_override("background", style_profile.make_progress_background_style())
		_weight_bar.add_theme_stylebox_override("fill", style_profile.make_progress_fill_style(style_profile.get_accent_color()))

func set_visibility(make_visible: bool) -> void:
	if fade_controller == null:
		return
	if make_visible:
		fade_controller.fade_in()
		visible = true
		set_process_input(true)
	else:
		fade_controller.fade_out()
		set_process_input(false)
		# Hide when fade is complete
		if not fade_controller.fade_completed.is_connected(_on_fade_completed):
			fade_controller.fade_completed.connect(_on_fade_completed)

func _on_fade_completed(direction: String) -> void:
	if direction == "out":
		visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	_camera = get_viewport().get_camera_3d()
	if not _character or not _camera:
		return
	
	# Update attachment lines at fixed frequency
	_update_timer += delta
	if _update_timer >= _update_interval:
		_update_timer = 0.0
		update_lines()
		queue_redraw()

func _draw() -> void:
	_camera = get_viewport().get_camera_3d()
	if not _camera or style_profile == null:
		return
	
	var line_opacity = 1.0 if style_profile.presentation_tier == UIStyleProfile.PresentationTier.HIGH else 0.5
	
	for line_data in _attachment_lines:
		var screen_pos: Vector2 = line_data.get("screen_pos", Vector2.ZERO)
		var is_hovered: bool = line_data.get("is_hovered", false)
		var btn: Button = line_data.get("button")
		
		# Skip if position is invalid or button is null/hidden via filter
		if screen_pos == Vector2.ZERO or screen_pos.x < 0 or screen_pos.y < 0 or btn == null or not btn.visible:
			continue
		
		var rect = btn.get_global_rect()
		var start_pos = Vector2(rect.end.x + 10, rect.get_center().y)
		
		# Determine color/width
		var color = line_color_hover if is_hovered else line_color_idle
		color.a = line_opacity
		var width = hover_line_width if is_hovered else line_width
		
		# Draw the leader line
		draw_line(start_pos, screen_pos, color, width)
		
		# Draw a small circle directly under the start pos logic
		var circle_radius = 5.0 if is_hovered else 3.0
		draw_circle(start_pos, circle_radius, color)
		# Draw a circle exactly where the 3D attachment node lives
		draw_circle(screen_pos, circle_radius, color)

## Set the character node to track attachment points from
func set_character(character: Node3D) -> void:
	_character = character
	_attachment_lines.clear()
	_selected_line = ""

## Query and update all attachment point positions
func update_lines() -> void:
	if not _character or not _camera:
		return
	
	_attachment_lines.clear()
	
	var positions_dict: Dictionary = {}
	var display_names: Dictionary = {}
	var inv = _character.get_node_or_null("InventoryComponent")
	var visuals_component = _character.get_node_or_null("VisualsComponent")
	
	# Connect weight signal once
	if inv and not inv.weight_changed.is_connected(_on_weight_changed):
		inv.weight_changed.connect(_on_weight_changed)
		_on_weight_changed(inv.get_total_weight(), inv.get_load_factor())
	
	# Build positions from VisualsComponent if available
	var visual_positions: Dictionary = {}
	if visuals_component and visuals_component.has_method("get_attachment_point_world_positions"):
		visual_positions = visuals_component.get_attachment_point_world_positions()
	
	# Use InventoryComponent.slot_names as the authoritative slot list
	if inv:
		var char_pos = _character.global_position
		for slot_name in inv.slot_names:
			var cfg = inv.slot_configs.get(slot_name, {})
			display_names[slot_name] = cfg.get("display_name", slot_name.replace("_", " ").capitalize())
			
			if visual_positions.has(slot_name):
				positions_dict[slot_name] = visual_positions[slot_name]
			else:
				# Fallback offset so leader lines still render
				positions_dict[slot_name] = char_pos + _get_fallback_offset(slot_name)
	else:
		# No InventoryComponent at all — pure fallback
		var char_pos = _character.global_position
		positions_dict = {
			"right_hand": char_pos + Vector3(0.4, 0.8, -0.1),
			"left_hand": char_pos + Vector3(-0.4, 0.8, -0.1),
			"lower_back": char_pos + Vector3(0, 1.0, -0.3)
		}
		for key in positions_dict.keys():
			display_names[key] = key.replace("_", " ").capitalize()
		
	# Synchronize dynamically created UI buttons
	_sync_menu_buttons(positions_dict.keys(), display_names)
	
	for attachment_name in positions_dict.keys():
		var world_pos = positions_dict[attachment_name]
		var screen_pos = project_attachment_point(world_pos)
		
		var line_data: Dictionary = {
			"slot_name": attachment_name,
			"world_pos": world_pos,
			"screen_pos": screen_pos,
			"is_hovered": (_selected_line == attachment_name),
			"button": _buttons.get(attachment_name)
		}
		_attachment_lines.append(line_data)

func _get_fallback_offset(slot_name: String) -> Vector3:
	match slot_name:
		"left_hand": return Vector3(-0.4, 0.8, -0.1)
		"right_hand": return Vector3(0.4, 0.8, -0.1)
		"torso": return Vector3(0, 1.2, 0.15)
		"lower_back": return Vector3(0, 1.0, -0.3)
		"belt": return Vector3(0, 0.9, 0.1)
		"left_pocket": return Vector3(-0.2, 0.85, 0.1)
		"right_pocket": return Vector3(0.2, 0.85, 0.1)
		"back_mount": return Vector3(0, 1.3, -0.25)
		"shoulder_mount": return Vector3(-0.15, 1.4, 0.0)
		_: return Vector3(0, 1.0, 0)

func _sync_menu_buttons(keys: Array, display_names: Dictionary = {}) -> void:
	if _buttons.size() == keys.size():
		return
		
	for c in _slot_menu.get_children():
		c.queue_free()
	_buttons.clear()
	
	for key in keys:
		var label_text = display_names.get(key, key.replace("_", " ").capitalize())
		
		var btn = Button.new()
		btn.text = "  " + label_text
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = true
		btn.custom_minimum_size = Vector2(200, 36)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		
		# Apply native UIStyleProfile styling
		if style_profile:
			var font = style_profile.get_font()
			if font:
				btn.add_theme_font_override("font", font)
			btn.add_theme_font_size_override("font_size", style_profile.base_font_size + 2)
			btn.add_theme_color_override("font_color", style_profile.primary_text_color)
			btn.add_theme_color_override("font_hover_color", style_profile.get_accent_color())
			btn.add_theme_color_override("font_pressed_color", style_profile.get_accent_color())
			
			# Subtle panel background for readability
			var normal_style = StyleBoxFlat.new()
			normal_style.bg_color = Color(style_profile.panel_fill_color.r, style_profile.panel_fill_color.g, style_profile.panel_fill_color.b, 0.4)
			normal_style.corner_radius_top_left = style_profile.panel_corner_radius
			normal_style.corner_radius_top_right = style_profile.panel_corner_radius
			normal_style.corner_radius_bottom_left = style_profile.panel_corner_radius
			normal_style.corner_radius_bottom_right = style_profile.panel_corner_radius
			normal_style.content_margin_left = style_profile.spacing_unit
			normal_style.content_margin_right = style_profile.spacing_unit
			btn.add_theme_stylebox_override("normal", normal_style)
			
			var hover_style = normal_style.duplicate()
			hover_style.bg_color = Color(style_profile.elevated_panel_fill_color.r, style_profile.elevated_panel_fill_color.g, style_profile.elevated_panel_fill_color.b, 0.7)
			hover_style.border_color = style_profile.get_accent_color()
			hover_style.border_width_left = 2
			btn.add_theme_stylebox_override("hover", hover_style)
		
		btn.button_down.connect(_on_slot_clicked.bind(key))
		btn.mouse_entered.connect(_on_slot_hovered.bind(key))
		btn.mouse_exited.connect(_on_slot_unhovered.bind(key))
		
		_slot_menu.add_child(btn)
		_buttons[key] = btn
	
	_refresh_button_labels()

## Refresh button labels with inline slot status (item names)
func _refresh_button_labels() -> void:
	var inv = _character.get_node_or_null("InventoryComponent") if _character else null
	if inv == null:
		return
	
	# Connect to inventory_updated once for live refresh
	if not inv.inventory_updated.is_connected(_on_inventory_updated):
		inv.inventory_updated.connect(_on_inventory_updated)
	
	for slot_name in _buttons.keys():
		var btn: Button = _buttons[slot_name]
		var cfg = inv.slot_configs.get(slot_name, {})
		var display_name: String = cfg.get("display_name", slot_name.replace("_", " ").capitalize())
		
		var state = inv.get_slot_state(slot_name)
		var main_item = state.get("item") if state else null
		
		if main_item != null:
			var item_name = main_item.get_display_name() if main_item.has_method("get_display_name") else "Item"
			if main_item.has_method("is_container") and main_item.is_container():
				var count = main_item.contained_item_ids.size()
				var capacity = main_item.definition.container_capacity if main_item.definition else 0
				btn.text = "  %s — %s (%d/%d)" % [display_name, item_name, count, capacity]
			else:
				btn.text = "  %s — %s" % [display_name, item_name]
			if style_profile:
				btn.add_theme_color_override("font_color", style_profile.primary_text_color)
		else:
			btn.text = "  %s" % display_name
			if style_profile:
				btn.add_theme_color_override("font_color", style_profile.secondary_text_color)

func _on_inventory_updated() -> void:
	_refresh_button_labels()

func _on_slot_clicked(slot_name: String) -> void:
	slot_line_clicked.emit(slot_name)
	
func _on_slot_hovered(slot_name: String) -> void:
	_selected_line = slot_name
	slot_line_hovered.emit(slot_name)
	
func _on_slot_unhovered(_slot_name: String) -> void:
	_selected_line = ""
	
## ACCORDION API

func expand_slot(slot_name: String, panel: Control) -> void:
	if panel.get_parent():
		panel.get_parent().remove_child(panel)
		
	if _buttons.has(slot_name):
		_slot_menu.add_child(panel)
		var btn = _buttons[slot_name]
		var target_index = btn.get_index() + 1
		_slot_menu.move_child(panel, target_index)
		
func expand_action(menu: Control, panel: Control) -> void:
	if menu.get_parent():
		menu.get_parent().remove_child(menu)
	
	_slot_menu.add_child(menu)
	if panel and panel.get_parent() == _slot_menu:
		_slot_menu.move_child(menu, panel.get_index() + 1)

func _on_weight_changed(new_weight: float, load_factor: float) -> void:
	if _weight_label:
		var capacity = 20.0
		var inv = _character.get_node_or_null("InventoryComponent")
		if inv:
			capacity = inv.get("base_capacity")
		_weight_label.text = "Load: %.1f / %.1f" % [new_weight, capacity]
		
	if _weight_bar:
		_weight_bar.value = load_factor
		if load_factor > 0.9:
			_weight_bar.modulate = Color.CRIMSON
		elif load_factor > 0.6:
			_weight_bar.modulate = Color.GOLD
		else:
			_weight_bar.modulate = Color.WHITE

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: set_active_filter("weapon")
			KEY_2: set_active_filter("medical")
			KEY_3: set_active_filter("ammo")
			KEY_4: set_active_filter("") # Show all

func set_active_filter(cat: String) -> void:
	_active_filter = cat
	var inv = _character.get_node_or_null("InventoryComponent")
	
	for key in _buttons.keys():
		var btn = _buttons[key] as Button
		if cat == "":
			btn.visible = true
		else:
			if inv and inv.get("slot_configs"):
				var cfg = inv.get("slot_configs").get(key, {})
				var accept = cfg.get("accepted_categories", [])
				# Display if the specified filter category is explicitly accepted
				btn.visible = accept.has(cat)
			else:
				btn.visible = true

## Project a 3D world position to 2D screen coordinates
func project_attachment_point(world_pos: Vector3) -> Vector2:
	_camera = get_viewport().get_camera_3d()
	if not _camera:
		return Vector2.ZERO
	
	# Use official Godot 4.6 API
	var screen_pos = _camera.unproject_position(world_pos)
	
	# Clamp to viewport bounds for safety
	var viewport_size = get_viewport_rect().size
	screen_pos.x = clamp(screen_pos.x, -50, viewport_size.x + 50)
	screen_pos.y = clamp(screen_pos.y, -50, viewport_size.y + 50)
	
	return screen_pos
