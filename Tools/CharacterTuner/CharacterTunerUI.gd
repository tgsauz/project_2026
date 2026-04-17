extends CanvasLayer

# ============================================================
#  CHARACTER TUNER UI
# ============================================================

const STYLE_PROFILE_PATH := "res://Player/Debug/Theme/Project2026UIStyle.tres"

@export var controller_path: NodePath
var controller: CharacterTunerController = null

@export var slot_option_path: NodePath
var slot_option: OptionButton = null

@export var item_option_path: NodePath
var item_option: OptionButton = null
var rig_option: OptionButton = null
var rig_label: Label = null

@export var transform_panel_path: NodePath
var transform_panel: Panel = null

var current_slot: String = ""

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
var control_root: Control = null
var pos_x_slider: HSlider = null
var pos_y_slider: HSlider = null
var pos_z_slider: HSlider = null
var rot_x_slider: HSlider = null
var rot_y_slider: HSlider = null
var rot_z_slider: HSlider = null
var scale_slider: HSlider = null
var move_x_slider: HSlider = null
var move_y_slider: HSlider = null
var save_button: Button = null

var profile_status_label: Label
var copy_button: Button
var paste_button: Button
var mirror_button: Button
var rescan_button: Button
var anchor_debug_toggle: Button
var aim_preview_toggle: Button

# Numeric input fields for sliders
var pos_x_value_input: SpinBox
var pos_y_value_input: SpinBox
var pos_z_value_input: SpinBox
var rot_x_value_input: SpinBox
var rot_y_value_input: SpinBox
var rot_z_value_input: SpinBox
var scale_value_input: SpinBox
var move_x_value_input: SpinBox
var move_y_value_input: SpinBox

var suppress_numeric_callbacks: bool = false

func _ready() -> void:
	if not _resolve_required_nodes():
		set_process(false)
		set_process_input(false)
		return

	style_profile = load(STYLE_PROFILE_PATH) as UIStyleProfile
	controller.item_list_updated.connect(_on_items_updated)
	controller.profile_changed.connect(_on_profile_changed)
	if controller.has_signal("rig_presets_updated"):
		controller.rig_presets_updated.connect(_on_rig_presets_updated)
	_setup_ui()
	_refresh_rig_options()
	_on_items_updated()

func _on_items_updated() -> void:
	if slot_option == null:
		return
	slot_option.clear()
	for slot in controller.active_slots:
		slot_option.add_item(controller.get_slot_label(slot))
		var idx = slot_option.item_count - 1
		slot_option.set_item_metadata(idx, slot)
	
	if slot_option.item_count > 0:
		var preferred_slot_index := _find_slot_option_index(current_slot)
		if preferred_slot_index < 0:
			preferred_slot_index = 0
		slot_option.select(preferred_slot_index)
		_on_slot_selected(preferred_slot_index)
	else:
		current_slot = ""
		current_item = null
		current_profile = null

func _on_slot_selected(index: int) -> void:
	if index < 0 or index >= slot_option.item_count: return
	var slot_name = slot_option.get_item_metadata(index) as String
	current_slot = slot_name
	_refresh_item_list(slot_name)

func _on_profile_changed(slot_name: String, profile: ItemVisualAttachmentProfile, status_text: String) -> void:
	if slot_name.is_empty() or slot_name != current_slot:
		return
	current_profile = profile
	if profile != null:
		_update_sliders_from_profile(profile)
	else:
		if profile_status_label != null:
			profile_status_label.text = "Profile is null"
	if profile_status_label != null:
		profile_status_label.text = status_text
	_update_aux_button_state()

func _update_sliders_from_profile(profile: ItemVisualAttachmentProfile) -> void:
	if profile == null: return
	pos_x_slider.value = profile.position.x
	pos_y_slider.value = profile.position.y
	pos_z_slider.value = profile.position.z
	rot_x_slider.value = profile.rotation_degrees.x
	rot_y_slider.value = profile.rotation_degrees.y
	rot_z_slider.value = profile.rotation_degrees.z
	scale_slider.value = profile.scale.x
	_update_slider_value_labels()

