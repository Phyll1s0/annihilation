# Level editor

Open **Settings → Developer**, enable **Developer mode**, then choose **Level editor**.
The editor is designed for desktop windows, including fullscreen and high-resolution displays.

## Make a map

1. Choose **New**, or select a campaign level from **Open a level…** to make an editable copy.
2. Enter a name. Set the width and height, then choose **Resize**. Maps can be 1–12 tiles in each direction.
3. Select a brush and click or drag across the board. Right-click removes a tile and its particle.
4. Choose **Playtest**, or press **F5**, to try the map immediately.
5. Choose **Find minimum** to search for the shortest solution, then **Save** to keep the level in **My levels**.

| Brush | Effect |
| --- | --- |
| Floor | Place a normal tile; keep any particle. |
| Void | Remove the tile and its particle. |
| White / Black | Place a particle, adding a floor if needed. |
| Clear | Remove a particle while keeping the terrain. |
| Portal | Place the selected A–Z portal group, keeping any particle. |

Each portal group has two ends. Remove an existing end before placing a third.
Playable maps need equal, nonzero black and white counts, and complete portal pairs.
Incomplete maps can still be saved as drafts.

**Ctrl/Cmd Z** undoes a stroke; **Ctrl/Cmd Shift Z** redoes it. **Ctrl/Cmd S** saves the level.
Resizing preserves cells inside the new bounds and can be undone.

## Drafts and saved levels

The current draft is saved automatically. Reopening the editor restores it.
**Save** updates the current entry in **My levels**. Switching away from unsaved edits keeps a draft copy instead of overwriting an existing saved original.

Campaign maps are copied into custom levels. Editing or playtesting them does not change the campaign, its completion records, or its current checkpoint.

## Playtest and verify

An unverified map can be tested in **Easy**. **Hard** becomes available after its minimum is verified.
Playtests use the regular movement, teleport, undo, restart, and pause controls; return to the editor to continue drawing.

The shortest-path search runs in the background on desktop and in small frame-sized batches on Web.
You can cancel it or keep editing. Results from an older draft cannot certify a changed map.

Search has time and memory limits. Reaching a limit is different from proving that a map has no solution; Easy playtesting remains available.
Campaign copies retain their existing certificate until their terrain or particles change. Renaming a level preserves its certificate, and undoing a change restores the certificate with the matching map.

## Import and export

**Import** and **Export** open the level JSON panel. You can paste or copy JSON, open a file, or save a file. Web exports download through the browser.

Imported files receive a new custom identity. External minimum-move claims are treated as unverified until the editor searches the map itself.
Locally saved, verified maps retain their certificate when reopened.

Example of an unverified level:

```json
{
  "format": "null-level",
  "version": 1,
  "level": {
    "id": "custom_example",
    "title": "My Orbit",
    "chapter": "Custom",
    "description": "Custom level",
    "layout": ["wA#Ab"],
    "optimal_moves": 0
  }
}
```

Raw campaign-format level objects can also be imported. Particle positions on portals use the optional `tokens` array described in [level authoring](levels.md).

Custom content is stored under `user://editor/`: `draft.json` for the active draft, `levels/` for saved maps, and `playtest.json` for test runs.
Export JSON files to share them or keep them under version control.
