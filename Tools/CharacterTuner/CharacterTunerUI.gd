extends CanvasLayer

# ============================================================
#  CHARACTER TUNER UI (PREMIUM VERSION)
# ============================================================

@export var controller: Node 
@export var slot_list: VBoxContainer
@export var transform_panel: Control
@export var selection_controls: Control
@export var slider_controls: Control

@export_group("Selection")
@export var item_dropdown: OptionButton
@export var profile_dropdown: OptionButton

@export_group("Transform Sliders")
@export var pos_x_slider: Slider
@export var pos_y_slider: Slider
@export var pos_z_slider: Slider
@export var rot_x_slider: Slider
@export var rot_y_slider: Slider
@export var rot_z_slider: Slider
@export var sca_x_slider: Slider
@export var sca_y_slider: Slider
@export var sca_z_slider: Slider

@export_group("Value Fields")
@export var pos_x_val: LineEdit
@export var pos_y_val: LineEdit
@export var pos_z_val: LineEdit
@export var rot_x_val: LineEdit
@export var rot_y_val: LineEdit
@export var rot_z_val: LineEdit
@export var sca_x_val: LineEdit
@export var sca_y_val: LineEdit
@export var sca_z_val: LineEdit

@export_group("Animation Controls")
@export var move_x_slider: Slider
@export var move_y_slider: Slider

@export_group("Styling Containers")
@export var sidebar_panel: Panel
@export var tuning_panel_container: Panel
@export var anim_panel_container: Panel

@export_group("Styling Labels")
@export var sidebar_header: Label
@export var tuning_header: Label
@export var anim_header: Label
@export var setting_labels: Array[Label] = []

@export_group("System")
@export var save_button: Button
@export var reset_button: Button
@export var confirmation_dialog: ConfirmationDialog
@export var notification_panel: Control
@export var notification_label: Label
@export var notification_anim: AnimationPlayer
@export var ui_style: Resource # UIStyleProfile

var current_slot: String = ""
var current_item: ItemDefinition = null
var current_profile: ItemVisualAttachmentProfile = null
var displayed_items: Array[ItemDefinition] = []
var displayed_profiles: Array[ItemVisualAttachmentProfile] = []
var slot_group: ButtonGroup = ButtonGroup.new()

var _initial_profile_state: Dictionary = {}
var _pending_action: String = ""

func _ready():
	controller.item_list_updated.connect(_on_items_updated)
	controller.profile_changed.connect(_on_profile_changed)
	confirmation_dialog.confirmed.connect(_on_dialog_confirmed)
	_setup_ui()
	_on_items_updated() # Ensure slots populate if signal was missed
	
	if ui_style:
		apply_style(ui_style)
		
	_update_visibility()

func apply_style(style: UIStyleProfile):
	if style == null: return
	
	# 1. Apply Panel Styles
	var default_panel = style.make_panel_style("default")
	var elevated_panel = style.make_panel_style("elevated")
	var debug_panel = style.make_panel_style("debug")
	
	if sidebar_panel: sidebar_panel.add_theme_stylebox_override("panel", default_panel)
	if tuning_panel_container: tuning_panel_container.add_theme_stylebox_override("panel", elevated_panel)
	if anim_panel_container: anim_panel_container.add_theme_stylebox_override("panel", elevated_panel)
	if notification_panel is PanelContainer:
		notification_panel.add_theme_stylebox_override("panel", debug_panel)
	
	# 2. Apply Label Styles
	var title_settings = style.make_label_settings("title")
	var body_settings = style.make_label_settings("body")
	var _accent_settings = style.make_label_settings("accent")
	
	if sidebar_header: sidebar_header.label_settings = title_settings
	if tuning_header: tuning_header.label_settings = title_settings
	if anim_header: anim_header.label_settings = title_settings
	
	for label in setting_labels:
		if label: label.label_settings = body_settings
		
	# Update existing value fields (LineEdits)
	var value_fields = [pos_x_val, pos_y_val, pos_z_val, rot_x_val, rot_y_val, rot_z_val, sca_x_val, sca_y_val, sca_z_val]
	for field in value_fields:
		if field:
			field.add_theme_color_override("font_color", style.get_accent_color())
			field.add_theme_font_override("font", style.get_font())
			field.add_theme_font_size_override("font_size", style.base_font_size)

	# 3. Handle HIGH Tier Transitions
	if style.presentation_tier == UIStyleProfile.PresentationTier.HIGH:
		# We'll use smooth fades for panel visibility if we wanted to
		pass

