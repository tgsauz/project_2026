extends Resource
class_name EquipmentSlotCatalog

@export var slots: Array[EquipmentSlotDefinition] = []

func get_slot(slot_name: String) -> EquipmentSlotDefinition:
	for slot in slots:
		if slot != null and slot.slot_name == slot_name:
			return slot
	return null

func has_slot(slot_name: String) -> bool:
	return get_slot(slot_name) != null

func get_slot_names() -> PackedStringArray:
	var names := PackedStringArray()
	for slot in slots:
		if slot == null or slot.slot_name.is_empty():
			continue
		names.append(slot.slot_name)
	return names

func get_tuner_slot_names() -> PackedStringArray:
	var names := PackedStringArray()
	for slot in slots:
		if slot == null or slot.slot_name.is_empty() or not slot.tuner_enabled:
			continue
		names.append(slot.slot_name)
	return names

func build_slot_configs_for(slot_names: PackedStringArray) -> Dictionary:
	var configs: Dictionary = {}
	for slot_name in slot_names:
		var slot := get_slot(slot_name)
		if slot != null:
			configs[slot_name] = slot.to_inventory_config()
	return configs

func validate() -> Array[String]:
	var warnings: Array[String] = []
	var seen := {}
	for slot in slots:
		if slot == null:
			warnings.append("Slot catalog contains a null entry.")
			continue
		if slot.slot_name.is_empty():
			warnings.append("Slot catalog contains an entry with an empty slot_name.")
			continue
		if seen.has(slot.slot_name):
			warnings.append("Slot catalog contains duplicate slot '%s'." % slot.slot_name)
			continue
		seen[slot.slot_name] = true
	return warnings
