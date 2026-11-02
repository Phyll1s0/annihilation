# Visual and audio assets

NULL uses black-and-white pieces against a pure black background (#000000), with sparse orbital trails and an empty zero as its mark.

- The mark in scripts/ui/zero_mark.gd is a native vector oval with a softly varying edge. It turns slowly while a silver highlight travels around its edge, and responds to start-button hover and keyboard focus. Reduced motion freezes it; it stops updating while the title screen is hidden.
- scripts/ui/void_background.gd draws vector stars, slowly drifting trails, and an occasional meteor over solid black. Details fade during play. Reduced motion freezes the trails and disables meteors.
- scripts/ui/direction_glyph.gd draws shared single arrows for one-way tiles and the editor direction picker. Large low-opacity arrows sit in the center of each field tile; the direction picker uses the same vector shape at full contrast.
- icon.svg and toggle-*.svg are project-specific vector assets.
- Settings toggles use DPITexture resources, rasterized from their SVG source at the current UI size. Interface icons retain their full source resolution and use mipmaps when reduced.
- The NULL wordmark uses Poppins Thin, with a larger size and close letter spacing, and scales at the current display resolution.
- Poppins-Thin.ttf, Poppins-ExtraLight.ttf, and Poppins-Regular.ttf come from the [Google Fonts repository](https://github.com/google/fonts/tree/main/ofl/poppins). The bundled OFL license is retained in source and export packages. Chinese text uses system font fallbacks.
- General interface icons use Ionicons 7.1.0, with grayscale tinting applied by Godot. Their license is included in icons/LICENSE.txt.

## Music

`audio/still-orbit.ogg` is **Still Orbit**, an original 96-second piano composition and arrangement for NULL. Its revised arrangement repeats a descending four-note motif over a D / Bb / F / C bass cycle, with shorter note gates and gentler reverb. The steady-state reverb tail wraps into the next repetition; playback fades in, stays continuous across menus, and becomes quieter during puzzles. Settings → Audio controls the music toggle and saved volume.

The piano instrument uses the CC0 [VSCO 2 Community Edition Upright Piano](https://github.com/sgossner/VSCO-2-CE/tree/440300901dfe9275fd84e0b7763af1f8443ae62e/Keys/Upright%20Piano), sampled by Simon Dalzell / Ivy Audio and distributed by Sam Gossner / Versilian Studios. [Credits](audio/CREDITS.txt) and the [source sample license](audio/VSCO-CC0-LICENSE.txt) are included in source and exported builds. The original score and arrangement use the project's MIT license.

The committed Ogg file is ready to play. To regenerate it, use `tools/render_music.py` with `tools/music-requirements.txt` in an isolated Python environment. The renderer downloads checksum-verified samples from the pinned source revision into `builds/music-samples/`; those source recordings are not required at runtime.

The [original and revised study scores](../output/pdf/still-orbit-score.pdf) include readable notation, a timing comparison, and editable MusicXML and MIDI files beside the PDF. The reading notation shortens note lengths and rounds the original attacks for legibility; MIDI retains the humanized attack times and renderer gates. Both score revisions live in `tools/music_score.py`. To regenerate the PDF, use `tools/export_music_score.py` with `tools/notation-requirements.txt` and an available Cairo library.
