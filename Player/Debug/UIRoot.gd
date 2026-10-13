extends CanvasLayer
class_name UIRoot

# ============================================================
# CONFIG
# ============================================================

@export var debug_enabled: bool = true
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
var bounding_box_ui: BoundingBoxVisualUI
var runtime_ui_style: UIStyleProfile
var optimization_context: UIOptimizationContext
var layout_manager: ResponsiveLayoutManager
var player_character: Node

var inventory_view_controller: InventoryViewController
var inventory_overlay_ui: InventoryOverlayUI
var inventory_slot_panel_ui: InventorySlotPanelUI
var inventory_inspect_ui: ItemInspectUI
var inventory_tooltip_ui: ItemTooltipUI
var debug_inventory_inspector: DebugInventoryInspector

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
	optimization_context = UIOptimizationContext.new(runtime_ui_style, debug_enabled)
	set_meta("ui_profile", runtime_ui_style)

	layout_manager = ResponsiveLayoutManager.new(runtime_ui_style)
	add_child(layout_manager)

	_apply_ui_style()
	_register_layout_components()

	gameplay_layer.visible = true
	debug_layer.visible = false

	player_character = get_parent()
	if player_character != null:
		bind_character(player_character)

	if gameplay_layer != null:
		var hud_layer = gameplay_layer.get_node_or_null("HUD") as Control
		if hud_layer != null:
			bounding_box_ui = BoundingBoxVisualUI.new()
			hud_layer.add_child(bounding_box_ui)
			bounding_box_ui.apply_style(runtime_ui_style)

	_initialize_inventory_ui()
	_initialize_debug_inventory_ui()

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
# UI BINDINGS
# ============================================================

func _on_focus_changed(prompt_data: Dictionary) -> void:
	if interact_prompt_ui != null:
		interact_prompt_ui.set_prompt_data(prompt_data)
	if crosshair_ui != null:
		crosshair_ui.set_focus_active(not prompt_data.is_empty())
	_update_bounding_box_target()

func _on_quick_action_menu_changed(prompt_data: Dictionary, actions: Array, selected_index: int, is_open: bool) -> void:
	if quick_action_panel_ui != null:
		quick_action_panel_ui.set_actions(prompt_data, actions, selected_index, is_open)

func _build_runtime_style() -> UIStyleProfile:
	var style_instance: UIStyleProfile = ui_style.duplicate(true) if ui_style != null else UIStyleProfile.new()
	style_instance.accent_preset = accent_preset
	style_instance.presentation_tier = presentation_tier
	return style_instance

func _apply_ui_style() -> void:
	for component in [crosshair_ui, interact_prompt_ui, status_cluster_ui, quick_action_panel_ui, debug_stats_ui, bounding_box_ui, inventory_overlay_ui, inventory_slot_panel_ui, inventory_inspect_ui, inventory_tooltip_ui, debug_inventory_inspector]:
		if component != null and component.has_method("apply_style"):
			component.apply_style(runtime_ui_style)

func _update_bounding_box_target() -> void:
	if bounding_box_ui == null:
		return
	if player_character == null:
		bounding_box_ui.set_target(null)
		return

	var interaction = player_character.get_node_or_null("InteractionComponent") as InteractionComponent
	if interaction == null:
		bounding_box_ui.set_target(null)
		return

	bounding_box_ui.set_target(interaction.current_target)

func _register_layout_components() -> void:
	if layout_manager == null:
		return
	if status_cluster_ui != null:
		layout_manager.register_component(status_cluster_ui)
	if interact_prompt_ui != null:
		layout_manager.register_component(interact_prompt_ui)
	if quick_action_panel_ui != null:
		layout_manager.register_component(quick_action_panel_ui)

# ============================================================
# INVENTORY UI
# ============================================================

func _initialize_inventory_ui() -> void:
	if gameplay_layer == null:
		return

	var hud_layer = gameplay_layer.get_node_or_null("HUD") as Control
	if hud_layer == null:
		return

	inventory_view_controller = InventoryViewController.new()
	inventory_view_controller.name = "InventoryViewController"
	add_child(inventory_view_controller)

	if player_character != null:
		inventory_view_controller.set_character(player_character)

	inventory_overlay_ui = InventoryOverlayUI.new()
	inventory_overlay_ui.name = "InventoryOverlayUI"
	inventory_overlay_ui.modulate.a = 0.0
	hud_layer.add_child(inventory_overlay_ui)

	if player_character != null:
		inventory_overlay_ui.set_character(player_character)
		inventory_overlay_ui.set_inventory_component(_get_inventory_component())
		inventory_overlay_ui.set_visuals_component(_get_visuals_component())

	inventory_slot_panel_ui = InventorySlotPanelUI.new()
	inventory_slot_panel_ui.name = "InventorySlotPanel"
	inventory_slot_panel_ui.modulate.a = 0.0
	hud_layer.add_child(inventory_slot_panel_ui)

	inventory_inspect_ui = ItemInspectUI.new()
	inventory_inspect_ui.name = "ItemInspectUI"
	hud_layer.add_child(inventory_inspect_ui)

	inventory_tooltip_ui = ItemTooltipUI.new()
	inventory_tooltip_ui.name = "ItemTooltipUI"
	hud_layer.add_child(inventory_tooltip_ui)

	var inventory_component := _get_inventory_component()
	if inventory_slot_panel_ui:
		inventory_slot_panel_ui.set_inventory_component(inventory_component)
	if inventory_tooltip_ui:
		inventory_tooltip_ui.set_inventory_component(inventory_component)

	if inventory_overlay_ui:
		inventory_overlay_ui.apply_style(runtime_ui_style)
	if inventory_slot_panel_ui:
		inventory_slot_panel_ui.apply_style(runtime_ui_style)
	if inventory_inspect_ui:
		inventory_inspect_ui.apply_style(runtime_ui_style)
	if inventory_tooltip_ui:
		inventory_tooltip_ui.apply_style(runtime_ui_style)

	inventory_view_controller.inventory_mode_changed.connect(_on_inventory_mode_changed)
	inventory_overlay_ui.slot_line_clicked.connect(_on_slot_line_clicked)
	inventory_overlay_ui.slot_line_hovered.connect(_on_slot_line_hovered)
	inventory_overlay_ui.slot_line_unhovered.connect(_on_slot_line_unhovered)
	inventory_overlay_ui.deselected.connect(_on_deselected)
	inventory_slot_panel_ui.item_action_requested.connect(_on_item_action_selected)
	inventory_slot_panel_ui.anchor_changed.connect(_on_inventory_panel_anchor_changed)
	_on_inventory_mode_changed(false)

