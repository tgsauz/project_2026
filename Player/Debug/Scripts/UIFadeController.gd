extends RefCounted
class_name UIFadeController

# ============================================================
# DESCRIPTION
# ============================================================
# Manages fade in/out animations for UI elements.
# - Observes value changes every frame
# - Fades IN immediately when value changes significantly
# - Debounces to detect stability, fades OUT after ~6 frames of no change (~100ms @ 60fps)
# - Automatically cleans up tweens when node exits tree
# - Respects UIStyleProfile fade settings and presentation tier
# ============================================================

signal fade_started(direction: String)
signal fade_completed(direction: String)

# ============================================================
# CONFIG
# ============================================================

var target: CanvasItem
var style_profile: UIStyleProfile
var stability_threshold: float = 0.01
var debounce_frames: int = 6  # ~100ms at 60fps

# ============================================================
# STATE
# ============================================================

var is_fading: bool = false
var _current_value: Variant = null
var _last_significant_value: Variant = null
var _stability_frame_count: int = 0  # frames since last significant change
var _current_tween: Tween = null
var _fade_out_scheduled: bool = false
var _tree_exiting_connected: bool = false

# ============================================================
# LIFECYCLE
# ============================================================

func _init(target_node: CanvasItem, style: UIStyleProfile, threshold: float = 0.01) -> void:
	target = target_node
	style_profile = style
	stability_threshold = threshold
	
	# Connect to tree_exiting when initialized
	if target != null and not _tree_exiting_connected:
		target.tree_exiting.connect(_on_target_tree_exiting)
		_tree_exiting_connected = true

func _process(_delta: float) -> void:
	# Track stability: increment counter if value hasn't changed significantly
	if _stability_frame_count > 0:
		_stability_frame_count += 1
		
		# When stability threshold reached and not already fading, trigger fade out
		if _stability_frame_count >= debounce_frames and not is_fading and not _fade_out_scheduled:
			_fade_out_scheduled = true
			fade_out()
			_stability_frame_count = 0

# ============================================================
# PUBLIC API
# ============================================================

## Observe a value change. Triggers fade_in if changed significantly, or fade_out if stable.
func observe_value(current_value: Variant) -> void:
	_current_value = current_value
	
	# First observation: initialize
	if _last_significant_value == null:
		_last_significant_value = _current_value
		_stability_frame_count = 0
		_fade_out_scheduled = false
		return
	
	# Check if value changed significantly
	if _has_value_changed(_last_significant_value, _current_value):
		# Value changed: trigger fade in and reset stability counter
		_last_significant_value = _current_value
		_stability_frame_count = 0
		_fade_out_scheduled = false
		fade_in()
	else:
		# Value unchanged: increment stability counter (fade_out will trigger in _process)
		if _stability_frame_count == 0:
			_stability_frame_count = 1  # Start counting on first frame of stability

## Manually trigger fade in animation.
func fade_in() -> void:
	if not style_profile.is_fade_supported() or is_fading:
		return
	_fade_to(1.0, "in")

## Manually trigger fade out animation.
func fade_out() -> void:
	if not style_profile.is_fade_supported() or is_fading:
		return
	_fade_to(0.0, "out")

## Force immediate visibility without animation.
func set_visible_immediate(is_visible: bool) -> void:
	if target == null:
		return
	var kill_existing = _current_tween != null
	if kill_existing:
		_current_tween.kill()
		_current_tween = null
	
	target.modulate.a = 1.0 if is_visible else 0.0
	is_fading = false
	_fade_out_scheduled = false

# ============================================================
# PRIVATE IMPLEMENTATION
# ============================================================

func _has_value_changed(old_val: Variant, new_val: Variant) -> bool:
	if old_val == null or new_val == null:
		return old_val != new_val
	
	# Float comparison with threshold
	if old_val is float and new_val is float:
		return abs(old_val - new_val) > stability_threshold
	
	# Direct equality for other types
	return old_val != new_val

func _fade_to(target_alpha: float, direction: String) -> void:
	if target == null or not style_profile.is_fade_supported():
		return
	
	# Kill existing tween to prevent conflicts
	if _current_tween != null:
		_current_tween.kill()
		_current_tween = null
	
	var duration = style_profile.get_fade_duration(direction)
	
	# If duration is 0, apply immediately without animation
	if duration <= 0.0:
		target.modulate.a = target_alpha
		is_fading = false
		_fade_out_scheduled = false
		fade_completed.emit(direction)
		return
	
	is_fading = true
	_fade_out_scheduled = false
	fade_started.emit(direction)
	
	_current_tween = target.create_tween()
	_current_tween.bind_node(target)
	_current_tween.set_trans(Tween.TRANS_QUAD)
	_current_tween.set_ease(style_profile.fade_easing_type)
	_current_tween.tween_property(target, "modulate:a", target_alpha, duration)
	
	# Connect to finished signal instead of using await
	_current_tween.finished.connect(func(): 
		is_fading = false
		fade_completed.emit(direction)
	)

func _on_target_tree_exiting() -> void:
	# Ensure tween is killed when target node exits tree
	if _current_tween != null:
		_current_tween.kill()
		_current_tween = null
	is_fading = false
	_fade_out_scheduled = false