func _refresh_item_list(slot_name: String) -> void:
	if item_option == null:
		return
	item_option.clear()
	item_option.add_item("-- None / Clear --")
	item_option.set_item_metadata(0, null)
	
	var items = controller.get_items_for_slot(slot_name)
	for item in items:
		if item == null: continue
		item_option.add_item(item.display_name)
		var idx = item_option.item_count - 1
		item_option.set_item_metadata(idx, item)
	
	var preferred_item := controller.get_selected_item_for_slot(slot_name)
	var preferred_index := _find_item_option_index(preferred_item)
	if preferred_index < 0:
		preferred_index = 0
	item_option.select(preferred_index)
	_on_item_selected_idx(preferred_index)

func _on_item_selected_idx(index: int) -> void:
	if index < 0 or index >= item_option.item_count: return
	var item = item_option.get_item_metadata(index) as ItemDefinition
	_on_item_selected(item)

func _on_item_selected(definition: ItemDefinition) -> void:
	if current_slot.is_empty():
		return
	current_item = definition
	if definition == null:
		controller.equip_item(current_slot, definition)
		current_profile = null
		if profile_status_label != null:
			profile_status_label.text = "Item cleared"
		_update_aux_button_state()
	else:
		# equip_item emits profile_changed which calls _on_profile_changed,
		# updating current_profile and sliders. We avoid overwriting status here.
		controller.equip_item(current_slot, definition)
		current_profile = controller.get_selected_profile_for_slot(current_slot)
		# If profile_changed did not fire (e.g. slot mismatch guard), sync sliders now.
		if current_profile != null:
			_update_sliders_from_profile(current_profile)
		if profile_status_label != null and profile_status_label.text.is_empty():
			profile_status_label.text = "Item loaded"

func _on_rig_presets_updated(_active_index: int) -> void:
	_refresh_rig_options()

func _on_value_changed(_value: float):
	if current_slot == "" or current_profile == null:
		return
	
	var pos = Vector3(
		pos_x_slider.value,
		pos_y_slider.value,
		pos_z_slider.value
	)
	var rot = Vector3(
		rot_x_slider.value,
		rot_y_slider.value,
		rot_z_slider.value
	)
	# Use X slider for uniform scale for now
	var sca = Vector3.ONE * scale_slider.value
	
	controller.update_offset(current_slot, pos, rot, sca)
	current_profile.position = pos
	current_profile.rotation_degrees = rot
	current_profile.scale = sca
	_update_slider_value_labels()

func _on_anim_value_changed(_value: float):
	var lateral = move_x_slider.value
	var forward = move_y_slider.value
	controller.set_animation_blend(lateral, forward)
	_update_anim_slider_value_labels()

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
		profile_status_label.text = "Mirrored using hand/side rule"

func _on_rescan_pressed() -> void:
	controller.rescan_items()
	if profile_status_label != null:
		profile_status_label.text = "Item scan refreshed"

func _on_anchor_debug_toggled(enabled: bool) -> void:
	controller.set_anchor_debug_enabled(enabled)
	anchor_debug_toggle.text = "Anchor Debug: ON" if enabled else "Anchor Debug: OFF"

func _on_aim_preview_toggled(enabled: bool) -> void:
	if controller != null and controller.has_method("set_preview_aiming"):
		controller.set_preview_aiming(enabled)
	aim_preview_toggle.text = "Aim Preview: ON" if enabled else "Aim Preview: OFF"

