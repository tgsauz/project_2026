## InventoryOverlayUI
## Renders attachment-node dots and a single selected connector line.
extends Control
class_name InventoryOverlayUI

signal slot_line_hovered(slot_name: String, screen_pos: Vector2)
signal slot_line_unhovered
signal slot_line_clicked(slot_name: String)
signal deselected

@export var line_width: float = 2.0
@export var hover_line_width: float = 3.0
@export var update_frequency: int = 60
@export var dot_radius: float = 5.0
@export var hover_dot_radius: float = 8.0
@export var selected_dot_radius: float = 9.0

var _character: Node3D
var _camera: Camera3D
var _inventory_component: InventoryComponent
var _visuals_component: VisualsComponent
var _attachment_points: Array[Dictionary] = []
var _hovered_slot: String = ""
var _selected_slot: String = ""
var _panel_anchor_screen_pos: Vector2 = Vector2.ZERO
var _update_timer: float = 0.0
var _update_interval: float = 1.0 / update_frequency

var style_profile: UIStyleProfile
var fade_controller: UIFadeController

var _encumbrance_container: VBoxContainer
var _weight_label: Label
var _weight_bar: ProgressBar
var _active_filter: String = ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process_input(false)
	_setup_ui()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover_state(event.position)
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked_slot := _find_slot_at_screen_position(event.position)
		if clicked_slot.is_empty():
			clear_selection()
			deselected.emit()
			return

		_selected_slot = clicked_slot
		slot_line_clicked.emit(clicked_slot)
		queue_redraw()

func _setup_ui() -> void:
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

func apply_style(style: UIStyleProfile) -> void:
	style_profile = style
	if fade_controller == null:
		fade_controller = UIFadeController.new(self, style)
	else:
		fade_controller.style_profile = style

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
		if not fade_controller.fade_completed.is_connected(_on_fade_completed):
			fade_controller.fade_completed.connect(_on_fade_completed)

func _on_fade_completed(direction: String) -> void:
	if direction == "out":
		visible = false

func _process(delta: float) -> void:
	_camera = get_viewport().get_camera_3d()
	if not _character or not _camera:
		return

	_update_timer += delta
	if _update_timer >= _update_interval:
		_update_timer = 0.0
		update_lines()
		queue_redraw()

func _draw() -> void:
	if _camera == null or style_profile == null:
		return

	for point_data in _attachment_points:
		var screen_pos: Vector2 = point_data.get("screen_pos", Vector2.ZERO)
		if screen_pos == Vector2.ZERO:
			continue
		if not point_data.get("visible_by_filter", true):
			continue

		var slot_name := str(point_data.get("slot_name", ""))
		var has_item: bool = bool(point_data.get("has_item", false))
		var is_hovered := slot_name == _hovered_slot
		var is_selected := slot_name == _selected_slot
		var base_color := _get_dot_color(point_data, has_item)
		var radius := dot_radius

		if is_selected:
			radius = selected_dot_radius
		elif is_hovered:
			radius = hover_dot_radius

		draw_circle(screen_pos, radius, Color(base_color.r, base_color.g, base_color.b, 0.22))
		draw_circle(screen_pos, max(radius - 2.0, 2.0), base_color)
		draw_arc(screen_pos, radius + 2.0, 0.0, TAU, 24, Color(base_color.r, base_color.g, base_color.b, 0.85), 1.5)

	if _selected_slot.is_empty() or _panel_anchor_screen_pos == Vector2.ZERO:
		return

	var selected_point := _get_point_data(_selected_slot)
	if selected_point.is_empty():
		return
	if not selected_point.get("visible_by_filter", true):
		return

	var start_pos: Vector2 = selected_point.get("screen_pos", Vector2.ZERO) as Vector2
	if start_pos == Vector2.ZERO:
		return

	var color := style_profile.get_accent_color()
	draw_line(_panel_anchor_screen_pos, start_pos, color, hover_line_width)
	draw_circle(_panel_anchor_screen_pos, 4.0, color)

func set_character(character: Node3D) -> void:
	_character = character
	_inventory_component = character.get_node_or_null("InventoryComponent") as InventoryComponent if character != null else null
	_visuals_component = character.get_node_or_null("VisualsComponent") as VisualsComponent if character != null else null
	_attachment_points.clear()
	_hovered_slot = ""
	_selected_slot = ""

func set_inventory_component(inventory: InventoryComponent) -> void:
	_inventory_component = inventory

func set_visuals_component(visuals_component: VisualsComponent) -> void:
	_visuals_component = visuals_component

func set_panel_anchor_global_position(global_pos: Vector2) -> void:
	_panel_anchor_screen_pos = global_pos - global_position
	queue_redraw()

func clear_selection() -> void:
	_selected_slot = ""
	_panel_anchor_screen_pos = Vector2.ZERO
	queue_redraw()

func set_selected_slot(slot_name: String) -> void:
	_selected_slot = slot_name
	queue_redraw()

