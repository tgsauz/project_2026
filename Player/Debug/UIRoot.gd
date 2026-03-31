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
var bounding_box_ui: BoundingBoxVisualUI
var runtime_ui_style: UIStyleProfile
var optimization_context: UIOptimizationContext
var layout_manager: ResponsiveLayoutManager
var player_character: Node

# Inventory UI Components (Phase 4)
var inventory_view_controller: InventoryViewController
var inventory_overlay_ui: InventoryOverlayUI
var inventory_slot_panel_ui: InventorySlotPanelUI
var inventory_action_menu: InventoryItemActionMenu
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
	
	# Store UI profile in metadata for other scripts to reference
	set_meta("ui_profile", runtime_ui_style)
	
	# Initialize responsive layout manager
	layout_manager = ResponsiveLayoutManager.new(runtime_ui_style)
	add_child(layout_manager)
	
	_apply_ui_style()
	_register_layout_components()
	
	# Gameplay always visible
	gameplay_layer.visible = true

	# Debug hidden by default
	debug_layer.visible = false

	# Track owning character
	player_character = get_parent()
	if player_character != null:
		bind_character(player_character)

	# Create optional bounding box overlay as HUD layer
	if gameplay_layer != null:
		var hud_layer = gameplay_layer.get_node_or_null("HUD") as Control
		if hud_layer != null:
			bounding_box_ui = BoundingBoxVisualUI.new()
			hud_layer.add_child(bounding_box_ui)
			bounding_box_ui.apply_style(runtime_ui_style)
	
	# Initialize inventory UI components (Phase 4)
	_initialize_inventory_ui()
	
	# Initialize debug inventory inspector (Phase 5)
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
#  UI BINDINGS
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
	for component in [crosshair_ui, interact_prompt_ui, status_cluster_ui, quick_action_panel_ui, debug_stats_ui, bounding_box_ui, inventory_overlay_ui, inventory_slot_panel_ui, inventory_action_menu, inventory_tooltip_ui, debug_inventory_inspector]:
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
# INVENTORY UI INITIALIZATION (Phase 4)
# ============================================================

func _initialize_inventory_ui() -> void:
	if gameplay_layer == null:
		return
	
	var hud_layer = gameplay_layer.get_node_or_null("HUD") as Control
	if hud_layer == null:
		return
	
	# Create Camera/Inventory controller
	inventory_view_controller = InventoryViewController.new()
	inventory_view_controller.name = "InventoryViewController"
	add_child(inventory_view_controller)
	
	if player_character != null:
		inventory_view_controller.set_character(player_character)
	
	# Create Attachment line overlay (Control-based, 2D rendering)
	inventory_overlay_ui = InventoryOverlayUI.new()
	inventory_overlay_ui.name = "InventoryOverlayUI"
	inventory_overlay_ui.modulate.a = 0.0  # Initially hidden
	hud_layer.add_child(inventory_overlay_ui)
	
	if player_character != null:
		inventory_overlay_ui.set_character(player_character)
	
	# Create Item selection panel (VBoxContainer-based scene)
	inventory_slot_panel_ui = InventorySlotPanelUI.new()
	inventory_slot_panel_ui.name = "InventorySlotPanel"
	inventory_slot_panel_ui.modulate.a = 0.0  # Initially hidden
	hud_layer.add_child(inventory_slot_panel_ui)
	
	# Create Action menu (HBoxContainer-based scene)
	inventory_action_menu = InventoryItemActionMenu.new()
	inventory_action_menu.name = "InventoryActionMenu"
	inventory_action_menu.modulate.a = 0.0  # Initially hidden
	hud_layer.add_child(inventory_action_menu)
	
	# Create 3D Inspect Viewer (Control-based Canvas)
	inventory_inspect_ui = ItemInspectUI.new()
	inventory_inspect_ui.name = "ItemInspectUI"
	hud_layer.add_child(inventory_inspect_ui)
	
	# Create Item Tooltip (Phase 5)
	inventory_tooltip_ui = ItemTooltipUI.new()
	inventory_tooltip_ui.name = "ItemTooltipUI"
	hud_layer.add_child(inventory_tooltip_ui)
	
	# Apply style to all newly created nodes
	if inventory_overlay_ui: inventory_overlay_ui.apply_style(runtime_ui_style)
	if inventory_slot_panel_ui: inventory_slot_panel_ui.apply_style(runtime_ui_style)
	if inventory_action_menu: inventory_action_menu.apply_style(runtime_ui_style)
	if inventory_inspect_ui: inventory_inspect_ui.apply_style(runtime_ui_style)
	if inventory_tooltip_ui: inventory_tooltip_ui.apply_style(runtime_ui_style)
	
	# Wire signals: Camera mode toggle → UI visibility
	inventory_view_controller.inventory_mode_changed.connect(_on_inventory_mode_changed)
	
	# Wire signals: Overlay line click / deselect → Accordion transitions
	inventory_overlay_ui.slot_line_clicked.connect(_on_slot_line_clicked)
	inventory_overlay_ui.deselected.connect(_on_deselected)
	
	# Wire signals: Item selection → Action menu populate
	inventory_slot_panel_ui.item_selected.connect(_on_item_selected)
	
	# Wire signals: Item hover → Tooltip
	inventory_slot_panel_ui.item_hovered.connect(_on_item_hovered)
	inventory_slot_panel_ui.item_unhovered.connect(_on_item_unhovered)
	
	# Wire signals: Action selection → Execute and refresh
	inventory_action_menu.item_action_selected.connect(_on_item_action_selected)

