## InventoryItemActionMenu
## Displays context-aware action buttons for a selected item (move, drop, stow)
extends PanelContainer

class_name InventoryItemActionMenu

## Emitted when an action is selected
signal item_action_selected(action_id: String)

@onready var title_label = Label.new()
@onready var action_container = HBoxContainer.new()

var _current_item = null
var _current_slot: String = ""
var _action_buttons: Dictionary = {}

var style_profile: UIStyleProfile
var fade_controller: UIFadeController

func apply_style(style: UIStyleProfile) -> void:
	style_profile = style
	if fade_controller == null:
		fade_controller = UIFadeController.new(self, style)
	else:
		fade_controller.style_profile = style
		
	# Apply styling via profile helpers
	add_theme_stylebox_override("panel", style_profile.make_panel_style("elevated"))
	title_label.label_settings = style_profile.make_label_settings("title")

func _ready() -> void:
	# Setup layout
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# Title label
	title_label.text = ""
	title_label.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(title_label)
	
	# Action button container
	action_container.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(action_container)
	
	# Initially hidden
	visible = false

## Set the item and populate available actions
func set_item(item, slot_name: String) -> void:
	_current_item = item
	_current_slot = slot_name
	
	# Clear previous buttons
	for button in action_container.get_children():
		button.queue_free()
	_action_buttons.clear()
	
	# Get item name for title
	var item_name = item.get("name", "Unknown") if item is Dictionary else "Item"
	title_label.text = item_name
	
	# Try to get context-aware actions from InventoryComponent
	var actions: Array = []
	var inv = _find_inventory_component()
	var item_id = item.get("id", "") if item is Dictionary else ""
	if inv and not item_id.is_empty() and inv.has_method("get_item_actions"):
		var raw_actions = inv.get_item_actions(item_id)
		for a in raw_actions:
			actions.append({"id": a.get("id", ""), "label": a.get("label", ""), "enabled": true})
	else:
		# Fallback generic actions
		actions = [
			{"id": "equip", "label": "Equip", "enabled": true},
			{"id": "drop", "label": "Drop", "enabled": true},
			{"id": "stow", "label": "Stow", "enabled": true},
			{"id": "inspect", "label": "Inspect", "enabled": true}
		]
	
	_create_action_buttons_from(actions)
	
	if fade_controller:
		fade_controller.fade_in()
	visible = true

func _find_inventory_component() -> Node:
	var root = get_tree().root.find_child("UIRoot", true, false)
	if root and root.get("player_character"):
		return root.player_character.get_node_or_null("InventoryComponent")
	return null

## Create context-aware action buttons
func _create_action_buttons_from(actions: Array) -> void:
	for action_data in actions:
		var button = Button.new()
		button.text = action_data.get("label", "?")
		button.custom_minimum_size = Vector2(70, 32)
		button.disabled = not action_data.get("enabled", true)
		button.pressed.connect(_on_action_button_pressed.bind(action_data.get("id", "")))
		
		# Style with profile
		if style_profile:
			var font = style_profile.get_font()
			if font: button.add_theme_font_override("font", font)
			button.add_theme_font_size_override("font_size", style_profile.small_font_size)
			button.add_theme_color_override("font_color", style_profile.primary_text_color)
			button.add_theme_color_override("font_hover_color", style_profile.get_accent_color())
		
		action_container.add_child(button)
		_action_buttons[action_data.get("id", "")] = button

## Clear the menu
func clear() -> void:
	_current_item = null
	_current_slot = ""
	for button in action_container.get_children():
		button.queue_free()
	_action_buttons.clear()
	title_label.text = ""
	visible = false

func _on_fade_completed(direction: String) -> void:
	if direction == "out":
		visible = false

## Handle action button press
func _on_action_button_pressed(action_id: String) -> void:
	item_action_selected.emit(action_id)
