extends CanvasLayer

# ============================================================
#  CHARACTER TUNER UI
# ============================================================

@export var controller_path: NodePath
@onready var controller = get_node(controller_path)

@export var slot_list_path: NodePath
@onready var slot_list = get_node(slot_list_path)

@export var transform_panel_path: NodePath
@onready var transform_panel = get_node(transform_panel_path)

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

func _ready():
	controller.item_list_updated.connect(_on_items_updated)
	controller.profile_changed.connect(_on_profile_changed)
	_setup_ui()

func _on_items_updated():
	for child in slot_list.get_children():
		child.queue_free()
		
	for slot in controller.active_slots:
		var btn = Button.new()
		btn.text = slot.replace("_", " ").capitalize()
		btn.toggle_mode = true
		btn.pressed.connect(_on_slot_selected.bind(slot))
		slot_list.add_child(btn)

func _on_slot_selected(slot_name: String):
	current_slot = slot_name
	_refresh_item_list(slot_name)

func _on_profile_changed(slot_name: String, profile: ItemVisualAttachmentProfile):
	if slot_name == current_slot:
		current_profile = profile
		_update_sliders_from_profile(profile)

func _update_sliders_from_profile(profile: ItemVisualAttachmentProfile):
	get_node(pos_x_path).value = profile.position.x
	get_node(pos_y_path).value = profile.position.y
	get_node(pos_z_path).value = profile.position.z
	get_node(rot_x_path).value = profile.rotation_degrees.x
	get_node(rot_y_path).value = profile.rotation_degrees.y
	get_node(rot_z_path).value = profile.rotation_degrees.z
	get_node(sca_x_path).value = profile.scale.x

func _refresh_item_list(slot_name: String):
	# Clear previous item buttons
	for child in transform_panel.get_node("ItemList").get_children():
		child.queue_free()
		
	var items = controller.get_items_for_slot(slot_name)
	for item in items:
		var btn = Button.new()
		btn.text = item.display_name
		btn.pressed.connect(_on_item_selected.bind(item))
		transform_panel.get_node("ItemList").add_child(btn)

func _on_item_selected(definition: ItemDefinition):
	current_item = definition
	controller.equip_item(current_slot, definition)

func _on_value_changed(_value: float):
	if current_slot == "": return
	
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
	
	# Update temporary profile state for saving
	if current_profile:
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

func _setup_ui():
	# Connect transform sliders
	var sliders = [pos_x_path, pos_y_path, pos_z_path, rot_x_path, rot_y_path, rot_z_path, sca_x_path]
	for s_path in sliders:
		var s = get_node_or_null(s_path)
		if s:
			s.value_changed.connect(_on_value_changed)
			
	# Connect anim sliders
	get_node(move_x_path).value_changed.connect(_on_anim_value_changed)
	get_node(move_y_path).value_changed.connect(_on_anim_value_changed)
	
	# Connect save button
	get_node(save_button_path).pressed.connect(_on_save_pressed)
