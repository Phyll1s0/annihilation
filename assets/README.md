# Visual assets

NULL uses black-and-white pieces against a pure black background (#000000), with sparse orbital trails and an empty zero as its mark.

- The mark in scripts/ui/zero_mark.gd is a native vector oval with a softly varying edge. It responds to start-button hover and keyboard focus.
- scripts/ui/void_background.gd draws vector stars, slowly drifting trails, and an occasional meteor over solid black. Details fade during play. Reduced motion freezes the trails and disables meteors.
- icon.svg and toggle-*.svg are project-specific vector assets.
- Poppins-ExtraLight.ttf and Poppins-Regular.ttf come from the Google Fonts repository. The bundled OFL license is retained in source and export packages. Chinese text uses system font fallbacks.
- General interface icons use Ionicons 7.1.0, with grayscale tinting applied by Godot. Their license is included in icons/LICENSE.txt.
