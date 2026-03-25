extends CanvasLayer
class_name UIRoot

# ============================================================
# CONFIG
# ============================================================

@export var debug_enabled: bool = true  # master switch

# ============================================================
# REFERENCES
# ============================================================
@export var gameplay_layer_path: NodePath
@export var debug_layer_path: NodePath

var gameplay_layer
var debug_layer

# ============================================================
# INIT
# ============================================================

func _ready():
	
	gameplay_layer = get_node(gameplay_layer_path)
	debug_layer = get_node(debug_layer_path)
	
	assert(gameplay_layer != null)
	assert(debug_layer != null)
	
	# Gameplay always visible
	gameplay_layer.visible = true
	
	# Debug hidden by default
	debug_layer.visible = false
# ============================================================
# INPUT
# ============================================================

func _input(event):
	if not debug_enabled:
		return
	
	if event.is_action_pressed("toggle_debug"):
		debug_layer.visible = !debug_layer.visible
