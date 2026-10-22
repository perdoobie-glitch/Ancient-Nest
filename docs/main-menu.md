# Main menu reference

The main menu follows the Ancient Nest reference image supplied in the conversation. A browser implementation is available in `index.html`; it does not require a game engine or a build step.

## Implemented

- A generated adaptation of the supplied scene and emblem is included as `assets/main-menu.webp`.
- The title and all four menu controls are rendered separately from the background.
- A horizontal menu follows the reference at landscape sizes; portrait screens use two rows with touch-sized controls.
- Mouse, touch, Tab, arrow keys, Enter, and Escape work for navigation and dialogs.
- Settings change synthesized menu sound volume and enable or disable sound, persisting on this device when browser storage is available.
- Play and Custom Match show honest preview messages until gameplay is implemented.
- Quit opens an exit screen, and Return to menu restores focus.

The generated artwork is an adaptation, rather than the original attached image file. The emblem is part of that artwork. The supplied source image itself has not been added as a repository asset.

## Visual direction

- Full-screen cinematic scene with ancient stone towers, waterfalls, vegetation, and a large celestial body in the sky.
- An armored character with a red cape and a bird on the left.
- A white armored character with green accents on the right.
- A large metallic gold emblem in the center, shaped like an A and incorporating a woven nest and branches.
- The title ANCIENT NEST beneath the emblem in widely spaced serif capitals.
- A horizontal menu near the lower center with thin gold rules and diamond ornaments.
- Warm gold highlights, deep shadows, and soft foreground blur.

## Menu items

In order from left to right:

1. Play
2. Custom Match
3. Settings
4. Quit

Play is highlighted in the supplied reference. Selection should have a warm gold glow. Each item must connect to the corresponding game action once game code is available.

## Implementation requirements

- Preserve the reference composition at a 16:9 aspect ratio.
- Keep title and menu text readable at other supported display sizes.
- Use interactive menu controls with pointer and keyboard support; add controller support if the game supports it.
- Keep labels and controls separate from background artwork.
- Use the supplied reference artwork or approved production assets when available.

## Pending project inputs

- Game engine and source files.
- Menu action handlers and navigation destinations.
