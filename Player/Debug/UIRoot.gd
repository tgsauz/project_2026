extends CanvasLayer
class_name UIRoot

# ============================================================
# CONFIG
# ============================================================

@export var debug_enabled: bool = true  # master switch
@export var ui_style: UIStyleProfile
@export var accent_preset: UIStyleProfile.AccentPreset = UIStyleProfile.AccentPreset.TEAL
@export var presentation_tier: UIStyleProfile.PresentationTier = UIStyleProfile.PresentationTier.LOW

# ============================================================
# REFERENCES
# ============================================================
var gameplay_layer: Control
var debug_layer: Control
var debug_stats_ui: DebugStatsUI
var crosshair_ui: CrosshairUI
var interact_prompt_ui: InteractionPromptUI
var status_cluster_ui: StatusClusterUI
var quick_action_panel_ui: QuickActionPanelUI
var runtime_ui_style: UIStyleProfile

# ============================================================
# INIT
# ============================================================

func _ready():
	gameplay_layer = get_node_or_null("GameplayLayer") as Control
	debug_layer = get_node_or_null("DebugLayer") as Control
	debug_stats_ui = get_node_or_null("DebugLayer/DebugStatsUI") as DebugStatsUI
	crosshair_ui = get_node_or_null("GameplayLayer/HUD/Crosshair") as CrosshairUI
	interact_prompt_ui = get_node_or_null("GameplayLayer/HUD/InteractPrompt") as InteractionPromptUI
	status_cluster_ui = get_node_or_null("GameplayLayer/HUD/StatusContainer") as StatusClusterUI
	quick_action_panel_ui = get_node_or_null("MenuLayer/MenuRoot/QuickActionPanel") as QuickActionPanelUI

	assert(gameplay_layer != null)
	assert(debug_layer != null)
	runtime_ui_style = _build_runtime_style()
	_apply_ui_style()
	
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
	if status_cluster_ui != null and status_cluster_ui.has_method("bind_character"):
		status_cluster_ui.bind_character(character)
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
	if interact_prompt_ui != null:
		interact_prompt_ui.set_prompt_data(prompt_data)
	if crosshair_ui != null:
		crosshair_ui.set_focus_active(not prompt_data.is_empty())

func _on_quick_action_menu_changed(prompt_data: Dictionary, actions: Array, selected_index: int, is_open: bool) -> void:
	if quick_action_panel_ui != null:
		quick_action_panel_ui.set_actions(prompt_data, actions, selected_index, is_open)

func _build_runtime_style() -> UIStyleProfile:
	var style_instance: UIStyleProfile = ui_style.duplicate(true) if ui_style != null else UIStyleProfile.new()
	style_instance.accent_preset = accent_preset
	style_instance.presentation_tier = presentation_tier
	return style_instance

func _apply_ui_style() -> void:
	for component in [crosshair_ui, interact_prompt_ui, status_cluster_ui, quick_action_panel_ui, debug_stats_ui]:
		if component != null and component.has_method("apply_style"):
			component.apply_style(runtime_ui_style)
