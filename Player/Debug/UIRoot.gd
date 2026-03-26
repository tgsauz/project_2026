extends CanvasLayer
class_name UIRoot

# ============================================================
# CONFIG
# ============================================================

@export var debug_enabled: bool = true  # master switch

# ============================================================
# REFERENCES
# ============================================================
var gameplay_layer: Control
var debug_layer: Control
var debug_stats_ui: Control

# ============================================================
# INIT
# ============================================================

func _ready():
	gameplay_layer = get_node_or_null("GameplayLayer") as Control
	debug_layer = get_node_or_null("DebugLayer") as Control
	debug_stats_ui = get_node_or_null("DebugLayer/DebugStatsUI") as Control

	assert(gameplay_layer != null)
	assert(debug_layer != null)
	
	# Gameplay always visible
	gameplay_layer.visible = true
	
	# Debug hidden by default
	debug_layer.visible = false

	var parent_character := get_parent()
	if parent_character != null:
		bind_character(parent_character)

func bind_character(character: Node) -> void:
	if debug_stats_ui != null and debug_stats_ui.has_method("bind_character"):
		debug_stats_ui.bind_character(character)
# ============================================================
# INPUT
# ============================================================

func _input(event):
	if not debug_enabled:
		return
	
	if event.is_action_pressed("toggle_debug"):
		debug_layer.visible = !debug_layer.visible
