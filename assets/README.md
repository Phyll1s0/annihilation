# Visual and audio assets

ANNIHILATION uses black-and-white pieces against a pure black background (#000000), with sparse orbital trails and an empty zero as its mark.

- The mark in scripts/ui/zero_mark.gd is a native vector oval with a softly varying edge. It turns slowly while a silver highlight travels around its edge, and responds to start-button hover and keyboard focus. Reduced motion freezes it; it stops updating while the title screen is hidden.
- scripts/ui/void_background.gd draws vector stars, slowly drifting trails, and an occasional meteor over solid black. Details fade during play. Reduced motion freezes the trails and disables meteors.
- scripts/ui/direction_glyph.gd draws shared single arrows for one-way tiles and the editor direction picker. Large low-opacity arrows sit in the center of each field tile; the direction picker uses the same vector shape at full contrast.
- icon.svg and toggle-*.svg are project-specific vector assets.
- Settings toggles use DPITexture resources, rasterized from their SVG source at the current UI size. Interface icons retain their full source resolution and use mipmaps when reduced.
- The ANNIHILATION wordmark uses Poppins Thin, with close letter spacing. The single-line title scales with the display and fits narrow windows independently of the Start button.
- Poppins-Thin.ttf, Poppins-ExtraLight.ttf, and Poppins-Regular.ttf come from the [Google Fonts repository](https://github.com/google/fonts/tree/main/ofl/poppins). The bundled OFL license is retained in source and export packages. Chinese text uses system font fallbacks.
- General interface icons use Ionicons 7.1.0, with grayscale tinting applied by Godot. Their license is included in icons/LICENSE.txt.

## Music

`audio/still-orbit.ogg` is **Still Orbit**, an original 96-second piano composition and arrangement for ANNIHILATION. Its current airy arrangement uses a slow A-B-E melodic arch, a quiet repeated A3 pulse, and open D / G / B / A bass movement. A very soft synthesized organ layer connects the piano phrases; bass-filtered reverb keeps the space clear. The steady-state reverb tail wraps into the next repetition; playback fades in over four seconds, stays continuous across menus, and becomes quieter during puzzles. Settings → Audio controls the music toggle and saved volume.

The piano instrument uses the CC0 [VSCO 2 Community Edition Upright Piano](https://github.com/sgossner/VSCO-2-CE/tree/440300901dfe9275fd84e0b7763af1f8443ae62e/Keys/Upright%20Piano), sampled by Simon Dalzell / Ivy Audio and distributed by Sam Gossner / Versilian Studios. [Credits](audio/CREDITS.txt) and the [source sample license](audio/VSCO-CC0-LICENSE.txt) are included in source and exported builds. The original score and arrangement use the project's MIT license.

The committed Ogg file is ready to play. To regenerate it, use `tools/render_music.py` with `tools/music-requirements.txt` in an isolated Python environment. The renderer downloads checksum-verified samples from the pinned source revision into `builds/music-samples/`; those source recordings are not required at runtime.

The [current airy piano study score](../output/pdf/still-orbit-air-score.pdf) includes readable notation and a timing comparison. Its MusicXML, piano-only MIDI, and note list are beside the PDF; the quiet organ bed is documented in the renderer. The [earlier arrangement comparison](../output/pdf/still-orbit-score.pdf) preserves the first two versions. Reading notation simplifies note lengths and rounds the original attacks for legibility; MIDI retains humanized piano attack times and gates. All three score revisions live in `tools/music_score.py`. To regenerate the current PDF, use `tools/export_music_score.py --air` with `tools/notation-requirements.txt` and an available Cairo library.

Board tile outlines use 70% white, with stronger group-colored outlines on portals. Black particles use a bright silver outline with a 1.65-pixel base stroke; outlines grow with the display scale to remain readable in fullscreen.
