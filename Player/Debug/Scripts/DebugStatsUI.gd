extends Control
class_name DebugStatsUI

# ============================================================
#  REFERENCES
# ============================================================

var style_profile: UIStyleProfile
var character: Node
var controller: CharacterController
var inventory: InventoryComponent

var panel: Panel
var header_label: Label
var divider: ColorRect
var speed_label: Label
var velocity_label: Label
var load_label: Label
var weight_label: Label
var stamina_label: Label
# ============================================================
#  INIT
# ============================================================

func _ready():
	panel = get_node_or_null("Panel") as Panel
	header_label = get_node_or_null("Panel/VBoxContainer/HeaderLabel") as Label
	divider = get_node_or_null("Panel/VBoxContainer/Divider") as ColorRect
	speed_label = get_node_or_null("Panel/VBoxContainer/SpeedLabel") as Label
	velocity_label = get_node_or_null("Panel/VBoxContainer/VelocityLabel") as Label
	load_label = get_node_or_null("Panel/VBoxContainer/LoadLabel") as Label
	weight_label = get_node_or_null("Panel/VBoxContainer/WeightLabel") as Label
	stamina_label = get_node_or_null("Panel/VBoxContainer/StaminaLabel") as Label

	assert(panel != null)
	assert(header_label != null)
	assert(divider != null)
	assert(speed_label != null)
	assert(velocity_label != null)
	assert(load_label != null)
	assert(weight_label != null)
	assert(stamina_label != null)

func bind_character(new_character: Node) -> void:
	character = new_character
	controller = new_character as CharacterController

	if controller == null:
		push_warning("DebugStatsUI.bind_character expected CharacterController.")
		inventory = null
		return

	inventory = controller.get_inventory_component()

func apply_style(style: UIStyleProfile) -> void:
	style_profile = style
	if panel != null:
		panel.add_theme_stylebox_override("panel", style_profile.make_panel_style("debug"))
	if header_label != null:
		header_label.label_settings = style_profile.make_label_settings("accent")
		header_label.uppercase = true
	if divider != null:
		divider.color = style_profile.make_rule_color(1.4)

	for label in [speed_label, velocity_label, load_label, weight_label, stamina_label]:
		if label != null:
			label.label_settings = style_profile.make_label_settings("debug")
			label.uppercase = true

# ============================================================
#  UPDATE LOOP
# ============================================================

func _process(_delta):
	if controller == null or speed_label == null:
		return
	
	_update_speed()
	_update_velocity()
	_update_stamina()
	_update_load()
	_update_weight()

# ============================================================
#  UI UPDATES
# ============================================================

func _update_speed():
	var speed = controller.velocity.length()
	speed_label.text = "SPD   %.2f" % speed

func _update_velocity():
	var v = controller.velocity
	velocity_label.text = "VEL   (%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]

func _update_stamina():
	stamina_label.text = "STAM  %.0f / %.0f" % [controller.stamina, controller.stamina_max]

func _update_load():
	load_label.text = "LOAD  %.2f" % controller.load_factor

func _update_weight():
	if inventory != null:
		weight_label.text = "MASS  %.2f" % inventory.get_total_weight()
