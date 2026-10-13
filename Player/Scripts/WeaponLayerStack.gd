extends RefCounted
class_name WeaponLayerStack

# ============================================================
# WEAPON LAYER STACK
# Composes weapon positioning from ordered WeaponLayer instances.
# Layers are applied in priority order (lowest first).
# WeaponController owns this — delegates composition here instead
# of concentrating all positioning logic.
# ============================================================

var _layers: Array[WeaponLayer] = []
var _last_layer_snapshots: Array[Dictionary] = []
var _last_composition_results: Array[Dictionary] = []
var _debug_validate_spaces: bool = false

## Appends a layer and re-sorts by priority.
func add_layer(layer: WeaponLayer) -> void:
	_layers.append(layer)
	_sort_layers()

## Removes a layer by reference.
func remove_layer(layer: WeaponLayer) -> void:
	_layers.erase(layer)

## Composes all enabled layers in priority order.
## Returns the final WeaponRoot world-space transform.
func compose(state: AimState, delta: float) -> Transform3D:
	var current := Transform3D.IDENTITY
	_last_layer_snapshots.clear()
	_last_composition_results.clear()
	for layer in _layers:
		if layer.enabled:
			if _debug_validate_spaces:
				_last_layer_snapshots.append(_capture_snapshot("INPUT", current))
			current = layer.apply(current, state, delta)
			if _debug_validate_spaces:
				_last_layer_snapshots.append(_capture_snapshot("Layer_%d" % layer.priority, current))
			_last_composition_results.append({
				"label": "L%d_%s" % [layer.priority, layer.get_class()],
				"origin": current.origin,
				"fwd": -current.basis.z,
			})
	return current

func get_layer_count() -> int:
	return _layers.size()

func _sort_layers() -> void:
	_layers.sort_custom(func(a: WeaponLayer, b: WeaponLayer) -> bool: return a.priority < b.priority)

func set_debug_validate_spaces(enabled: bool) -> void:
	_debug_validate_spaces = enabled

func get_last_layer_snapshots() -> Array[Dictionary]:
	return _last_layer_snapshots

func get_last_composition_results() -> Array[Dictionary]:
	return _last_composition_results

func _capture_snapshot(label: String, t: Transform3D) -> Dictionary:
	return {
		"label": label,
		"origin": t.origin,
		"fwd": -t.basis.z,
		"right": t.basis.x,
		"up": t.basis.y,
		"basis_det": t.basis.determinant(),
	}
