extends Node
class_name ResponsiveLayoutManager

# ============================================================
# DESCRIPTION
# ============================================================
# Manages responsive UI layout based on viewport dimensions.
# - Detects breakpoints (mobile, tablet, desktop, ultrawide)
# - Scales per-side margins according to breakpoint
# - Recalculates UI component positions on viewport resize
# - Supports smooth position/scale transitions (HIGH tier only)
# ============================================================

enum Breakpoint {
	MOBILE,      # < 720p width
	TABLET,      # 720p - 1280p width
	DESKTOP,     # 1280p - 2560p width
	ULTRAWIDE    # > 2560p width
}

signal breakpoint_changed(old_breakpoint: Breakpoint, new_breakpoint: Breakpoint)

# ============================================================
# CONFIG
# ============================================================

var style_profile: UIStyleProfile
var transition_duration: float = 0.3  # for smooth layout changes on HIGH tier

# Breakpoint thresholds (width in pixels)
var breakpoint_thresholds: Dictionary = {
	Breakpoint.MOBILE: 720,
	Breakpoint.TABLET: 1280,
	Breakpoint.DESKTOP: 2560,
	Breakpoint.ULTRAWIDE: 99999  # essentially unlimited
}

# Margin scaling factors per breakpoint (multiplier applied to base margin)
var margin_scale_factors: Dictionary = {
	Breakpoint.MOBILE: 0.75,      # 75% of base margins
	Breakpoint.TABLET: 0.85,      # 85% of base margins
	Breakpoint.DESKTOP: 1.0,      # 100% of base margins
	Breakpoint.ULTRAWIDE: 1.15    # 115% of base margins
}

# ============================================================
# STATE
# ============================================================

var current_breakpoint: Breakpoint = Breakpoint.DESKTOP
var current_viewport_size: Vector2 = Vector2.ZERO
var registered_components: Array[Control] = []
var safe_area_rect: Rect2 = Rect2()

# ============================================================
# LIFECYCLE
# ============================================================

func _init(style: UIStyleProfile) -> void:
	style_profile = style
	# Viewport initialization deferred to _ready() since node not in tree yet

func _ready() -> void:
	# Initialize viewport and safe area now that node is in tree
	current_viewport_size = get_viewport().get_visible_rect().size
	safe_area_rect = DisplayServer.screen_get_usable_rect()
	_update_breakpoint()
	# Connect to viewport changes
	if get_viewport() != null:
		get_viewport().size_changed.connect(_on_viewport_changed)

func _exit_tree() -> void:
	if get_viewport() != null:
		get_viewport().size_changed.disconnect(_on_viewport_changed)

# ============================================================
# PUBLIC API
# ============================================================

## Register a UI component to be managed by this layout system.
func register_component(component: Control) -> void:
	if component != null and component not in registered_components:
		registered_components.append(component)

## Unregister a UI component.
func unregister_component(component: Control) -> void:
	if component in registered_components:
		registered_components.erase(component)

## Get the effective margin for the current breakpoint (scaled from base).
func get_effective_margin_vector() -> Vector4:
	var base_margin = Vector4(
		style_profile.margin_top,
		style_profile.margin_right,
		style_profile.margin_bottom,
		style_profile.margin_left
	)
	var scale_factor = margin_scale_factors.get(current_breakpoint, 1.0)
	return base_margin * scale_factor

## Get the current breakpoint.
func get_current_breakpoint() -> Breakpoint:
	return current_breakpoint

## Get viewport-relative position for a UI component anchored to a corner/edge.
## anchor: "top_left", "top_center", "top_right", "center_left", "center", "center_right", "bottom_left", "bottom_center", "bottom_right"
func get_anchored_position(anchor: String) -> Vector2:
	var viewport_size = get_viewport().get_visible_rect().size
	var margin = get_effective_margin_vector()
	var pos = Vector2.ZERO
	
	match anchor:
		"top_left":
			pos = Vector2(margin.w, margin.x)  # left, top
		"top_center":
			pos = Vector2(viewport_size.x / 2.0, margin.x)
		"top_right":
			pos = Vector2(viewport_size.x - margin.y, margin.x)  # right, top
		"center_left":
			pos = Vector2(margin.w, viewport_size.y / 2.0)
		"center":
			pos = Vector2(viewport_size.x / 2.0, viewport_size.y / 2.0)
		"center_right":
			pos = Vector2(viewport_size.x - margin.y, viewport_size.y / 2.0)
		"bottom_left":
			pos = Vector2(margin.w, viewport_size.y - margin.z)
		"bottom_center":
			pos = Vector2(viewport_size.x / 2.0, viewport_size.y - margin.z)
		"bottom_right":
			pos = Vector2(viewport_size.x - margin.y, viewport_size.y - margin.z)
	
	return pos

## Check if a screen point is in the safe area (respects notches, etc.)
func is_in_safe_area(screen_pos: Vector2) -> bool:
	return safe_area_rect.has_point(screen_pos)

# ============================================================
# PRIVATE IMPLEMENTATION
# ============================================================

func _on_viewport_changed() -> void:
	var new_size = get_viewport().get_visible_rect().size
	if new_size != current_viewport_size:
		current_viewport_size = new_size
		var old_breakpoint = current_breakpoint
		_update_breakpoint()
		
		if old_breakpoint != current_breakpoint:
			breakpoint_changed.emit(old_breakpoint, current_breakpoint)
			_recalculate_layout()

func _update_breakpoint() -> void:
	var viewport_width = current_viewport_size.x
	
	if viewport_width < breakpoint_thresholds[Breakpoint.MOBILE]:
		current_breakpoint = Breakpoint.MOBILE
	elif viewport_width < breakpoint_thresholds[Breakpoint.TABLET]:
		current_breakpoint = Breakpoint.TABLET
	elif viewport_width < breakpoint_thresholds[Breakpoint.DESKTOP]:
		current_breakpoint = Breakpoint.DESKTOP
	else:
		current_breakpoint = Breakpoint.ULTRAWIDE

func _recalculate_layout() -> void:
	# Recalculate positions for all registered components
	# This will trigger component-specific layout logic if implemented
	for component in registered_components:
		if component != null and not component.is_queued_for_deletion():
			if component.has_method("on_breakpoint_changed"):
				component.on_breakpoint_changed(current_breakpoint)
			elif component.has_method("_on_layout_invalidated"):
				component._on_layout_invalidated()

func _animate_layout_change() -> void:
	# On HIGH tier, smoothly animate margin/position changes
	if not style_profile.uses_high_tier():
		return
	
	for component in registered_components:
		if component != null and not component.is_queued_for_deletion():
			if component.has_method("animate_layout_change"):
				component.animate_layout_change(transition_duration)
