extends CanvasLayer

# ============================================================
#  CHARACTER TUNER UI
# ============================================================

const STYLE_PROFILE_PATH := "res://Player/Debug/Theme/Project2026UIStyle.tres"

@export var controller_path: NodePath
@onready var controller = get_node(controller_path)

@export var slot_list_path: NodePath
@onready var slot_list = get_node(slot_list_path)

@export var transform_panel_path: NodePath
@onready var transform_panel = get_node(transform_panel_path)

var current_slot: String = ""
var current_slot_button: Button
var slot_buttons: Dictionary = {}

# Sliders
@export var pos_x_path: NodePath
@export var pos_y_path: NodePath
@export var pos_z_path: NodePath
@export var rot_x_path: NodePath
@export var rot_y_path: NodePath
@export var rot_z_path: NodePath
@export var sca_x_path: NodePath

@export var move_x_path: NodePath
@export var move_y_path: NodePath
@export var save_button_path: NodePath

var current_item: ItemDefinition = null
var current_profile: ItemVisualAttachmentProfile = null
var style_profile: UIStyleProfile

var profile_status_label: Label
var copy_button: Button
var paste_button: Button
var mirror_button: Button
var rescan_button: Button
var anchor_debug_toggle: Button

func _ready():
	style_profile = load(STYLE_PROFILE_PATH) as UIStyleProfile
	controller.item_list_updated.connect(_on_items_updated)
	controller.profile_changed.connect(_on_profile_changed)
	_setup_ui()
	_on_items_updated()

func _on_items_updated():
	for child in slot_list.get_children():
		child.queue_free()
	slot_buttons.clear()
	current_slot_button = null
		
	for slot in controller.active_slots:
		var btn = Button.new()
		btn.text = controller.get_slot_label(slot)
		btn.toggle_mode = true
		btn.pressed.connect(_on_slot_selected.bind(slot, btn))
		slot_list.add_child(btn)
		slot_buttons[slot] = btn
		_style_button(btn)

func _on_slot_selected(slot_name: String, button: Button):
	current_slot = slot_name
	if current_slot_button != null and current_slot_button != button:
		current_slot_button.button_pressed = false
	current_slot_button = button
	button.button_pressed = true
	_refresh_item_list(slot_name)

func _on_profile_changed(slot_name: String, profile: ItemVisualAttachmentProfile, status_text: String):
	if slot_name == current_slot:
		current_profile = profile
		_update_sliders_from_profile(profile)
		if profile_status_label != null:
			profile_status_label.text = status_text
		_update_aux_button_state()

func _update_sliders_from_profile(profile: ItemVisualAttachmentProfile):
	get_node(pos_x_path).value = profile.position.x
	get_node(pos_y_path).value = profile.position.y
	get_node(pos_z_path).value = profile.position.z
	get_node(rot_x_path).value = profile.rotation_degrees.x
	get_node(rot_y_path).value = profile.rotation_degrees.y
	get_node(rot_z_path).value = profile.rotation_degrees.z
	get_node(sca_x_path).value = profile.scale.x

func _refresh_item_list(slot_name: String):
	var item_list = transform_panel.get_node("ItemList")
	for child in item_list.get_children():
		if child != profile_status_label:
			child.queue_free()
		
	var items = controller.get_items_for_slot(slot_name)
	if profile_status_label != null and profile_status_label.get_parent() != item_list:
		item_list.add_child(profile_status_label)
		item_list.move_child(profile_status_label, 0)

	for item in items:
		var btn = Button.new()
		btn.text = item.display_name
		btn.pressed.connect(_on_item_selected.bind(item))
		item_list.add_child(btn)
		_style_button(btn)

func _on_item_selected(definition: ItemDefinition):
	current_item = definition
	controller.equip_item(current_slot, definition)

func _on_value_changed(_value: float):
	if current_slot == "" or current_profile == null:
		return
	
	var pos = Vector3(
		get_node(pos_x_path).value,
		get_node(pos_y_path).value,
		get_node(pos_z_path).value
	)
	var rot = Vector3(
		get_node(rot_x_path).value,
		get_node(rot_y_path).value,
		get_node(rot_z_path).value
	)
	# Use X slider for uniform scale for now
	var sca = Vector3.ONE * get_node(sca_x_path).value
	
	controller.update_offset(current_slot, pos, rot, sca)
	current_profile.position = pos
	current_profile.rotation_degrees = rot
	current_profile.scale = sca

func _on_anim_value_changed(_value: float):
	var lateral = get_node(move_x_path).value
	var forward = get_node(move_y_path).value
	controller.set_animation_blend(lateral, forward)

func _on_save_pressed():
	if current_slot != "" and current_item != null and current_profile != null:
		controller.save_profile(current_slot, current_item, current_profile)
		if profile_status_label != null:
			profile_status_label.text = "Saved to resource"

func _on_copy_pressed() -> void:
	if current_profile == null:
		return
	controller.copy_profile_transform(current_profile)
	if profile_status_label != null:
		profile_status_label.text = "Transform copied"

func _on_paste_pressed() -> void:
	if current_profile == null:
		return
	controller.paste_profile_transform(current_profile)
	_update_sliders_from_profile(current_profile)
	_on_value_changed(0.0)
	if profile_status_label != null:
		profile_status_label.text = "Transform pasted"

func _on_mirror_pressed() -> void:
	if current_profile == null:
		return
	controller.mirror_profile_for_slot(current_slot, current_profile)
	_update_sliders_from_profile(current_profile)
	_on_value_changed(0.0)
	if profile_status_label != null:
		profile_status_label.text = "Mirrored using hand rule"

