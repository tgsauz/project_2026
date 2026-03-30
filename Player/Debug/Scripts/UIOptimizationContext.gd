extends Object
class_name UIOptimizationContext

# ============================================================
# DESCRIPTION
# ============================================================
# Tracks UI animation and rendering budgets to prevent performance
# regressions on low-end hardware.
# - Enforces max simultaneous tween limit
# - Culls oldest tweens when budget exceeded
# - Provides optional debug logging
# ============================================================

var style_profile: UIStyleProfile
var debug_enabled: bool = false
var _active_tweens: Array[Tween] = []

# ============================================================
# LIFECYCLE
# ============================================================

func _init(style: UIStyleProfile, debug: bool = false) -> void:
	style_profile = style
	debug_enabled = debug

# ============================================================
# PUBLIC API
# ============================================================

## Register a tween for budget tracking and culling if necessary.
func register_tween(tween: Tween) -> void:
	if tween == null:
		return
	
	_active_tweens.append(tween)
	_enforce_tween_budget()
	
	# Auto-cleanup when tween finishes
	tween.finished.connect(func() -> void:
		_active_tweens.erase(tween)
	)

## Get count of currently active tweens.
func get_active_tween_count() -> int:
	return _active_tweens.size()

## Get max allowed tweens based on style profile.
func get_max_tweens() -> int:
	return style_profile.max_simultaneous_tweens if style_profile else 8

## Manually clear all active tweens (emergency cleanup).
func clear_all_tweens() -> void:
	for tween in _active_tweens:
		if tween != null:
			tween.kill()
	_active_tweens.clear()

# ============================================================
# PRIVATE IMPLEMENTATION
# ============================================================

func _enforce_tween_budget() -> void:
	if style_profile == null:
		return
	
	var max_tweens = style_profile.max_simultaneous_tweens
	
	# If over budget, cull oldest tweens (FIFO)
	while _active_tweens.size() > max_tweens:
		var oldest = _active_tweens.pop_front()
		if oldest != null:
			oldest.kill()
		
		if debug_enabled:
			print_debug("UIOptimization: Culled tween (active: %d / max: %d)" % [_active_tweens.size(), max_tweens])