func _on_items_updated():
	for child in slot_list.get_children():
		child.queue_free()
		
	for slot in controller.active_slots:
		var btn = Button.new()
		btn.text = slot.replace("_", " ").capitalize()
		btn.toggle_mode = true
		btn.button_group = slot_group
		btn.pressed.connect(_on_slot_selected.bind(slot))
		slot_list.add_child(btn)

func _on_slot_selected(slot_name: String):
	current_slot = slot_name
	_refresh_item_dropdown()
	_update_visibility()

func _on_profile_changed(slot_name: String, profile: ItemVisualAttachmentProfile):
	if slot_name == current_slot:
		# If switching to a NEW profile or refreshed from disk, update UI
		current_profile = profile
		# Capture restore point from the state as it was when loaded
		_initial_profile_state = {
			"position": profile.position,
			"rotation": profile.rotation_degrees,
			"scale": profile.scale
		}
		_update_sliders_from_profile(profile)

func _update_sliders_from_profile(profile: ItemVisualAttachmentProfile):
	# We disconnect and reconnect to avoid 'feedback loop' during batch set
	_set_slider_values_silent(profile)
	_sync_all_values()

func _set_slider_values_silent(profile: ItemVisualAttachmentProfile):
	# We block signals while setting values to prevent many calls to controller
	pos_x_slider.set_value_no_signal(profile.position.x)
	pos_y_slider.set_value_no_signal(profile.position.y)
	pos_z_slider.set_value_no_signal(profile.position.z)
	rot_x_slider.set_value_no_signal(profile.rotation_degrees.x)
	rot_y_slider.set_value_no_signal(profile.rotation_degrees.y)
	rot_z_slider.set_value_no_signal(profile.rotation_degrees.z)
	sca_x_slider.set_value_no_signal(profile.scale.x)
	sca_y_slider.set_value_no_signal(profile.scale.y)
	sca_z_slider.set_value_no_signal(profile.scale.z)

func _refresh_item_dropdown():
	item_dropdown.clear()
	item_dropdown.add_item("-- Select Item --")
	displayed_items.clear()
	
	if current_slot == "": return
	
	var items = controller.get_items_for_slot(current_slot)
	for item in items:
		item_dropdown.add_item(item.display_name)
		displayed_items.append(item)

func _on_item_selected(index: int):
	# index 0 is placeholder
	if index == 0:
		current_item = null
		_update_visibility()
		return
		
	current_item = displayed_items[index - 1]
	_refresh_profile_dropdown(current_item)
	
	# This will trigger controller to equip and emit profile_changed
	controller.equip_item(current_slot, current_item)
	_update_visibility()

func _refresh_profile_dropdown(definition: ItemDefinition):
	profile_dropdown.clear()
	profile_dropdown.add_item("-- Select Profile --")
	displayed_profiles.clear()
	
	var profiles = definition.attachment_profiles
	for i in range(profiles.size()):
		var profile = profiles[i]
		if profile.slot_name != current_slot: continue
		
		profile_dropdown.add_item("Profile %d (%s)" % [i, profile.visual_state])
		displayed_profiles.append(profile)
	
	if displayed_profiles.is_empty():
		profile_dropdown.add_item("New Profile (Auto)")

