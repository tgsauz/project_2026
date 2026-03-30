extends Resource
class_name UIStyleProfile

enum AccentPreset {
	TEAL,
	AMBER,
	RED,
	LIME
}

enum PresentationTier {
	LOW,
	HIGH
}

@export var accent_preset: AccentPreset = AccentPreset.TEAL
@export var presentation_tier: PresentationTier = PresentationTier.LOW
@export var custom_font: Font

@export var base_font_size: int = 15
@export var heading_font_size: int = 19
@export var small_font_size: int = 12
@export var border_width: int = 1
@export var panel_corner_radius: int = 1
@export var spacing_unit: int = 8
@export var line_thickness: int = 2

@export var margin_top: int = 24
@export var margin_bottom: int = 24
@export var margin_left: int = 24
@export var margin_right: int = 24

# ============================================================
# ANIMATION & FADE SETTINGS
# ============================================================

@export var fade_enabled: bool = true
@export var fade_in_duration: float = 0.15
@export var fade_out_duration: float = 0.25
@export var fade_easing_type: Tween.EaseType = Tween.EASE_OUT
@export var bounding_box_enabled: bool = true

# ============================================================
# OPTIMIZATION SETTINGS
# ============================================================

@export var unproject_update_rate: float = 0.5  # seconds between unproject cache refreshes
@export var position_update_batch_size: int = 4  # max UI position updates per frame
@export var max_simultaneous_tweens: int = 8

@export var primary_text_color: Color = Color(0.87, 0.88, 0.85, 1.0)
@export var secondary_text_color: Color = Color(0.58, 0.63, 0.66, 1.0)
@export var panel_fill_color: Color = Color(0.05, 0.06, 0.07, 0.88)
@export var elevated_panel_fill_color: Color = Color(0.08, 0.09, 0.10, 0.94)
@export var debug_panel_fill_color: Color = Color(0.03, 0.04, 0.05, 0.82)
@export var border_color: Color = Color(0.72, 0.74, 0.72, 0.22)
@export var decorative_line_color: Color = Color(0.85, 0.87, 0.86, 0.10)
@export var muted_fill_color: Color = Color(0.15, 0.17, 0.19, 0.86)
@export var warning_color: Color = Color(0.90, 0.37, 0.30, 1.0)
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.7)

var _resolved_font: Font

func get_accent_color() -> Color:
	match accent_preset:
		AccentPreset.AMBER:
			return Color(0.91, 0.69, 0.33, 1.0)
		AccentPreset.RED:
			return Color(0.87, 0.33, 0.32, 1.0)
		AccentPreset.LIME:
			return Color(0.65, 0.82, 0.47, 1.0)
		_:
			return Color(0.34, 0.79, 0.78, 1.0)

func uses_high_tier() -> bool:
	return presentation_tier == PresentationTier.HIGH

func get_font() -> Font:
	if custom_font != null:
		return custom_font
	if _resolved_font != null:
		return _resolved_font

	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray([
		"Departure Mono",
		"Cascadia Mono",
		"Consolas",
		"Lucida Console",
		"Courier New",
		"Monospace"
	])
	system_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	system_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_resolved_font = system_font
	return _resolved_font

func make_label_settings(role: String = "body") -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = get_font()
	settings.outline_size = 1
	settings.outline_color = shadow_color

	match role:
		"title":
			settings.font_size = heading_font_size
			settings.font_color = primary_text_color
		"selected":
			settings.font_size = base_font_size
			settings.font_color = get_accent_color()
		"debug":
			settings.font_size = base_font_size
			settings.font_color = primary_text_color
		"meta":
			settings.font_size = small_font_size
			settings.font_color = secondary_text_color
			settings.outline_size = 0
		"accent":
			settings.font_size = small_font_size
			settings.font_color = get_accent_color()
			settings.outline_size = 0
		_:
			settings.font_size = base_font_size
			settings.font_color = secondary_text_color

	return settings

func make_panel_style(variant: String = "default") -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = true
	style.corner_radius_top_left = panel_corner_radius
	style.corner_radius_top_right = panel_corner_radius
	style.corner_radius_bottom_left = panel_corner_radius
	style.corner_radius_bottom_right = panel_corner_radius
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	style.content_margin_left = spacing_unit
	style.content_margin_top = spacing_unit
	style.content_margin_right = spacing_unit
	style.content_margin_bottom = spacing_unit

	match variant:
		"elevated":
			style.bg_color = elevated_panel_fill_color
		"debug":
			style.bg_color = debug_panel_fill_color
		_:
			style.bg_color = panel_fill_color

	return style

func make_progress_background_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = muted_fill_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = panel_corner_radius
	style.corner_radius_top_right = panel_corner_radius
	style.corner_radius_bottom_left = panel_corner_radius
	style.corner_radius_bottom_right = panel_corner_radius
	return style

func make_progress_fill_style(fill_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.corner_radius_top_left = panel_corner_radius
	style.corner_radius_top_right = panel_corner_radius
	style.corner_radius_bottom_left = panel_corner_radius
	style.corner_radius_bottom_right = panel_corner_radius
	return style

func make_rule_color(alpha_multiplier: float = 1.0) -> Color:
	var line_color := decorative_line_color
	line_color.a *= alpha_multiplier
	return line_color

# ============================================================
# OPTIMIZATION & FEATURE GATING
# ============================================================

func is_fade_supported() -> bool:
	if not fade_enabled:
		return false
	if presentation_tier == PresentationTier.LOW:
		return fade_in_duration > 0.0 or fade_out_duration > 0.0
	return true

func get_fade_duration(direction: String = "in") -> float:
	if not is_fade_supported():
		return 0.0
	return fade_in_duration if direction == "in" else fade_out_duration

func is_bounding_box_supported() -> bool:
	if not bounding_box_enabled:
		return false
	return presentation_tier == PresentationTier.HIGH

func get_optimization_tier() -> String:
	match presentation_tier:
		PresentationTier.LOW:
			return "low"
		_:
			return "high"

func get_margins() -> Vector4:
	# Returns margins as Vector4(top, right, bottom, left) for convenience
	return Vector4(margin_top, margin_right, margin_bottom, margin_left)

func apply_margins(container: MarginContainer) -> void:
	# Applies per-side margins to a MarginContainer
	if container == null:
		return
	var m = get_margins()
	container.add_theme_constant_override("margin_top", int(m.x))
	container.add_theme_constant_override("margin_right", int(m.y))
	container.add_theme_constant_override("margin_bottom", int(m.z))
	container.add_theme_constant_override("margin_left", int(m.w))
