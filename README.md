# Ancient Nest

Ancient Nest's cinematic main-menu preview, based on the reference artwork supplied for the project.

![Ancient Nest main-menu preview](docs/menu-preview.webp)

## Current status

The repository includes a working browser menu with Play, Custom Match, Settings, and Quit controls. It uses a generated adaptation of the supplied reference, with live title text and interactive menu controls over the artwork.

Game engine integration and gameplay have not been added. Play and Custom Match open clearly labeled preview screens. Settings control menu sound and volume and save locally when browser storage is available. Quit shows an exit screen with a return action; it does not attempt to close the browser tab.

## Open the menu

Open `index.html` in a modern browser. No installation or build step is required.

For a local HTTP preview, run this command from the repository directory, then visit <http://localhost:8000>:

```sh
python3 -m http.server 8000
```

Use a mouse, touch, or keyboard. Tab moves between controls; arrow keys change the menu selection; Enter activates it; Escape closes a dialog or returns from the exit screen.

## Structure

- `index.html`: browser preview entry point.
- `src/menu.css`: responsive layout and menu styling.
- `src/menu.js`: navigation, preview screens, and saved settings.
- `assets/main-menu.webp`: generated adaptation of the reference artwork.
- `docs/main-menu.md`: design notes and implementation status.

## Next step

Choose the game's engine and connect Play and Custom Match to gameplay. The current browser preview is a visual and interaction reference for that integration.

## Get the repository

Clone the repository from GitHub:

```sh
git clone https://github.com/perdoobie-glitch/Ancient-Nest.git
cd Ancient-Nest
```
