## InventorySlotPanelUI
## Displays items in a selected inventory slot as a selectable list
extends PanelContainer

class_name InventorySlotPanelUI

## Emitted when an item is selected from the list
signal item_selected(item)
## Emitted when hovering an item in the list
signal item_hovered(item_dict: Dictionary, screen_pos: Vector2)
signal item_unhovered()

@onready var title_label = Label.new()
@onready var item_list = ItemList.new()

var _current_slot: String = ""
var _current_items: Array = []
var _inventory_component: Node

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
	title_label.text = "(Empty)"
	title_label.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(title_label)
	
	# Item list
	item_list.item_clicked.connect(_on_item_clicked)
	item_list.custom_minimum_size = Vector2(200, 0)
	item_list.auto_height = true
	item_list.max_columns = 1
	item_list.mouse_exited.connect(func(): item_unhovered.emit())
	vbox.add_child(item_list)
	
	# Initially hidden
	visible = false

## Set items to display from a given slot
func set_slot_items(slot_name: String, items: Array) -> void:
	_current_slot = slot_name
	_current_items = items
	
	# Update title with clean display name
	title_label.text = slot_name.replace("_", " ").capitalize()
	
	# Populate item list
	item_list.clear()
	
	if items.is_empty():
		item_list.add_item("(empty)")
		if style_profile:
			item_list.set_item_custom_fg_color(0, style_profile.secondary_text_color)
	else:
		for i in range(items.size()):
			var item = items[i]
			var item_name = item.get("name", "Unknown") if item is Dictionary else "Item"
			var quantity = item.get("quantity", 1) if item is Dictionary else 1
			
			var display_text = "%s (x%d)" % [item_name, quantity] if quantity > 1 else item_name
			item_list.add_item(display_text)
			
			if style_profile:
				item_list.set_item_custom_fg_color(i, style_profile.primary_text_color)
	
	# Apply font to item_list
	if style_profile:
		var font = style_profile.get_font()
		if font: item_list.add_theme_font_override("font", font)
		item_list.add_theme_font_size_override("font_size", style_profile.base_font_size)
	
	if fade_controller:
		fade_controller.fade_in()
	visible = true

## Clear the panel
func clear() -> void:
	_current_slot = ""
	_current_items.clear()
	item_list.clear()
	title_label.text = "(Empty)"
	visible = false

func _on_fade_completed(direction: String) -> void:
	if direction == "out":
		visible = false

## Set reference to inventory component (for refresh after actions)
func set_inventory_component(inv: Node) -> void:
	_inventory_component = inv

## Handle item selection
func _on_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	if index >= 0 and index < _current_items.size():
		var selected_item = _current_items[index]
		item_selected.emit(selected_item)

func _process(_delta: float) -> void:
	if not visible or _current_items.is_empty():
		return
	# Detect hovered item index under mouse
	var mouse_pos = item_list.get_local_mouse_position()
	var idx = item_list.get_item_at_position(mouse_pos, true)
	if idx >= 0 and idx < _current_items.size():
		item_hovered.emit(_current_items[idx], get_global_mouse_position())

## Refresh the panel (call after inventory updates)
func refresh() -> void:
	if _current_slot != "":
		# Re-query items from inventory component if available
		if _inventory_component and _inventory_component.has_method("get_slot_state"):
			var slot_state = _inventory_component.get_slot_state(_current_slot)
			if slot_state:
				var items = slot_state.get("items", [])
				set_slot_items(_current_slot, items)
