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
