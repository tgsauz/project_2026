# 13 - Character Visuals Tuner Guide

The **Character Visuals Tuner** is a standalone developer tool for aligning equipment, clothing, and attachments in real-time. It eliminates the need to restart the game to see minor transform changes.

## Location
Open and run: `res://Tools/CharacterTuner/CharacterTuner.tscn`

## Core Workflow

1.  **Select a Slot**: Choose the attachment slot you want to tune (e.g., `Back Mount`, `Right Hand`).
2.  **Equip an Item**: Select an `ItemDefinition` from the list to preview it in the selected slot.
3.  **Tune Transforms**: Use the sliders on the right to adjust `Position`, `Rotation`, and `Scale`.
4.  **Preview Locomotion**: Use the `Lateral` and `Forward` sliders at the bottom to transition the character into walking/running animations. This is critical for checking **clipping** with the body or other items.
5.  **Use Authoring Helpers**: `Copy`, `Paste`, `Mirror L/R`, `Rescan Items`, and `Anchor Debug` are available from the tuner UI.
6.  **Save Changes**: Click **"Save To Resource"** to commit the current transform values directly to the item's `AttachmentProfile`.

## Technical Architecture

The Tuner uses the same `VisualsComponent` as the player character, but it injects data manually:

-   **CharacterTunerController**: Bridges the UI and the character rig. It scans item definitions recursively through `ItemDefinitionRegistry`, derives slot lists from the shared equipment slot catalog, and handles the `ResourceSaver` logic.
-   **CharacterTunerController**: Bridges the UI and the character rig. It scans item definitions recursively through `ItemDefinitionRegistry`, derives tuneable nodes from the shared attachment layout plus equipment modifiers, and handles the `ResourceSaver` logic.
-   **TunerCamera**: An orbit camera (`Left Click` to Orbit, `Right Click` to Pan, `Scroll` to Zoom) for close-up inspection.
-   **VisualsComponent.set_runtime_visual()**: An external API added to support manual equipment forcing without an active `InventoryComponent`.

## Examples
### Rescan item definitions
Use `Rescan Items` after adding a new `.tres` under `res://World/Items/`, even if it lives in a nested subfolder such as `res://World/Items/TestData/Nested/`.

### Tune a contributed equipment node
1. Equip a belt or vest in-game authoring data so its modifier exists.
2. In the tuner, select a node such as `Belt Slot 01 [Gear]`.
3. Pick a compatible item like `Utility Pouch`.
4. Adjust the transform and save the attachment profile for that contributed node.

### Copy and paste a transform
1. Tune a `Right Hand` profile.
2. Press `Copy`.
3. Select a different compatible item or slot profile.
4. Press `Paste`.
5. Save if the result is correct.

### Mirror a hand-held transform
1. Tune a `Right Hand` weapon profile.
2. Select the matching `Left Hand` item profile.
3. Press `Mirror L/R`.
4. The current mirror rule negates X position and negates Y/Z rotation.
5. Validate the result in locomotion preview before saving.

## Best Practices for Alignment

-   **Backpacks**: Align them while the character is in a "Walk" animation to ensure they don't clip into the spine during movement.
-   **Vests/Clothing**: These are often `skinned_mesh` items. If they clip, you may need to adjust the baseline `CharacterTuner.tscn` rig or modify the `AttachmentProfile` scale.
-   **Weapons**: Use the `Right Hand` slot and check the rotation against the `ik_hand_gun` bone.

## Troubleshooting

-   **Items Not Showing Up**: Ensure the item is under `res://World/Items/`, has a valid `equipped_visual_scene`, and either includes the selected node in `allowed_slots` or matches the node's accepted categories/tags.
-   **Save Fails**: Ensure you are running the project in the Godot Editor; `ResourceSaver` might not work in exported headless builds.
-   **Slot Missing In Tuner**: The node must be enabled in the shared attachment layout or equipment modifier with `tuner_enabled = true`.
