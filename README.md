# NULL

NULL is a minimalist grid puzzle about black and white particles, disappearing paths, and finding the shortest solution. Built with Godot 4 and GDScript.

![NULL title screen](docs/images/home.png)

## Gameplay

Select a particle and move it one tile up, down, left, or right.

- Particles must stay on the remaining tiles.
- Particles of the same color block each other.
- When opposite colors meet, both particles disappear, along with the tile where they meet.
- Clear every particle to finish the level.

Portals with matching letters are linked. Entering an empty portal teleports the particle to its partner and costs one move. A same-colored particle at the exit blocks the move. If a collision happens on a portal, that end disappears and its partner becomes a normal tile.

## Modes

| Mode | Goal |
| --- | --- |
| Easy | Clear the board in any number of moves. |
| Hard | Clear the board in the verified minimum number of moves. |

Each level supports both modes, with separate completion records and a shared personal best. Invalid moves and selection changes do not count. Undo restores particles, tiles, portals, and the move counter.

## Features

- 20 handcrafted levels across six chapters, all available from level selection.
- Minimum move counts verified by independent Python and GDScript solvers.
- Automatic saves, resumable games, and undo history restored after restarting.
- A minimal title screen with scalable text and controls that starts the next unfinished level or resumes the current run.
- Black-and-white pieces, a pure black background with faint star trails, and an orbital zero mark.
- Responsive chapter selection, progress indicators, pause menus, and Settings, with readable controls in fullscreen.
- Reduced-motion controls; background details fade during play.
- English by default, with an instant, saved switch to Simplified Chinese in Settings → General → Language.
- Centered, square-cell boards that resize with the window, without a text footer during play.

## Controls

| Input | Action |
| --- | --- |
| Click a particle, then an adjacent tile | Select and move |
| Arrow keys / WASD | Move the selected particle |
| Tab / Shift+Tab | Cycle through particles |
| Z | Undo |
| R | Restart the level |
| Esc | Deselect, then pause |
| Enter / Space on the title screen | Start or continue |
| F11 | Toggle fullscreen |

Level selection is available from the back button during play or the pause menu. Switching modes restarts the current level.
Optional controls and a short rules reference are available under Settings → Controls.

## Run locally

Open the project with **Godot 4.6** and press **F5**, or run:

~~~bash
godot --path .
~~~

Tested with Godot **4.6.2**. The game runs locally, with progress and preferences stored on your device.

## Development

Levels live in `data/levels.json`. The rules, session history, rendering, navigation, and persistence are separate modules.
UI copy and level names use English source messages, with translations in `locale/`. Changing language keeps the current puzzle and undo history intact.

~~~bash
python3 tools/check.py
python3 tools/check.py --visual
~~~

The visual checks open native windows and save screenshots in `builds/`. Tests use isolated saves.
Layout checks cover all 20 levels at thirteen viewport sizes, including ultrawide, portrait, and 5K layouts. They verify proportional board growth, pointer input, and undo after resizing a live puzzle.
Navigation checks cover all six chapters in both languages, resizing up to 5K and back, and leaving, pausing, restarting, and resuming a puzzle through the menus.

After changing a level, regenerate its shortest-path certificate and run the checks:

~~~bash
python3 tools/certify_levels.py --write
python3 tools/check.py
~~~

See [design notes](docs/design.md) and [level authoring](docs/levels.md) for implementation details. Both documents are in Chinese.

## Export

Install the export templates matching your Godot version. macOS and Web presets are included.

~~~bash
mkdir -p builds/macos builds/web
godot --headless --path . --export-release macOS builds/macos/NULL.zip
godot --headless --path . --export-release Web builds/web/index.html
~~~

Serve the Web build over HTTP. Build outputs and editor caches are excluded from Git.

## License

[MIT](LICENSE). Font and icon licenses are included with their [assets](assets/README.md).