func _setup_ui() -> void:
	_create_aux_controls()
	_style_existing_ui()
	_update_aux_button_state()
	
	# Connect transform sliders
	var sliders: Array[HSlider] = [pos_x_slider, pos_y_slider, pos_z_slider, rot_x_slider, rot_y_slider, rot_z_slider, scale_slider]
	for s_path in sliders:
		if s_path != null and not s_path.value_changed.is_connected(_on_value_changed):
			s_path.value_changed.connect(_on_value_changed)
	
	# Improve precision for authored transform values
	if pos_x_slider != null: pos_x_slider.step = 0.001
	if pos_y_slider != null: pos_y_slider.step = 0.001
	if pos_z_slider != null: pos_z_slider.step = 0.001
	if rot_x_slider != null: rot_x_slider.step = 0.01
	if rot_y_slider != null: rot_y_slider.step = 0.01
	if rot_z_slider != null: rot_z_slider.step = 0.01
	if scale_slider != null: scale_slider.step = 0.001
			
	# Connect anim sliders
	if not move_x_slider.value_changed.is_connected(_on_anim_value_changed):
		move_x_slider.value_changed.connect(_on_anim_value_changed)
	if not move_y_slider.value_changed.is_connected(_on_anim_value_changed):
		move_y_slider.value_changed.connect(_on_anim_value_changed)
	
	# Create value display labels for sliders
	_create_slider_value_labels()
	_update_slider_value_labels()
	_update_anim_slider_value_labels()
	# Re-apply style so dynamically created numeric inputs match tuner styling.
	if control_root != null:
		_style_control_tree(control_root)
	
	# Connect action buttons
	if not save_button.pressed.is_connected(_on_save_pressed):
		save_button.pressed.connect(_on_save_pressed)
	if not copy_button.pressed.is_connected(_on_copy_pressed):
		copy_button.pressed.connect(_on_copy_pressed)
	if not paste_button.pressed.is_connected(_on_paste_pressed):
		paste_button.pressed.connect(_on_paste_pressed)
	if not mirror_button.pressed.is_connected(_on_mirror_pressed):
		mirror_button.pressed.connect(_on_mirror_pressed)
	if not rescan_button.pressed.is_connected(_on_rescan_pressed):
		rescan_button.pressed.connect(_on_rescan_pressed)
	if not anchor_debug_toggle.toggled.is_connected(_on_anchor_debug_toggled):
		anchor_debug_toggle.toggled.connect(_on_anchor_debug_toggled)
	if not aim_preview_toggle.toggled.is_connected(_on_aim_preview_toggled):
		aim_preview_toggle.toggled.connect(_on_aim_preview_toggled)

	if slot_option != null and not slot_option.item_selected.is_connected(_on_slot_selected):
		slot_option.item_selected.connect(_on_slot_selected)
	if item_option != null and not item_option.item_selected.is_connected(_on_item_selected_idx):
		item_option.item_selected.connect(_on_item_selected_idx)
	if rig_option != null and not rig_option.item_selected.is_connected(_on_rig_selected):
		rig_option.item_selected.connect(_on_rig_selected)

func _create_aux_controls() -> void:
	var tuning_vbox := transform_panel.get_node("MarginContainer/TuningVBox/VBoxContainer") as VBoxContainer
	var anim_vbox := get_node("Control/HBoxContainer/CenterArea/AnimPanel/MarginContainer/VBoxContainer") as VBoxContainer
	var tuning_root_vbox := transform_panel.get_node("MarginContainer/TuningVBox") as VBoxContainer

	rescan_button = Button.new()
	rescan_button.text = "Rescan Items"
	rescan_button.custom_minimum_size = Vector2(0, 34)
	tuning_vbox.add_child(rescan_button)
	tuning_vbox.move_child(rescan_button, 0)

	profile_status_label = Label.new()
	profile_status_label.text = "Select a slot and item"
	tuning_root_vbox.add_child(profile_status_label)
	var status_index := item_option.get_index() + 1 if item_option != null else 5
	tuning_root_vbox.move_child(profile_status_label, status_index)

	var rig_row := HBoxContainer.new()
	rig_row.add_theme_constant_override("separation", 8)
	rig_label = Label.new()
	rig_label.text = "Rig"
	rig_option = OptionButton.new()
	rig_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rig_row.add_child(rig_label)
	rig_row.add_child(rig_option)
	tuning_root_vbox.add_child(rig_row)
	tuning_root_vbox.move_child(rig_row, 1)

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

	aim_preview_toggle = Button.new()
	aim_preview_toggle.toggle_mode = true
	aim_preview_toggle.text = "Aim Preview: OFF"
	anim_vbox.add_child(aim_preview_toggle)

