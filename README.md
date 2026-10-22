# Ancient Nest

Ancient Nest's cinematic main-menu preview, based on the reference artwork supplied for the project.

![Ancient Nest main-menu preview](docs/menu-preview.webp)

## Current status

The repository includes a working browser menu with Play, Custom Match, Settings, and Quit controls. It uses a generated adaptation of the supplied reference, with live title text and interactive menu controls over the artwork.

A Godot account starter and Cloudflare accounts service are included below. Gameplay and integration of the browser menu into Godot have not been added. Play and Custom Match open clearly labeled preview screens. Settings control menu sound and volume and save locally when browser storage is available. Quit shows an exit screen with a return action; it does not attempt to close the browser tab.

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

## Windows one-click setup and launch

In the full download, double-click **Setup Ancient Nest.cmd** to configure and deploy
the service. The shortcut installs Node.js if needed, opens Cloudflare login, applies
migrations, asks securely for missing provider credentials, and checks readiness.
You need your existing Cloudflare, Resend, Twilio, and Discord accounts for that
first setup. It preserves existing secrets and does not reset the database.

For players, open **Play Ancient Nest.cmd** in the full download, or extract the
Windows player ZIP and open **Ancient Nest.exe**. Godot
and terminal commands are not needed. The full download includes the player folder;
source checkouts use the [build instructions](ancient-nest-accounts/README.md#windows-shortcuts-and-download).
This is an account/voice starter; gameplay and live deployment are still outstanding.

## Godot login and accounts service

The [accounts project](ancient-nest-accounts/README.md) includes a D1-backed Cloudflare
Worker and a [Godot 4 client](ancient-nest-accounts/godot-client/README.md). Registration
requires email and phone. The client automatically attempts saved sign-in when the
game starts, continues on success, and requires manual login if restoration fails.
It also includes Discord account linking and team-voice integration.

Install the project dependencies and pinned native addons:

```sh
cd ancient-nest-accounts
npm ci
npm run discord:install
```

Open `ancient-nest-accounts/godot-client/project.godot` in Godot 4.4 or newer
(validated with 4.6.3). The startup scene is the account screen. Until a gameplay
scene is assigned, successful login shows a signed-in status. The existing browser
menu remains a visual reference; no gameplay scene has been invented.

The Worker configuration already identifies the existing `ancientnestaccounts`
D1 database and Discord application. Follow the [deployment instructions](ancient-nest-accounts/README.md#install-and-deploy)
to authenticate Cloudflare, apply migrations, configure provider secrets, and deploy.
The default accounts URL is configured in the Godot project; it must point to the
live deployed service. Adding these files does not deploy Cloudflare resources.

Native binaries are installed by the checksum-verified installer and are ignored
by Git. No production credentials are included. Persistent sign-in needs a working
OS credential store; Discord voice and microphone behavior require live desktop testing.

## Next step

Deploy the accounts Worker and assign the actual Godot main-menu/gameplay scene to
the login gate. Connect the supplied matchmaking helpers to the authoritative
coordinator when its source is available.

## Get the repository

Clone the repository from GitHub:

```sh
git clone https://github.com/perdoobie-glitch/Ancient-Nest.git
cd Ancient-Nest
```