func _on_rescan_pressed() -> void:
	controller.rescan_items()
	if profile_status_label != null:
		profile_status_label.text = "Item scan refreshed"

func _on_anchor_debug_toggled(enabled: bool) -> void:
	controller.set_anchor_debug_enabled(enabled)
	anchor_debug_toggle.text = "Anchor Debug: ON" if enabled else "Anchor Debug: OFF"

func _setup_ui():
	_create_aux_controls()
	_style_existing_ui()
	_update_aux_button_state()
	
	# Connect transform sliders
	var sliders = [pos_x_path, pos_y_path, pos_z_path, rot_x_path, rot_y_path, rot_z_path, sca_x_path]
	for s_path in sliders:
		var s = get_node_or_null(s_path)
		if s:
			s.value_changed.connect(_on_value_changed)
			
	# Connect anim sliders
	get_node(move_x_path).value_changed.connect(_on_anim_value_changed)
	get_node(move_y_path).value_changed.connect(_on_anim_value_changed)
	
	# Connect action buttons
	get_node(save_button_path).pressed.connect(_on_save_pressed)
	copy_button.pressed.connect(_on_copy_pressed)
	paste_button.pressed.connect(_on_paste_pressed)
	mirror_button.pressed.connect(_on_mirror_pressed)
	rescan_button.pressed.connect(_on_rescan_pressed)
	anchor_debug_toggle.toggled.connect(_on_anchor_debug_toggled)

func _create_aux_controls() -> void:
	var tuning_vbox := transform_panel.get_node("VBoxContainer") as VBoxContainer
	var item_list := transform_panel.get_node("ItemList") as VBoxContainer
	var slot_panel := slot_list.get_parent() as ScrollContainer
	var slot_panel_root := slot_panel.get_parent() as Panel
	var anim_vbox := get_node("Control/AnimPanel/VBoxContainer") as VBoxContainer

	rescan_button = Button.new()
	rescan_button.text = "Rescan Items"
	rescan_button.custom_minimum_size = Vector2(0, 34)
	rescan_button.position = Vector2(12, 12)
	slot_panel.offset_top = 56
	slot_panel_root.add_child(rescan_button)
	slot_panel_root.move_child(rescan_button, 0)

	profile_status_label = Label.new()
	profile_status_label.text = "Select a slot and item"
	item_list.add_child(profile_status_label)
	item_list.move_child(profile_status_label, 0)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	tuning_vbox.add_child(action_row)
	tuning_vbox.move_child(action_row, tuning_vbox.get_child_count() - 1)

	copy_button = Button.new()
	copy_button.text = "Copy"
	action_row.add_child(copy_button)

	paste_button = Button.new()
	paste_button.text = "Paste"
	action_row.add_child(paste_button)

	mirror_button = Button.new()
	mirror_button.text = "Mirror L/R"
	action_row.add_child(mirror_button)

	anchor_debug_toggle = Button.new()
	anchor_debug_toggle.toggle_mode = true
	anchor_debug_toggle.text = "Anchor Debug: OFF"
	anim_vbox.add_child(anchor_debug_toggle)

func _style_existing_ui() -> void:
	if style_profile == null:
		return

	_style_control_tree(get_node("Control"))
	_style_button(get_node(save_button_path) as Button)
	_style_button(copy_button)
	_style_button(paste_button)
	_style_button(mirror_button)
	_style_button(rescan_button)
	_style_button(anchor_debug_toggle)

	if profile_status_label != null:
		profile_status_label.label_settings = style_profile.make_label_settings("accent")

func _style_control_tree(node: Node) -> void:
	if node is Panel:
		(node as Panel).add_theme_stylebox_override("panel", style_profile.make_panel_style("elevated"))
	elif node is Label:
		var label := node as Label
		label.label_settings = style_profile.make_label_settings("meta")
		if label.text == "Character Tuner":
			label.label_settings = style_profile.make_label_settings("title")
	elif node is HSlider:
		var slider := node as HSlider
		slider.add_theme_stylebox_override("grabber_area", style_profile.make_progress_background_style())
		slider.add_theme_stylebox_override("grabber_area_highlight", style_profile.make_progress_fill_style(style_profile.get_accent_color()))
	elif node is ScrollContainer:
		var scroll := node as ScrollContainer
		scroll.add_theme_stylebox_override("panel", style_profile.make_panel_style())

	for child in node.get_children():
		_style_control_tree(child)

func _style_button(button: Button) -> void:
	if button == null or style_profile == null:
		return

	var font = style_profile.get_font()
	if font:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", style_profile.base_font_size)
	button.add_theme_color_override("font_color", style_profile.primary_text_color)
	button.add_theme_color_override("font_hover_color", style_profile.get_accent_color())
	button.add_theme_color_override("font_pressed_color", style_profile.get_accent_color())
	button.add_theme_stylebox_override("normal", style_profile.make_panel_style())
	button.add_theme_stylebox_override("hover", style_profile.make_panel_style("elevated"))
	button.add_theme_stylebox_override("pressed", style_profile.make_panel_style("elevated"))

func _update_aux_button_state() -> void:
	var has_profile := current_profile != null
	copy_button.disabled = not has_profile
	paste_button.disabled = not has_profile
	mirror_button.disabled = not has_profile or (current_slot != "left_hand" and current_slot != "right_hand")