func _style_existing_ui() -> void:
	if style_profile == null:
		return

	_style_control_tree(control_root)
	_style_button(save_button)
	_style_button(copy_button)
	_style_button(paste_button)
	_style_button(mirror_button)
	_style_button(rescan_button)
	_style_button(anchor_debug_toggle)
	_style_button(aim_preview_toggle)

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
	elif node is OptionButton:
		var opt := node as OptionButton
		var font = style_profile.get_font()
		if font:
			opt.add_theme_font_override("font", font)
		opt.add_theme_font_size_override("font_size", style_profile.base_font_size)
		opt.add_theme_color_override("font_color", style_profile.primary_text_color)
		opt.add_theme_color_override("font_hover_color", style_profile.get_accent_color())
		opt.add_theme_color_override("font_pressed_color", style_profile.get_accent_color())
		opt.add_theme_stylebox_override("normal", style_profile.make_panel_style())
		opt.add_theme_stylebox_override("hover", style_profile.make_panel_style("elevated"))
		opt.add_theme_stylebox_override("pressed", style_profile.make_panel_style("elevated"))
	elif node is SpinBox:
		var spin := node as SpinBox
		var font = style_profile.get_font()
		if font:
			spin.add_theme_font_override("font", font)
		spin.add_theme_font_size_override("font_size", style_profile.base_font_size)
		spin.add_theme_color_override("font_color", style_profile.primary_text_color)
		spin.add_theme_color_override("font_selected_color", style_profile.get_accent_color())
		spin.add_theme_stylebox_override("normal", style_profile.make_panel_style())
		spin.add_theme_stylebox_override("focus", style_profile.make_panel_style("elevated"))
	elif node is LineEdit:
		var line_edit := node as LineEdit
		var font = style_profile.get_font()
		if font:
			line_edit.add_theme_font_override("font", font)
		line_edit.add_theme_font_size_override("font_size", style_profile.base_font_size)
		line_edit.add_theme_color_override("font_color", style_profile.primary_text_color)
		line_edit.add_theme_color_override("font_selected_color", style_profile.get_accent_color())
		line_edit.add_theme_stylebox_override("normal", style_profile.make_panel_style())
		line_edit.add_theme_stylebox_override("focus", style_profile.make_panel_style("elevated"))

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
	
	var is_sided = current_slot.ends_with("_left") or current_slot.ends_with("_right") or current_slot.begins_with("left_") or current_slot.begins_with("right_")
	mirror_button.disabled = not has_profile or not is_sided

func _refresh_rig_options() -> void:
	if rig_option == null or controller == null:
		return
	rig_option.clear()
	if not controller.has_method("get_rig_preset_labels"):
		rig_option.add_item("Legacy Rig")
		rig_option.disabled = true
		return

	var labels := controller.get_rig_preset_labels()
	for idx in range(labels.size()):
		rig_option.add_item(labels[idx])

	var has_presets := labels.size() > 0
	rig_option.disabled = not has_presets
	if not has_presets:
		rig_option.add_item("Legacy Rig")
		rig_option.select(0)
		return

	var active_index := controller.get_active_rig_preset_index() if controller.has_method("get_active_rig_preset_index") else 0
	if active_index < 0 or active_index >= rig_option.item_count:
		active_index = 0
	rig_option.select(active_index)

func _on_rig_selected(index: int) -> void:
	if controller == null:
		return
	if not controller.has_method("select_rig_preset"):
		return
	var ok := controller.select_rig_preset(index)
	if profile_status_label != null:
		profile_status_label.text = "Rig switched" if ok else "Rig switch failed"