func update_lines() -> void:
	if not _character or not _camera:
		return

	_attachment_points.clear()

	var inv = _inventory_component
	var visuals_component = _visuals_component

	if inv and not inv.weight_changed.is_connected(_on_weight_changed):
		inv.weight_changed.connect(_on_weight_changed)
		_on_weight_changed(inv.get_total_weight(), inv.get_load_factor())
	if inv and not inv.inventory_updated.is_connected(_on_inventory_updated):
		inv.inventory_updated.connect(_on_inventory_updated)

	var visual_positions: Dictionary = {}
	if visuals_component and visuals_component.has_method("get_attachment_point_world_positions"):
		visual_positions = visuals_component.get_attachment_point_world_positions()

	if inv:
		var char_pos = _character.global_position
		for node_data in inv.get_available_attachment_nodes():
			var slot_name := str(node_data.get("node_id", ""))
			if slot_name.is_empty():
				continue

			var world_pos: Vector3 = visual_positions.get(slot_name, char_pos + _get_fallback_offset(slot_name))
			var cfg = inv.slot_configs.get(slot_name, {})
			var accepted_categories = cfg.get("accepted_categories", PackedStringArray())
			var slot_state = inv.get_slot_state(slot_name)
			var main_item = slot_state.get("item", null) if not slot_state.is_empty() else null

			_attachment_points.append({
				"slot_name": slot_name,
				"display_name": str(node_data.get("display_name", slot_name.replace("_", " ").capitalize())),
				"screen_pos": project_attachment_point(world_pos),
				"world_pos": world_pos,
				"accepted_categories": accepted_categories,
				"has_item": main_item != null,
				"visible_by_filter": _passes_filter(accepted_categories)
			})
	else:
		var fallback_positions = {
			"right_hand": _character.global_position + Vector3(0.4, 0.8, -0.1),
			"left_hand": _character.global_position + Vector3(-0.4, 0.8, -0.1),
			"lower_back": _character.global_position + Vector3(0, 1.0, -0.3)
		}
		for slot_name in fallback_positions.keys():
			_attachment_points.append({
				"slot_name": slot_name,
				"display_name": slot_name.replace("_", " ").capitalize(),
				"screen_pos": project_attachment_point(fallback_positions[slot_name]),
				"world_pos": fallback_positions[slot_name],
				"accepted_categories": PackedStringArray(),
				"has_item": false,
				"visible_by_filter": true
			})

	if not _selected_slot.is_empty():
		var selected_exists := false
		for point_data in _attachment_points:
			if str(point_data.get("slot_name", "")) == _selected_slot:
				selected_exists = true
				break
		if not selected_exists:
			clear_selection()

func _get_dot_color(point_data: Dictionary, has_item: bool) -> Color:
	if style_profile == null:
		return Color.WHITE
	if has_item:
		return style_profile.get_accent_color()
	if point_data.get("visible_by_filter", true):
		return Color(
			style_profile.secondary_text_color.r,
			style_profile.secondary_text_color.g,
			style_profile.secondary_text_color.b,
			0.9
		)
	return Color(0.35, 0.35, 0.35, 0.4)

func _find_slot_at_screen_position(screen_pos: Vector2) -> String:
	for point_data in _attachment_points:
		if not point_data.get("visible_by_filter", true):
			continue
		var point_pos: Vector2 = point_data.get("screen_pos", Vector2.ZERO)
		if point_pos == Vector2.ZERO:
			continue
		if point_pos.distance_to(screen_pos) <= hover_dot_radius + 4.0:
			return str(point_data.get("slot_name", ""))
	return ""

func _update_hover_state(screen_pos: Vector2) -> void:
	var hovered_slot := _find_slot_at_screen_position(screen_pos)
	if hovered_slot == _hovered_slot:
		return

	_hovered_slot = hovered_slot
	if _hovered_slot.is_empty():
		slot_line_unhovered.emit()
	else:
		var point_data := _get_point_data(_hovered_slot)
		slot_line_hovered.emit(_hovered_slot, point_data.get("screen_pos", screen_pos))
	queue_redraw()

func _get_point_data(slot_name: String) -> Dictionary:
	for point_data in _attachment_points:
		if str(point_data.get("slot_name", "")) == slot_name:
			return point_data
	return {}

func _passes_filter(accepted_categories) -> bool:
	if _active_filter.is_empty():
		return true

	var categories: PackedStringArray = PackedStringArray()
	if accepted_categories is PackedStringArray:
		categories = accepted_categories
	elif accepted_categories is Array:
		for category in accepted_categories:
			categories.append(str(category))

	return categories.has(_active_filter)

func _get_fallback_offset(slot_name: String) -> Vector3:
	match slot_name:
		"left_hand":
			return Vector3(-0.4, 0.8, -0.1)
		"right_hand":
			return Vector3(0.4, 0.8, -0.1)
		"torso":
			return Vector3(0, 1.2, 0.15)
		"lower_back":
			return Vector3(0, 1.0, -0.3)
		"belt":
			return Vector3(0, 0.9, 0.1)
		"left_pocket":
			return Vector3(-0.2, 0.85, 0.1)
		"right_pocket":
			return Vector3(0.2, 0.85, 0.1)
		"back_mount":
			return Vector3(0, 1.3, -0.25)
		"shoulder_mount":
			return Vector3(-0.15, 1.4, 0.0)
		_:
			return Vector3(0, 1.0, 0)

func _on_inventory_updated() -> void:
	update_lines()
	queue_redraw()

func _on_weight_changed(new_weight: float, load_factor: float) -> void:
	if _weight_label:
		var capacity = 20.0
		var inv = _inventory_component
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
			KEY_1:
				set_active_filter("weapon")
			KEY_2:
				set_active_filter("medical")
			KEY_3:
				set_active_filter("ammo")
			KEY_4:
				set_active_filter("")

func set_active_filter(cat: String) -> void:
	_active_filter = cat
	update_lines()
	queue_redraw()

func project_attachment_point(world_pos: Vector3) -> Vector2:
	_camera = get_viewport().get_camera_3d()
	if not _camera:
		return Vector2.ZERO

	var screen_pos = _camera.unproject_position(world_pos)
	var viewport_size = get_viewport_rect().size
	screen_pos.x = clamp(screen_pos.x, -50, viewport_size.x + 50)
	screen_pos.y = clamp(screen_pos.y, -50, viewport_size.y + 50)
	return screen_pos
