extends RefCounted
class_name WeaponLayer

# ============================================================
# WEAPON LAYER
# Base class for composable weapon positioning layers.
# Subclasses override apply() to add a transform contribution.
# Current layers are composed in priority order:
#   base (0) → aim (5).
# Additional presentation layers can be added when their behavior is implemented.
# ============================================================

var priority: int = 0
var enabled: bool = true

func apply(current: Transform3D, _state: AimState, _delta: float) -> Transform3D:
	return current
