# Visual and audio assets

NULL uses black-and-white pieces against a pure black background (#000000), with sparse orbital trails and an empty zero as its mark.

- The mark in scripts/ui/zero_mark.gd is a native vector oval with a softly varying edge. It responds to start-button hover and keyboard focus.
- scripts/ui/void_background.gd draws vector stars, slowly drifting trails, and an occasional meteor over solid black. Details fade during play. Reduced motion freezes the trails and disables meteors.
- icon.svg and toggle-*.svg are project-specific vector assets.
- Settings toggles use DPITexture resources, rasterized from their SVG source at the current UI size. Interface icons retain their full source resolution and use mipmaps when reduced.
- Poppins-ExtraLight.ttf and Poppins-Regular.ttf come from the Google Fonts repository. The bundled OFL license is retained in source and export packages. Chinese text uses system font fallbacks.
- General interface icons use Ionicons 7.1.0, with grayscale tinting applied by Godot. Their license is included in icons/LICENSE.txt.

## Music

`audio/still-orbit.ogg` is **Still Orbit**, an original 96-second piano composition and arrangement for NULL. The steady-state reverb tail wraps into the next repetition; playback fades in, stays continuous across menus, and becomes quieter during puzzles. Settings → Audio controls the music toggle and saved volume.

The piano instrument uses the CC0 [VSCO 2 Community Edition Upright Piano](https://github.com/sgossner/VSCO-2-CE/tree/440300901dfe9275fd84e0b7763af1f8443ae62e/Keys/Upright%20Piano), sampled by Simon Dalzell / Ivy Audio and distributed by Sam Gossner / Versilian Studios. [Credits](audio/CREDITS.txt) and the [source sample license](audio/VSCO-CC0-LICENSE.txt) are included in source and exported builds. The original score and arrangement use the project's MIT license.

The committed Ogg file is ready to play. To regenerate it, use `tools/render_music.py` with `tools/music-requirements.txt` in an isolated Python environment. The renderer downloads checksum-verified samples from the pinned source revision into `builds/music-samples/`; those source recordings are not required at runtime.
