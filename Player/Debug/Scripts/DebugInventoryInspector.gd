## DebugInventoryInspector
## Developer-only overlay showing raw inventory state with quick actions.
## Lives under DebugLayer, toggled with the existing toggle_debug hotkey.
extends PanelContainer
class_name DebugInventoryInspector

var _vbox: VBoxContainer
var _header: Label
var _slot_table: RichTextLabel
var _actions_row: HBoxContainer
var _last_serialized: Dictionary = {}

var style_profile: UIStyleProfile

func _ready() -> void:
	custom_minimum_size = Vector2(400, 500)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -420
	offset_right = -10
	offset_top = 10
	offset_bottom = 520
	
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 6)
	add_child(_vbox)
	
	_header = Label.new()
	_header.text = "INVENTORY INSPECTOR"
	_vbox.add_child(_header)
	
	# Slot table (scrollable rich text)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_vbox.add_child(scroll)
	
	_slot_table = RichTextLabel.new()
	_slot_table.bbcode_enabled = true
	_slot_table.fit_content = true
	_slot_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_table.custom_minimum_size = Vector2(370, 0)
	_slot_table.scroll_active = false
	scroll.add_child(_slot_table)
	
	# Quick action buttons
	_actions_row = HBoxContainer.new()
	_actions_row.add_theme_constant_override("separation", 8)
	_vbox.add_child(_actions_row)
	
	_add_action_button("Clear All", _on_clear)
	_add_action_button("Add Test", _on_add_test)
	_add_action_button("Serialize", _on_serialize)
	_add_action_button("Deserialize", _on_deserialize)

func apply_style(style: UIStyleProfile) -> void:
	style_profile = style
	add_theme_stylebox_override("panel", style.make_panel_style("debug"))
	_header.label_settings = style.make_label_settings("accent")
	
	for btn in _actions_row.get_children():
		if btn is Button:
			var font = style.get_font()
			if font: btn.add_theme_font_override("font", font)
			btn.add_theme_font_size_override("font_size", style.small_font_size)

func _process(_delta: float) -> void:
	if not visible:
		return
	_refresh_display()

func _refresh_display() -> void:
	var inv = _find_inventory()
	if inv == null:
		_slot_table.text = "[No InventoryComponent found]"
		return
	
	var bbcode := ""
	
	# Slot states
	bbcode += "[b]SLOTS[/b]\n"
	for slot_name in inv.slot_names:
		var state = inv.get_slot_state(slot_name)
		var item = state.get("item")
		if item != null:
			var def_id = item.definition.id if item.definition else "?"
			bbcode += "  [color=#5cc]%s[/color]: %s [color=#888](id:%s w:%.1f)[/color]\n" % [
				slot_name, item.get_display_name(), def_id, item.get_total_weight()
			]
			if item.is_container() and item.contained_item_ids.size() > 0:
				for cid in item.contained_item_ids:
					var nested = inv.get_item_instance(str(cid))
					if nested:
						bbcode += "    └ %s [color=#888](id:%s)[/color]\n" % [nested.get_display_name(), nested.instance_id]
		else:
			bbcode += "  [color=#666]%s[/color]: (empty)\n" % slot_name
	
	# Weight
	bbcode += "\n[b]WEIGHT[/b]: %.1f / %.1f (load: %.0f%%)\n" % [inv.total_weight, inv.base_capacity, inv.load_factor * 100]
	
	# Registry
	bbcode += "\n[b]REGISTRY[/b]: %d instances\n" % inv.item_instances.size()
	for item_id in inv.item_instances.keys():
		var item = inv.item_instances[item_id]
		if item:
			bbcode += "  [color=#888]%s[/color] → %s (slot:%s)\n" % [item.instance_id, item.get_display_name(), item.owning_slot]
	
	# Definition registry
	var all_defs = ItemDefinitionRegistry.get_all()
	bbcode += "\n[b]DEF REGISTRY[/b]: %d definitions loaded\n" % all_defs.size()
	
	_slot_table.text = bbcode

func _find_inventory() -> InventoryComponent:
	var root = get_tree().root.find_child("UIRoot", true, false)
	if root and root.get("player_character"):
		return root.player_character.get_node_or_null("InventoryComponent") as InventoryComponent
	return null

func _add_action_button(label: String, callback: Callable) -> void:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(80, 28)
	btn.pressed.connect(callback)
	_actions_row.add_child(btn)

func _on_clear() -> void:
	var inv = _find_inventory()
	if inv: inv.clear()
	print("[DebugInv] Inventory cleared.")

func _on_add_test() -> void:
	var inv = _find_inventory()
	if inv == null:
		return
	# Pick a random definition from the registry
	var all_defs = ItemDefinitionRegistry.get_all()
	if all_defs.is_empty():
		print("[DebugInv] No definitions in registry.")
		return
	var keys = all_defs.keys()
	var random_def = all_defs[keys[randi() % keys.size()]]
	var instance = ItemInstance.create_from_definition(random_def, 1)
	var success = inv.pickup_item_instance(instance)
	print("[DebugInv] Added '%s' → %s" % [random_def.display_name, "success" if success else "failed"])

func _on_serialize() -> void:
	var inv = _find_inventory()
	if inv == null:
		return
	_last_serialized = inv.serialize()
	var json = JSON.stringify(_last_serialized, "\t")
	print("[DebugInv] Serialized inventory:\n%s" % json)

func _on_deserialize() -> void:
	var inv = _find_inventory()
	if inv == null:
		return
	if _last_serialized.is_empty():
		print("[DebugInv] No serialized data. Press Serialize first.")
		return
	inv.deserialize(_last_serialized)
	print("[DebugInv] Deserialized inventory from snapshot.")
