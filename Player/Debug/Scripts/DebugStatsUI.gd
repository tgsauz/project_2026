extends Control

# ============================================================
#  REFERENCES
# ============================================================

@export var character_path: NodePath

var character
var controller
var inventory

# UI refs
@export var speed_label_path: NodePath
@export var velocity_label_path: NodePath
@export var load_label_path: NodePath
@export var weight_label_path: NodePath

var speed_label
var velocity_label
var load_label
var weight_label
# ============================================================
#  INIT
# ============================================================

func _ready():
	
	character = get_node(character_path)
	
	speed_label = get_node(speed_label_path)
	velocity_label = get_node(velocity_label_path)
	load_label = get_node(load_label_path)
	weight_label = get_node(weight_label_path)
	
	# assuming controller is on root
	controller = character
	
	# get inventory from controller
	inventory = controller.inventory

# ============================================================
#  UPDATE LOOP
# ============================================================

func _process(_delta):
	if controller == null:
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