func _resolve_required_nodes() -> bool:
	controller = _resolve_node_with_fallback(controller_path, NodePath("../TunerController")) as CharacterTunerController
	control_root = _resolve_node_with_fallback(NodePath(), NodePath("Control")) as Control
	
	# New OptionButton paths
	slot_option = _resolve_node_with_fallback(slot_option_path, NodePath("Control/HBoxContainer/TuningPanel/MarginContainer/TuningVBox/SlotOption")) as OptionButton
	item_option = _resolve_node_with_fallback(item_option_path, NodePath("Control/HBoxContainer/TuningPanel/MarginContainer/TuningVBox/ItemOption")) as OptionButton
	
	transform_panel = _resolve_node_with_fallback(transform_panel_path, NodePath("Control/HBoxContainer/TuningPanel")) as Panel
	pos_x_slider = _resolve_node_with_fallback(pos_x_path, NodePath("Control/HBoxContainer/TuningPanel/MarginContainer/TuningVBox/VBoxContainer/PosX/HSlider")) as HSlider
	pos_y_slider = _resolve_node_with_fallback(pos_y_path, NodePath("Control/HBoxContainer/TuningPanel/MarginContainer/TuningVBox/VBoxContainer/PosY/HSlider")) as HSlider
	pos_z_slider = _resolve_node_with_fallback(pos_z_path, NodePath("Control/HBoxContainer/TuningPanel/MarginContainer/TuningVBox/VBoxContainer/PosZ/HSlider")) as HSlider
	rot_x_slider = _resolve_node_with_fallback(rot_x_path, NodePath("Control/HBoxContainer/TuningPanel/MarginContainer/TuningVBox/VBoxContainer/RotX/HSlider")) as HSlider
	rot_y_slider = _resolve_node_with_fallback(rot_y_path, NodePath("Control/HBoxContainer/TuningPanel/MarginContainer/TuningVBox/VBoxContainer/RotY/HSlider")) as HSlider
	rot_z_slider = _resolve_node_with_fallback(rot_z_path, NodePath("Control/HBoxContainer/TuningPanel/MarginContainer/TuningVBox/VBoxContainer/RotZ/HSlider")) as HSlider
	scale_slider = _resolve_node_with_fallback(sca_x_path, NodePath("Control/HBoxContainer/TuningPanel/MarginContainer/TuningVBox/VBoxContainer/Scale/HSlider")) as HSlider
	move_x_slider = _resolve_node_with_fallback(move_x_path, NodePath("Control/HBoxContainer/CenterArea/AnimPanel/MarginContainer/VBoxContainer/MoveX/HSlider")) as HSlider
	move_y_slider = _resolve_node_with_fallback(move_y_path, NodePath("Control/HBoxContainer/CenterArea/AnimPanel/MarginContainer/VBoxContainer/MoveY/HSlider")) as HSlider
	save_button = _resolve_node_with_fallback(save_button_path, NodePath("Control/HBoxContainer/TuningPanel/MarginContainer/TuningVBox/VBoxContainer/SaveButton")) as Button

	var valid := true
	if controller == null:
		push_error("CharacterTunerUI could not resolve the tuner controller.")
		valid = false
	if control_root == null:
		push_error("CharacterTunerUI could not resolve the root Control node.")
		valid = false
	if slot_option == null:
		push_error("CharacterTunerUI could not resolve the Slot OptionButton.")
		valid = false
	if item_option == null:
		push_error("CharacterTunerUI could not resolve the Item OptionButton.")
		valid = false
	if transform_panel == null:
		push_error("CharacterTunerUI could not resolve the transform panel.")
		valid = false
	if pos_x_slider == null or pos_y_slider == null or pos_z_slider == null:
		push_error("CharacterTunerUI could not resolve position sliders.")
		valid = false
	if rot_x_slider == null or rot_y_slider == null or rot_z_slider == null:
		push_error("CharacterTunerUI could not resolve rotation sliders.")
		valid = false
	if scale_slider == null:
		push_error("CharacterTunerUI could not resolve the scale slider.")
		valid = false
	if move_x_slider == null or move_y_slider == null:
		push_error("CharacterTunerUI could not resolve animation preview sliders.")
		valid = false
	if save_button == null:
		push_error("CharacterTunerUI could not resolve the save button.")
		valid = false

	return valid

