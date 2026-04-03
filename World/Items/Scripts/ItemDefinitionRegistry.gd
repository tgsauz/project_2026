## ItemDefinitionRegistry
## Preloaded O(1) lookup for item definitions by string ID.
## Scans once at startup, caches permanently. Safe for low-end hardware.
extends Node
class_name ItemDefinitionRegistry

const SCAN_DIRECTORY := "res://World/Items/"

static var _cache: Dictionary = {}
static var _initialized: bool = false

## Must be called once before any lookups (typically from _ready of a root node)
static func initialize() -> void:
	if _initialized:
		return
	_cache.clear()
	_scan_directory(SCAN_DIRECTORY)
	_initialized = true
	print("[ItemDefinitionRegistry] Loaded %d item definitions." % _cache.size())

## O(1) lookup by ItemDefinition.id
static func find_by_id(id: String) -> ItemDefinition:
	if not _initialized:
		initialize()
	return _cache.get(id)

## Returns all registered definitions (for debug tools)
static func get_all() -> Dictionary:
	if not _initialized:
		initialize()
	return _cache

static func get_all_definitions() -> Array[ItemDefinition]:
	if not _initialized:
		initialize()
	return _cache.values()

static func is_initialized() -> bool:
	return _initialized

## Recursively scans a directory for .tres resources that extend ItemDefinition
static func _scan_directory(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path.path_join(file_name)
		if dir.current_is_dir():
			if file_name != "." and file_name != ".." and file_name != "Scripts":
				_scan_directory(full_path)
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var resource = ResourceLoader.load(full_path, "", ResourceLoader.CACHE_MODE_REUSE)
			if resource is ItemDefinition:
				var item_def := resource as ItemDefinition
				_validate_slots(item_def, full_path)
				if not item_def.id.is_empty():
					_cache[item_def.id] = item_def
		file_name = dir.get_next()
	dir.list_dir_end()

static func _validate_slots(item_def: ItemDefinition, full_path: String) -> void:
	if item_def == null:
		return

	var known_points := _build_known_point_ids_for_validation(item_def)

	for slot_name in item_def.allowed_slots:
		if not known_points.has(slot_name):
			push_warning("ItemDefinitionRegistry: %s references unknown allowed slot '%s'." % [full_path, slot_name])

	if not item_def.preferred_slot.is_empty() and not known_points.has(item_def.preferred_slot):
		push_warning("ItemDefinitionRegistry: %s uses unknown preferred_slot '%s'." % [full_path, item_def.preferred_slot])

	if not item_def.secondary_hand_slot.is_empty() and not known_points.has(item_def.secondary_hand_slot):
		push_warning("ItemDefinitionRegistry: %s uses unknown secondary_hand_slot '%s'." % [full_path, item_def.secondary_hand_slot])

static func _build_known_point_ids_for_validation(item_def: ItemDefinition) -> PackedStringArray:
	var known_points := AttachmentLayoutLibrary.get_base_known_point_ids()
	known_points = AttachmentLayoutLibrary.append_modifier_point_ids(known_points, item_def.attachment_modifier)

	for cached_definition in _cache.values():
		if cached_definition == null:
			continue
		known_points = AttachmentLayoutLibrary.append_modifier_point_ids(known_points, cached_definition.attachment_modifier)

	return known_points