func _initialize_debug_inventory_ui() -> void:
	if debug_layer == null:
		return
	debug_inventory_inspector = DebugInventoryInspector.new()
	debug_inventory_inspector.name = "DebugInventoryInspector"
	debug_layer.add_child(debug_inventory_inspector)
	debug_inventory_inspector.set_inventory_component(_get_inventory_component())
	debug_inventory_inspector.set_visuals_component(_get_visuals_component())
	if runtime_ui_style:
		debug_inventory_inspector.apply_style(runtime_ui_style)

func _on_deselected() -> void:
	if inventory_slot_panel_ui:
		inventory_slot_panel_ui.clear()
	if inventory_overlay_ui:
		inventory_overlay_ui.clear_selection()
	if inventory_inspect_ui and inventory_inspect_ui.active:
		inventory_inspect_ui._close()
	if inventory_tooltip_ui:
		inventory_tooltip_ui.hide_tooltip()

func _on_inventory_mode_changed(is_active: bool) -> void:
	if inventory_overlay_ui == null:
		return

	if player_character != null and player_character.has_method("set_inventory_mode_active"):
		player_character.set_inventory_mode_active(is_active)

	if crosshair_ui != null and crosshair_ui.has_method("set_cursor_mode"):
		crosshair_ui.set_cursor_mode(is_active)

	if is_active:
		inventory_overlay_ui.set_visibility(true)
		inventory_overlay_ui.update_lines()
	else:
		inventory_overlay_ui.set_visibility(false)
		if inventory_slot_panel_ui:
			inventory_slot_panel_ui.clear()
		if inventory_tooltip_ui:
			inventory_tooltip_ui.hide_tooltip()

func _on_slot_line_clicked(slot_name: String) -> void:
	if inventory_slot_panel_ui == null or player_character == null:
		return

	var inventory := _get_inventory_component()
	if inventory == null:
		return

	inventory_slot_panel_ui.set_slot_state(slot_name, inventory.get_slot_state(slot_name))
	inventory_overlay_ui.set_selected_slot(slot_name)
	_on_inventory_panel_anchor_changed(inventory_slot_panel_ui.get_accent_anchor_global_position())

func _on_slot_line_hovered(slot_name: String, screen_pos: Vector2) -> void:
	if inventory_tooltip_ui == null:
		return

	var inventory := _get_inventory_component()
	if inventory == null:
		return

	var slot_state := inventory.get_slot_state(slot_name)
	var main_item = slot_state.get("item", null) if not slot_state.is_empty() else null
	if main_item == null:
		inventory_tooltip_ui.hide_tooltip()
		return

	inventory_tooltip_ui.show_tooltip(InventorySlotPanelUI.normalize_item_payload(main_item, inventory), screen_pos)

func _on_slot_line_unhovered() -> void:
	if inventory_tooltip_ui:
		inventory_tooltip_ui.hide_tooltip()

func _on_inventory_panel_anchor_changed(global_pos: Vector2) -> void:
	if inventory_overlay_ui:
		inventory_overlay_ui.set_panel_anchor_global_position(global_pos)

func _on_item_action_selected(action_id: String, item: Dictionary) -> void:
	var inventory := _get_inventory_component()
	if inventory == null or item == null:
		return

	var item_id = item.get("id", "")

	match action_id:
		"equip", "move_to_hand":
			if inventory.has_method("move_item_to_hand"):
				inventory.move_item_to_hand(item_id)
		"drop":
			if inventory.has_method("drop_item"):
				inventory.drop_item(item_id)
		"stow", "unequip":
			if inventory.has_method("unequip_item"):
				inventory.unequip_item(item_id)
		"inspect":
			var instance = inventory.get_item_instance(item_id)
			if instance != null and instance.definition != null:
				inventory_inspect_ui.inspect_item(instance.definition)

	if action_id != "inspect":
		var current_slot = inventory_slot_panel_ui._current_slot
		if not current_slot.is_empty():
			_on_slot_line_clicked(current_slot)

func _get_inventory_component() -> InventoryComponent:
	if player_character == null:
		return null
	return player_character.get_node_or_null("InventoryComponent") as InventoryComponent

func _get_visuals_component() -> VisualsComponent:
	if player_character == null:
		return null
	return player_character.get_node_or_null("VisualsComponent") as VisualsComponent

# ============================================================
# OPTIMIZATION
# ============================================================

func get_optimization_context() -> UIOptimizationContext:
	return optimization_context

func get_layout_manager() -> ResponsiveLayoutManager:
	return layout_manager
