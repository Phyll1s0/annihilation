# Level editor

Choose **Create** on the title screen. The original **Settings → Developer → Developer mode → Level editor** route is also available.
The editor is designed for desktop windows, including fullscreen and high-resolution displays.

## Make a map

1. Choose **New**, or select a campaign level from **Open a level…** to make an editable copy.
2. Enter a name. Set the width and height, then choose **Resize**. Maps can be 1–12 tiles in each direction.
3. Select a brush and click or drag across the board. Right-click removes a tile and its particle.
4. Choose **Playtest**, or press **F5**, to try the map immediately.
5. Choose **Save** to keep the level in **My levels**. Complete playtests to establish and improve its records.

| Brush | Effect |
| --- | --- |
| Floor | Place a normal tile; keep any particle. |
| Void | Remove the tile and its particle. |
| White / Black | Place a particle, adding a floor if needed. |
| Erase piece | Remove a particle while keeping the terrain. |
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

## Playtest and records

Playtest maps immediately. Custom levels have no Easy/Hard split or automatic shortest-path search.
Use the regular movement, teleport, undo, restart, and pause controls; return to the editor to continue drawing.
Only the completed walk remaining after undo is counted. Restart clears the current walk.

Choose **Leaderboard** to set a player name and see the local ranking. Each name keeps its best completed walk; fewer moves rank first, with names breaking ties. The first completion sets the **best known** record. A shorter completion replaces it without claiming a theoretical minimum.

Records belong to the map's terrain, particles, and portal connections. Renaming a map or importing it under a new identity preserves the matching ranking. Changing its geometry starts a different ranking; undoing that change restores the original ranking. Relabeling portals without changing their connections also keeps the ranking.

Names are local labels, not authenticated accounts. There is no automatic online synchronization. Up to 100 personal bests are retained per map.

## Import and export

**Import** and **Export** open the level JSON panel. You can paste or copy JSON, open a file, or save a file. Web exports download through the browser.

Exports contain the map and its leaderboard under the optional `records` field. Send the JSON to another player, then import their exported JSON to merge improved scores. Repeated imports do not duplicate names or replace a better score with a worse one.

Imported maps receive a new custom identity, while matching maps share records. Every submitted or imported score is replayed using the game rules and must finish the map. Claimed move counts are ignored; the completed walk determines the score. Invalid scores are skipped without discarding the map. This verifies a particular completion, not the shortest possible solution.

Imports accept files up to 8 MB and walks up to 10,000 moves. Exports include the highest-ranked records that fit the sharing budget. Old files with minimum-move certificates still import; those certificates are ignored for custom play.

Example of a shareable level and completed walk:

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
  },
  "records": [
    {
      "player": "Player",
      "actions": [
        {"source": 0, "direction": "right"},
        {"source": 3, "direction": "right"}
      ]
    }
  ]
}
```

Raw campaign-format level objects can also be imported. Particle positions on portals use the optional `tokens` array described in [level authoring](levels.md).

Custom content is stored under `user://editor/`: `draft.json` for the active draft, `levels/` for saved maps, `records.json` for player names and best walks, and `playtest.json` for test runs.
Export JSON files to share them or keep them under version control.
