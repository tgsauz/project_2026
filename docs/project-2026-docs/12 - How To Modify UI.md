# 12 - How To Modify UI

This guide covers how to modify existing user interfaces or add entirely new UI components to the project, adhering to the project's styling and architecture guidelines.

## 1. UI Architecture Overview

The UI layer is managed centrally by `UIRoot.gd`. The UI visual design is controlled dynamically by a `UIStyleProfile` Resource, rather than hardcoding colors and raw StyleBoxes inside the editor. 

When `UIRoot` initializes, it generates a "runtime style" by duplicating the assigned `UIStyleProfile`. It then passes this style profile down to all registered UI components inside the `_apply_ui_style()` function.

*   **UIRoot.gd Engine Layer:** Handles input, visibility toggling, and passes the style definition to children.
*   **UIStyleProfile.gd Resource:** Exposes all global properties for styling. It manages base fonts, accent colors, preset styles, presentation tiers, and includes helper methods to generate Godot `StyleBoxFlat` and `LabelSettings`.

> [!WARNING]
> Do not assign hardcoded RGB values, custom fonts, or Theme overrides directly to individual UI nodes within the editor. The dynamic styling system will ignore or overwrite these changes. All styles must be drawn directly from `UIStyleProfile`.

## 2. Customizing Existing Appearance

To change the overall look of the UI without altering code geometry, you can edit the `UIStyleProfile` resource used by the `UIRoot` node.

1. Open the main active scene where `UIRoot` exists (such as a Player character scene or an Autoload depending on project iteration).
2. Select the `UIRoot` node.
3. In the Inspector, locate the **Config** section.
4. Modify properties like `accent_preset` or `presentation_tier`, or open the underlying `UIStyleProfile` resource to modify base font size, panel background colors, border thicknesses, etc.

## 3. Creating a New UI Component

When you add a new piece of UI to the project, follow these steps to integrate correctly:

1. Create a scene with a `Control` (or sub-class like `PanelContainer`, `MarginContainer`) as the root.
2. Attach a script to the root node.
3. Define a local variable to cache the styling, e.g., `var style_profile: UIStyleProfile`.
4. Implement the `apply_style(style: UIStyleProfile) -> void` method.
5. In `apply_style()`, use `UIStyleProfile`'s helper functions (like `make_panel_style()`, `make_label_settings()`, `get_accent_color()`) to assign StyleBox Overrides and Label Settings to your children dynamically.

### Boilerplate Example for New UI Components

Use the below snippet as a starting point for AI agents or Developers building new UI widgets.

```gdscript
extends Control
class_name MyCustomUI

var style_profile: UIStyleProfile

var main_panel: Panel
var title_label: Label
var details_label: Label
var accent_rect: ColorRect

func _ready() -> void:
    # 1. Fetch References Safely
    main_panel = get_node_or_null("Box/MainPanel") as Panel
    title_label = get_node_or_null("Box/MainPanel/TitleLabel") as Label
    details_label = get_node_or_null("Box/MainPanel/DetailsLabel") as Label
    accent_rect = get_node_or_null("AccentRect") as ColorRect
    
    # Hide by default if driven by gameplay logic
    # visible = false 

# 2. Implement apply_style matching UIRoot expectation
func apply_style(style: UIStyleProfile) -> void:
    style_profile = style
    
    # Apply dynamically generated Panel StyleBox
    if main_panel != null:
        # "default", "elevated", or "debug" variant
        main_panel.add_theme_stylebox_override("panel", style_profile.make_panel_style("elevated")) 
        
    # Apply Font and Size logic via label_settings helpers
    if title_label != null:
        # "title", "body", "selected", "meta", "accent", or "debug" roles
        title_label.label_settings = style_profile.make_label_settings("title")
        
    if details_label != null:
        details_label.label_settings = style_profile.make_label_settings("body")
        
    # Dynamically fetch colors
    if accent_rect != null:
        accent_rect.color = style_profile.get_accent_color()
```

## 4. Registering Your Component with UIRoot

For your new component to actually receive the styles, `UIRoot` needs to know it exists.

1. Instance your new UI component under `GameplayLayer`, `DebugLayer`, or applicable layer in `UIRoot.tscn`.
2. Open `UIRoot.gd`.
3. In the **References** snippet section, declare a variable for your component.
   ```gdscript
   var my_custom_ui: MyCustomUI
   ```
4. In `_ready()`, fetch the reference to the node.
   ```gdscript
   my_custom_ui = get_node_or_null("GameplayLayer/HUD/MyCustomUI") as MyCustomUI
   ```
5. In the `_apply_ui_style()` function, add your component to the iteration array:
   ```gdscript
   func _apply_ui_style() -> void:
       for component in [
           crosshair_ui, interact_prompt_ui, status_cluster_ui, 
           quick_action_panel_ui, debug_stats_ui, my_custom_ui # Added here!
       ]:
           if component != null and component.has_method("apply_style"):
               component.apply_style(runtime_ui_style)
   ```

By adding it to this array, the component will be fully styled at runtime in parity with the rest of the UI.

## 5. UI Fade Animation System

The UI supports automatic fade-in and fade-out animations controlled by `UIFadeController`. This is useful for ephemeral data like stamina/load indicators that should fade out when stable.

### How Fade Works

- **Fade-in**: Triggered when a tracked value changes
- **Stability detection**: If the value remains unchanged for 6 frames, a fade-out is automatically queued
- **Duration & easing**: Configured via `UIStyleProfile` exports (`fade_in_duration`, `fade_out_duration`, `fade_easing_type`)
- **Tier gating**: LOW tier uses instant fades (0.0s duration), HIGH tier uses smooth animations (0.15-0.25s)

