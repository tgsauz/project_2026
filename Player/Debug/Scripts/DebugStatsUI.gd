extends Control

# ============================================================
#  REFERENCES
# ============================================================

var character: Node
var controller: CharacterController
var inventory: InventoryComponent

var speed_label: Label
var velocity_label: Label
var load_label: Label
var weight_label: Label
# ============================================================
#  INIT
# ============================================================

func _ready():
	speed_label = get_node_or_null("Panel/VBoxContainer/SpeedLabel") as Label
	velocity_label = get_node_or_null("Panel/VBoxContainer/VelocityLabel") as Label
	load_label = get_node_or_null("Panel/VBoxContainer/LoadLabel") as Label
	weight_label = get_node_or_null("Panel/VBoxContainer/WeightLabel") as Label

	assert(speed_label != null)
	assert(velocity_label != null)
	assert(load_label != null)
	assert(weight_label != null)

func bind_character(new_character: Node) -> void:
	character = new_character
	controller = new_character as CharacterController

	if controller == null:
		push_warning("DebugStatsUI.bind_character expected CharacterController.")
		inventory = null
		return

	inventory = controller.get_inventory_component()

# ============================================================
#  UPDATE LOOP
# ============================================================

func _process(_delta):
	if controller == null or speed_label == null:
		return
	
	_update_speed()
	_update_velocity()
	_update_load()
	_update_weight()

# ============================================================
#  UI UPDATES
# ============================================================

func _update_speed():
	var speed = controller.velocity.length()
	speed_label.text = "Speed: %.2f" % speed

func _update_velocity():
	var v = controller.velocity
	velocity_label.text = "Velocity: (%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]

func _update_load():
	load_label.text = "Load: %.2f" % controller.load_factor

func _update_weight():
	if inventory != null:
		weight_label.text = "Weight: %.2f" % inventory.get_total_weight()