func _on_profile_dropdown_selected(index: int):
	if index == 0: return
	
	if not displayed_profiles.is_empty():
		var profile = displayed_profiles[index - 1]
		# Ensure we are using the fresh object from the list
		controller.equip_item(current_slot, current_item, profile)
	else:
		controller.equip_item(current_slot, current_item)

func _on_value_changed(_value: float):
	if current_slot == "" or current_profile == null: return
	
	var pos = Vector3(pos_x_slider.value, pos_y_slider.value, pos_z_slider.value)
	var rot = Vector3(rot_x_slider.value, rot_y_slider.value, rot_z_slider.value)
	var sca = Vector3(sca_x_slider.value, sca_y_slider.value, sca_z_slider.value)
	
	controller.update_offset(current_slot, pos, rot, sca)
	
	# Update the working profile object
	current_profile.position = pos
	current_profile.rotation_degrees = rot
	current_profile.scale = sca
	_sync_all_values()

func _sync_all_values():
	pos_x_val.text = "%.2f" % pos_x_slider.value
	pos_y_val.text = "%.2f" % pos_y_slider.value
	pos_z_val.text = "%.2f" % pos_z_slider.value
	rot_x_val.text = "%.0f" % rot_x_slider.value
	rot_y_val.text = "%.0f" % rot_y_slider.value
	rot_z_val.text = "%.0f" % rot_z_slider.value
	sca_x_val.text = "%.2f" % sca_x_slider.value
	sca_y_val.text = "%.2f" % sca_y_slider.value
	sca_z_val.text = "%.2f" % sca_z_slider.value

func _on_anim_value_changed(_value: float):
	var lateral = move_x_slider.value
	var forward = move_y_slider.value
	controller.set_animation_blend(lateral, forward)

func _on_save_pressed():
	if current_slot != "" and current_item != null and current_profile != null:
		_pending_action = "save"
		confirmation_dialog.dialog_text = "Save changes to %s for item %s?" % [current_slot, current_item.display_name]
		confirmation_dialog.popup_centered()

func _on_reset_pressed():
	if current_profile:
		_pending_action = "reset"
		confirmation_dialog.dialog_text = "Reset all transforms to original state?"
		confirmation_dialog.popup_centered()

func _on_dialog_confirmed():
	if _pending_action == "save":
		controller.save_profile(current_slot, current_item, current_profile)
		show_notification("Saved Successfully")
	elif _pending_action == "reset":
		# Re-apply initial snapshot values to the object
		current_profile.position = _initial_profile_state["position"]
		current_profile.rotation_degrees = _initial_profile_state["rotation"]
		current_profile.scale = _initial_profile_state["scale"]
		
		# Refresh UI and notify controller
		_update_sliders_from_profile(current_profile)
		controller.update_offset(current_slot, current_profile.position, current_profile.rotation_degrees, current_profile.scale)
		show_notification("Transforms Reset")
	
	_pending_action = ""

func show_notification(text: String):
	notification_label.text = text
	notification_anim.stop()
	notification_anim.play("show")

func _update_visibility():
	var has_slot = current_slot != ""
	var has_item = current_item != null
	
	transform_panel.visible = has_slot
	selection_controls.visible = has_slot
	slider_controls.visible = has_item

func _setup_ui():
	# Connect transform sliders
	var sliders = [
		pos_x_slider, pos_y_slider, pos_z_slider, 
		rot_x_slider, rot_y_slider, rot_z_slider, 
		sca_x_slider, sca_y_slider, sca_z_slider
	]
	for s in sliders:
		if s: s.value_changed.connect(_on_value_changed)
			
	# Connect dropdowns
	item_dropdown.item_selected.connect(_on_item_selected)
	profile_dropdown.item_selected.connect(_on_profile_dropdown_selected)
			
	# Connect anim sliders
	move_x_slider.value_changed.connect(_on_anim_value_changed)
	move_y_slider.value_changed.connect(_on_anim_value_changed)
	
	# Connect system buttons
	save_button.pressed.connect(_on_save_pressed)
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
