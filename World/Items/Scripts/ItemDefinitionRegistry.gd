## ItemDefinitionRegistry
## Preloaded O(1) lookup for item definitions by string ID.
## Scans once at startup, caches permanently. Safe for low-end hardware.
## Use force_reload() from tool contexts (e.g. CharacterTuner) to pick up
## on-disk changes without restarting the project.
extends Node
class_name ItemDefinitionRegistry

const SCAN_DIRECTORY := "res://World/Items/"

static var _cache: Dictionary = {}
static var _initialized: bool = false

## Must be called once before any lookups (typically from _ready of a root node).
## No-ops if already initialized; call force_reload() to re-scan from disk.
static func initialize() -> void:
	if _initialized:
		return
	_cache.clear()
	_scan_directory(SCAN_DIRECTORY, false)
	_initialized = true
	print("[ItemDefinitionRegistry] Loaded %d item definitions." % _cache.size())

## Forces a full re-scan of the Items directory, bypassing the Godot resource cache.
## Use this in tool/editor contexts where .tres files may have changed on disk since
## the last scan (e.g. after ResourceSaver.save() in CharacterTuner).
static func force_reload() -> void:
	_initialized = false
	_cache.clear()
	_scan_directory(SCAN_DIRECTORY, true)
	_initialized = true
	print("[ItemDefinitionRegistry] Force-reloaded %d item definitions from disk." % _cache.size())

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
	var definitions: Array[ItemDefinition] = []
	for cached_definition in _cache.values():
		if cached_definition is ItemDefinition:
			definitions.append(cached_definition as ItemDefinition)
	return definitions

static func is_initialized() -> bool:
	return _initialized

## Recursively scans a directory for .tres resources that extend ItemDefinition.
## ignore_cache: if true uses CACHE_MODE_IGNORE to bypass the engine's resource
## cache, ensuring fresh data from disk (used for force_reload).
static func _scan_directory(path: String, ignore_cache: bool) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return

	var cache_mode := ResourceLoader.CACHE_MODE_IGNORE if ignore_cache else ResourceLoader.CACHE_MODE_REUSE

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path.path_join(file_name)
		if dir.current_is_dir():
			if file_name != "." and file_name != ".." and file_name != "Scripts":
				_scan_directory(full_path, ignore_cache)
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var resource = ResourceLoader.load(full_path, "", cache_mode)
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