func _create_slider_value_labels() -> void:
	# Create value inputs for position sliders
	pos_x_value_input = _create_value_input_for_slider(pos_x_slider, false)
	pos_y_value_input = _create_value_input_for_slider(pos_y_slider, false)
	pos_z_value_input = _create_value_input_for_slider(pos_z_slider, false)
	
	# Create value inputs for rotation sliders
	rot_x_value_input = _create_value_input_for_slider(rot_x_slider, false)
	rot_y_value_input = _create_value_input_for_slider(rot_y_slider, false)
	rot_z_value_input = _create_value_input_for_slider(rot_z_slider, false)
	
	# Create value input for scale slider
	scale_value_input = _create_value_input_for_slider(scale_slider, false)
	
	# Create value inputs for animation sliders
	move_x_value_input = _create_value_input_for_slider(move_x_slider, true)
	move_y_value_input = _create_value_input_for_slider(move_y_slider, true)

func _create_value_input_for_slider(slider: HSlider, is_anim_slider: bool) -> SpinBox:
	if slider == null or slider.get_parent() == null:
		return null
	
	var input := SpinBox.new()
	input.custom_minimum_size = Vector2(88, 0)
	input.min_value = slider.min_value
	input.max_value = slider.max_value
	input.step = slider.step if slider.step > 0.0 else (0.01 if is_anim_slider else 0.001)
	input.allow_greater = false
	input.allow_lesser = false
	input.value = slider.value
	input.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if not input.value_changed.is_connected(_on_numeric_value_changed.bind(slider, is_anim_slider)):
		input.value_changed.connect(_on_numeric_value_changed.bind(slider, is_anim_slider))

	var parent = slider.get_parent() as HBoxContainer
	if parent != null:
		parent.add_child(input)
	return input

func _on_numeric_value_changed(value: float, slider: HSlider, _is_anim_slider: bool) -> void:
	if suppress_numeric_callbacks:
		return
	if slider == null:
		return
	slider.value = value

func _update_slider_value_labels() -> void:
	suppress_numeric_callbacks = true
	if pos_x_value_input != null:
		pos_x_value_input.value = pos_x_slider.value
	if pos_y_value_input != null:
		pos_y_value_input.value = pos_y_slider.value
	if pos_z_value_input != null:
		pos_z_value_input.value = pos_z_slider.value
	if rot_x_value_input != null:
		rot_x_value_input.value = rot_x_slider.value
	if rot_y_value_input != null:
		rot_y_value_input.value = rot_y_slider.value
	if rot_z_value_input != null:
		rot_z_value_input.value = rot_z_slider.value
	if scale_value_input != null:
		scale_value_input.value = scale_slider.value
	suppress_numeric_callbacks = false

func _update_anim_slider_value_labels() -> void:
	suppress_numeric_callbacks = true
	if move_x_value_input != null:
		move_x_value_input.value = move_x_slider.value
	if move_y_value_input != null:
		move_y_value_input.value = move_y_slider.value
	suppress_numeric_callbacks = false

func _resolve_node_with_fallback(path: NodePath, fallback_path: NodePath) -> Node:
	if not path.is_empty():
		var explicit_node := get_node_or_null(path)
		if explicit_node != null:
			return explicit_node

	return get_node_or_null(fallback_path)

func _find_slot_option_index(slot_name: String) -> int:
	if slot_option == null or slot_name.is_empty():
		return -1
	for idx in range(slot_option.item_count):
		var candidate := slot_option.get_item_metadata(idx) as String
		if candidate == slot_name:
			return idx
	return -1

func _find_item_option_index(definition: ItemDefinition) -> int:
	if item_option == null:
		return -1
	if definition == null:
		return 0
	for idx in range(item_option.item_count):
		var candidate := item_option.get_item_metadata(idx) as ItemDefinition
		if candidate == definition:
			return idx
		if candidate != null and definition != null and not candidate.id.is_empty() and candidate.id == definition.id:
			return idx
		if candidate != null and definition != null and not candidate.resource_path.is_empty() and candidate.resource_path == definition.resource_path:
			return idx
	return -1
