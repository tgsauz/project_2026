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
var interact_prompt: Control
var prompt_name_label: Label
var prompt_tooltip_label: Label
var quick_action_title_label: Label
var quick_action_list_label: Label

# ============================================================
# INIT
# ============================================================

func _ready():
	gameplay_layer = get_node_or_null("GameplayLayer") as Control
	debug_layer = get_node_or_null("DebugLayer") as Control
	debug_stats_ui = get_node_or_null("DebugLayer/DebugStatsUI") as Control
	interact_prompt = get_node_or_null("GameplayLayer/HUD/InteractPrompt") as Control
	prompt_name_label = get_node_or_null("GameplayLayer/HUD/InteractPrompt/NameLabel") as Label
	prompt_tooltip_label = get_node_or_null("GameplayLayer/HUD/InteractPrompt/TooltipLabel") as Label
	quick_action_title_label = get_node_or_null("MenuLayer/MenuRoot/QuickActionPanel/TitleLabel") as Label
	quick_action_list_label = get_node_or_null("MenuLayer/MenuRoot/QuickActionPanel/ActionsLabel") as Label

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
	if character != null:
		var interaction = character.get_node_or_null("InteractionComponent")
		if interaction != null and not interaction.focus_changed.is_connected(_on_focus_changed):
			interaction.focus_changed.connect(_on_focus_changed)
		if character.has_signal("quick_action_menu_changed") and not character.is_connected("quick_action_menu_changed", Callable(self, "_on_quick_action_menu_changed")):
			character.connect("quick_action_menu_changed", Callable(self, "_on_quick_action_menu_changed"))

	_on_focus_changed({})
	_on_quick_action_menu_changed({}, [], 0, false)
# ============================================================
# INPUT
# ============================================================

func _input(event):
	if not debug_enabled:
		return
	
	if event.is_action_pressed("toggle_debug"):
		debug_layer.visible = !debug_layer.visible

# ============================================================
#  UI BINDINGS
# ============================================================

func _on_focus_changed(prompt_data: Dictionary) -> void:
	if interact_prompt == null or prompt_name_label == null or prompt_tooltip_label == null:
		return

	var has_prompt := not prompt_data.is_empty()
	interact_prompt.visible = has_prompt
	if not has_prompt:
		prompt_name_label.text = ""
		prompt_tooltip_label.text = ""
		return

	prompt_name_label.text = prompt_data.get("title", "")
	var interact_label := str(prompt_data.get("interact_label", ""))
	var quick_action_label := str(prompt_data.get("quick_action_label", ""))
	var prompt_segments: Array[String] = []
	if not interact_label.is_empty():
		prompt_segments.append(interact_label)
	if not quick_action_label.is_empty():
		prompt_segments.append(quick_action_label)
	if not str(prompt_data.get("tooltip", "")).is_empty():
		prompt_segments.append(str(prompt_data.get("tooltip", "")))
	prompt_tooltip_label.text = "  ".join(prompt_segments)

func _on_quick_action_menu_changed(prompt_data: Dictionary, actions: Array, selected_index: int, is_open: bool) -> void:
	if quick_action_title_label == null or quick_action_list_label == null:
		return

	var panel := quick_action_title_label.get_parent()
	if panel != null:
		panel.visible = is_open

	if not is_open:
		quick_action_title_label.text = ""
		quick_action_list_label.text = ""
		return

	quick_action_title_label.text = prompt_data.get("title", "Actions")
	var lines: Array[String] = []
	for action_index in range(actions.size()):
		var action: Dictionary = actions[action_index]
		var prefix := "> " if action_index == selected_index else "  "
		lines.append("%s%s" % [prefix, action.get("label", "")])
	quick_action_list_label.text = "\n".join(lines)
