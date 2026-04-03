extends RefCounted
class_name EquipmentSlotLibrary

const DEFAULT_CATALOG_PATH := "res://World/Items/Config/DefaultEquipmentSlotCatalog.tres"

static var _catalog: EquipmentSlotCatalog

static func get_catalog() -> EquipmentSlotCatalog:
	if _catalog == null:
		_catalog = load(DEFAULT_CATALOG_PATH) as EquipmentSlotCatalog
		if _catalog == null:
			push_error("EquipmentSlotLibrary: Failed to load slot catalog at %s" % DEFAULT_CATALOG_PATH)
			return null
		for warning in _catalog.validate():
			push_warning("EquipmentSlotLibrary: %s" % warning)
	return _catalog

static func get_slot(slot_name: String) -> EquipmentSlotDefinition:
	var catalog := get_catalog()
	return catalog.get_slot(slot_name) if catalog != null else null

static func has_slot(slot_name: String) -> bool:
	return get_slot(slot_name) != null

static func get_slot_names() -> PackedStringArray:
	var catalog := get_catalog()
	return catalog.get_slot_names() if catalog != null else PackedStringArray()

static func get_tuner_slot_names() -> PackedStringArray:
	var catalog := get_catalog()
	return catalog.get_tuner_slot_names() if catalog != null else PackedStringArray()

static func build_slot_configs_for(slot_names: PackedStringArray) -> Dictionary:
	var catalog := get_catalog()
	return catalog.build_slot_configs_for(slot_names) if catalog != null else {}