### Using UIFadeController in Your Component

To add fade behavior to an existing UI component:

```gdscript
extends Control
class_name MyStatusUI

var style_profile: UIStyleProfile
var fade_controller: UIFadeController

func _ready() -> void:
    # Create fade controller
    fade_controller = UIFadeController.new()
    # Pass this node and the style profile
    fade_controller.initialize(self, style_profile)
    # Add fade signal handlers if desired
    fade_controller.fade_started.connect(_on_fade_started)
    fade_controller.fade_completed.connect(_on_fade_completed)

func apply_style(style: UIStyleProfile) -> void:
    style_profile = style
    if fade_controller:
        fade_controller.style_profile = style

func _process(_delta: float) -> void:
    # Observe a value each frame (e.g., stamina_ratio)
    if fade_controller:
        fade_controller.observe_value(stamina_ratio)

func _on_fade_started(direction: String) -> void:
    # Called when fade begins
    pass

func _on_fade_completed(direction: String) -> void:
    # Called when fade completes
    pass
```

### Fade Animation Flow

1. You call `fade_controller.observe_value(current_value)` each frame
2. Controller detects when value changes → triggers fade-in
3. Controller counts stable frames (no change)
4. After threshold reached (6 frames) → triggers fade-out
5. Signals `fade_started()` and `fade_completed()` for UI events

For detailed implementation, see `Player/Debug/Scripts/UIFadeController.gd`.

## 6. Responsive Layout Framework

The UI supports responsive layout similar to web design, adapting margins and positioning based on viewport resolution.

### Available Breakpoints

`ResponsiveLayoutManager` defines 4 breakpoints with automatic margin scaling:

| Breakpoint | Resolution | Margin Scale |
|-------------|-----------|--------------|
| **MOBILE** | < 720px | 0.75x (75% of base) |
| **TABLET** | 720-1280px | 0.90x |
| **DESKTOP** | 1280-2560px | 1.0x (base margins) |
| **ULTRAWIDE** | > 2560px | 1.15x (115% of base) |

### Integrating Responsive Layout

For a UI component that needs responsive positioning:

1. **Enable responsive layout in UIStyleProfile**:
   - Set `use_responsive_layout = true` (in UIStyleProfile exports)

2. **In your component, register with ResponsiveLayoutManager**:
   ```gdscript
   extends Control
   class_name MyResponsiveUI

   var layout_manager: ResponsiveLayoutManager

   func _ready() -> void:
       # Get reference from UIRoot (passed via apply_style or dependency injection)
       layout_manager = UIRoot.responsive_layout_manager
       if layout_manager:
           layout_manager.register_component(self, "anchor_position_string")

   func on_breakpoint_changed(new_breakpoint: String) -> void:
       # Called when viewport breakpoint changes
       # Update your positioning here
       _update_responsive_position()

   func _update_responsive_position() -> void:
       # Use ResponsiveLayoutManager to get scaled positions
       if layout_manager:
           var scaled_margin = layout_manager.get_scaled_margin("top")
           position.y = scaled_margin
   ```

3. **Connect the breakpoint signal**:
   ```gdscript
   if layout_manager:
       layout_manager.breakpoint_changed.connect(on_breakpoint_changed)
   ```

### Example: Repositioning on Breakpoint Change

```gdscript
func _update_responsive_position(animate: bool = true) -> void:
    if not layout_manager:
        return

    var target_pos = layout_manager.get_anchored_position(anchor_name)
    
    if animate and style_profile.presentation_tier == UIStyleProfile.Tier.HIGH:
        # Smooth animation on HIGH tier
        var tween = create_tween()
        tween.set_trans(Tween.TRANS_QUAD)
        tween.set_ease(Tween.EASE_OUT)
        tween.tween_property(self, "position", target_pos, 0.3)
    else:
        # Instant on LOW tier
        position = target_pos
```

For detailed implementation, see `Player/Debug/Scripts/ResponsiveLayoutManager.gd`.

## 7. Programmatic UI Creation (Advanced)

By default, UI components are created as scenes in the editor and referenced in UIRoot. However, some components (like `BoundingBoxVisualUI`) are created at runtime and added to the scene tree programmatically.

### When to Use Programmatic Creation

- Component is spawned conditionally (optional feature)
- Component needs lifecycle tied to a gameplay system (e.g., interaction focus)
- Component is internal/utility and doesn't need editor visibility

### Example: Creating BoundingBoxVisualUI Programmatically

In `UIRoot._ready()`:

```gdscript
# Create the bounding box UI programmatically
bounding_box_ui = BoundingBoxVisualUI.new()
hud_layer.add_child(bounding_box_ui)
bounding_box_ui.apply_style(runtime_ui_style)

# Wire signals
if interaction_component:
    interaction_component.focus_changed.connect(_on_interaction_focus_changed)
```

Then in `_on_interaction_focus_changed()`:

```gdscript
func _on_interaction_focus_changed(new_target: Node) -> void:
    if bounding_box_ui:
        bounding_box_ui.set_target(new_target)
```

### Key Considerations

- Programmatic UI must still implement `apply_style()` for styling consistency
- Must be added to the scene tree via `add_child()` before use
- Consider cleanup strategy (Godot auto-garbage collects through lifecycle)
- For RefCounted utility objects, ensure proper initialization before use