func _initialize_debug_inventory_ui() -> void:
	if debug_layer == null:
		return
	debug_inventory_inspector = DebugInventoryInspector.new()
	debug_inventory_inspector.name = "DebugInventoryInspector"
	debug_layer.add_child(debug_inventory_inspector)
	if runtime_ui_style:
		debug_inventory_inspector.apply_style(runtime_ui_style)

func _on_deselected() -> void:
	if inventory_slot_panel_ui: inventory_slot_panel_ui.clear()
	if inventory_action_menu: inventory_action_menu.clear()
	if inventory_inspect_ui and inventory_inspect_ui.active: inventory_inspect_ui._close()
	if inventory_tooltip_ui: inventory_tooltip_ui.hide_tooltip()

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
		if inventory_slot_panel_ui: inventory_slot_panel_ui.clear()
		if inventory_action_menu: inventory_action_menu.clear()
		if inventory_tooltip_ui: inventory_tooltip_ui.hide_tooltip()

func _on_slot_line_clicked(slot_name: String) -> void:
	if inventory_slot_panel_ui == null or player_character == null:
		return
	
	# Query inventory component for items in this slot
	var inventory = player_character.get_node_or_null("InventoryComponent") as Node
	if inventory == null or not inventory.has_method("get_slot_state"):
		return
	
	var slot_state = inventory.get_slot_state(slot_name)
	var ui_items = []
	if slot_state:
		var main_item = slot_state.get("item")
		if main_item != null:
			if main_item.has_method("is_container") and main_item.is_container():
				for nested_id in main_item.contained_item_ids:
					var nested = inventory.get_item_instance(str(nested_id))
					if nested:
						ui_items.append({
							"id": nested.instance_id,
							"name": nested.get_display_name() if nested.has_method("get_display_name") else nested.definition.item_name,
							"quantity": nested.stack_count
						})
			else:
				ui_items.append({
					"id": main_item.instance_id,
					"name": main_item.get_display_name() if main_item.has_method("get_display_name") else main_item.definition.item_name,
					"quantity": main_item.stack_count
				})
				
	inventory_slot_panel_ui.set_slot_items(slot_name, ui_items)
	inventory_slot_panel_ui.set_inventory_component(inventory)
	
	inventory_overlay_ui.expand_slot(slot_name, inventory_slot_panel_ui)
	inventory_action_menu.clear()

func _on_item_selected(item) -> void:
	if inventory_action_menu == null:
		return
	
	# Get current slot from panel
	var slot_name = inventory_slot_panel_ui._current_slot
	inventory_action_menu.set_item(item, slot_name)
	
	inventory_overlay_ui.expand_action(inventory_action_menu, inventory_slot_panel_ui)

func _on_item_hovered(item_dict: Dictionary, screen_pos: Vector2) -> void:
	if inventory_tooltip_ui:
		inventory_tooltip_ui.show_tooltip(item_dict, screen_pos)

func _on_item_unhovered() -> void:
	if inventory_tooltip_ui:
		inventory_tooltip_ui.hide_tooltip()

func _on_item_action_selected(action_id: String) -> void:
	if player_character == null:
		return
	
	var inventory = player_character.get_node_or_null("InventoryComponent") as Node
	if inventory == null:
		return
	
	var item = inventory_action_menu._current_item
	if item == null: return
	var item_id = item.get("id", "")
	
	# Execute action
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
			if inventory.has_method("get_item_instance"):
				var instance = inventory.get_item_instance(item_id)
				if instance != null and instance.get("definition"):
					inventory_inspect_ui.inspect_item(instance.definition)
					
	# Refresh panel with updated inventory
	if action_id != "inspect":
		var current_slot = inventory_slot_panel_ui._current_slot
		_on_slot_line_clicked(current_slot)
	inventory_action_menu.clear()

# ============================================================
# OPTIMIZATION
# ============================================================

func get_optimization_context() -> UIOptimizationContext:
	return optimization_context

func get_layout_manager() -> ResponsiveLayoutManager:
	return layout_manager
