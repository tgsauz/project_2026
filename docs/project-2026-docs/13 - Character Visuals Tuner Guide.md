# 13 - Character Visuals Tuner Guide

The **Character Visuals Tuner** is a standalone developer tool for aligning equipment, clothing, and attachments in real-time. It eliminates the need to restart the game to see minor transform changes.

## Location
Open and run: `res://Tools/CharacterTuner/CharacterTuner.tscn`

## Core Workflow

1.  **Select a Slot**: Choose the attachment slot you want to tune (e.g., `Back Mount`, `Right Hand`).
2.  **Equip an Item**: Select an `ItemDefinition` from the list to preview it in the selected slot.
3.  **Tune Transforms**: Use the sliders on the right to adjust `Position`, `Rotation`, and `Scale`.
4.  **Preview Locomotion**: Use the `Lateral` and `Forward` sliders at the bottom to transition the character into walking/running animations. This is critical for checking **clipping** with the body or other items.
5.  **Save Changes**: Click **"Save To Resource"** to commit the current transform values directly to the item's `AttachmentProfile`.

## Technical Architecture

The Tuner uses the same `VisualsComponent` as the player character, but it injects data manually:

-   **CharacterTunerController**: Bridges the UI and the character rig. It scans `res://World/Items/` for definitions and handles the `ResourceSaver` logic.
-   **TunerCamera**: An orbit camera (`Left Click` to Orbit, `Right Click` to Pan, `Scroll` to Zoom) for close-up inspection.
-   **VisualsComponent.set_runtime_visual()**: An external API added to support manual equipment forcing without an active `InventoryComponent`.

## Best Practices for Alignment

-   **Backpacks**: Align them while the character is in a "Walk" animation to ensure they don't clip into the spine during movement.
-   **Vests/Clothing**: These are often `skinned_mesh` items. If they clip, you may need to adjust the baseline `CharacterTuner.tscn` rig or modify the `AttachmentProfile` scale.
-   **Weapons**: Use the `Right Hand` slot and check the rotation against the `ik_hand_gun` bone.

## Troubleshooting

-   **Items Not Showing Up**: Ensure your items are stored in `res://World/Items/` and have a valid `equipped_visual_scene`.
-   **Save Fails**: Ensure you are running the project in the Godot Editor; `ResourceSaver` might not work in exported headless builds.
