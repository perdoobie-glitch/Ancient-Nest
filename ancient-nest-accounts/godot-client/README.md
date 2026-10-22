# Godot first-launch accounts

A Godot 4.4+ starter (validated with Godot 4.6.3) for Ancient Nest's accounts API.
Open `project.godot` to try the account screen, or copy `addons/ancient_nest` into
the existing game. The game's source was not supplied, so its actual startup scene
has not been edited.

## Windows player download

The exported Windows x86_64 folder opens with **Ancient Nest.exe**; players do not
need to install Godot. Extract all files and keep the runtime DLLs beside the app.
The default HTTPS account origin is already configured. Owner setup and deployment
are required before live sign-in can succeed. This export is the account/voice
starter and does not contain gameplay. Build it with `npm run build:windows` from
the accounts directory after installing Godot 4.6.3 export templates and native addons.
The Windows binary is built and inspected on Linux; live Windows testing remains.

## Add to the game

1. Deploy the updated accounts Worker after applying all D1 migrations.
2. Copy `addons/ancient_nest` into the Godot project.
3. In Project Settings → Globals → Autoload, register
   `res://addons/ancient_nest/auth.gd` as **AncientNestAuth**.
4. Add a String project setting `ancient_nest/account_api` with the accounts Worker's
   HTTPS origin. The starter's `project.godot` shows the format. No server secrets
   belong in the game.
5. Install the native dependencies described below to enable persistent login and Discord voice.
6. Set `addons/ancient_nest/login.tscn` as the startup scene. To set its destination,
   create an inherited scene, assign **Game Scene** in the Inspector to the actual
   main menu/game scene, and use that inherited scene as the startup scene.

On first launch the screen offers **Create account**, with **Already have an account?
Sign in** for returning players on another device. An email address, a phone number with country code, and password confirmation are
required for registration. Register `verification_panel.gd` as **AncientNestVerification**
to show code entry and resend controls for both contacts. A successful registration also signs in immediately. On later
launches the autoload attempts to restore the saved session. Success skips account
entry; failure shows **Sign in** and prevents entry to the game. Access
refreshes automatically while running, and the game can call `get_access_token()`
before authenticated requests. The screen never proceeds into Game Scene after
a failed authentication request.

The standalone starter displays a signed-in status and Sign out button if no Game
Scene is assigned. Your game's main menu can call `await AncientNestAuth.sign_out()`
and return to the login scene after an `ok` result. Listen for `session_lost` to return
to that screen if the backend rejects a saved session. Never permit a multiplayer
connection simply because local UI says a player is signed in; the coordinator must
verify the access token and team membership.

## Persistent storage dependency

The project ZIP includes [Godot Keyring](https://github.com/shomykohai/godot-keyring), which exposes
the native `Keyring` class used by `credential_store.gd`. The adapter was checked
against its API and the bundled release 1.0.0 native class was loaded in Godot.
When using the source repository, run `npm run discord:install` from the accounts
directory to install pinned, checksum-verified Windows/Linux x86_64 binaries for
both Keyring and Discord Social SDK. Copy `addons/keyring` into the actual game
alongside `addons/ancient_nest`. The desktop credential-store round trip still
needs testing on the actual OS/keyring service.

If building the dependency yourself, follow its instructions with SCons and its `godot-cpp` submodule, and copy
the built `demo/addons/keyring` folder into your game's `addons/keyring`. Build and
ship the appropriate `template_debug` and `template_release` binaries for each
target CPU/platform. The upstream configuration currently lists Windows and Linux;
Linux also needs libsecret and a running desktop Secret Service. The current upstream
build configuration disables macOS, so do not assume a macOS/iOS/Android/Web export
has secure storage: provide a platform-native adapter for those targets first.
Review and test the addon on the exact platforms you ship.

The adapter uses OS-user-scoped credential storage, storing only a refresh token.
Its fixed entry is identified by `net.ancientnest.game`, `accounts-refresh-token`,
and `current-os-user`. Use a different package/service entry for a separate launcher
so it does not rotate the game's saved token behind its back. Launcher-to-game SSO
would be a separate token exchange; do not pass refresh tokens in launch arguments.

Without the native addon, **Stay signed in on this device** is unavailable, and the
game explicitly offers a session-only login. There is no plaintext or hard-coded-key
file fallback. To meet the requirement that players stay signed in after restarting,
ship a working credential-store adapter with the game. The smoke test uses an
in-memory adapter and does not claim to test the OS keyring implementation.

## Calling the matchmaking API

```gdscript
var auth: Dictionary = await AncientNestAuth.get_access_token()
if not auth.ok:
    # Show a reconnect/sign-in prompt; do not enter an authenticated match.
    return
var headers := PackedStringArray(["Authorization: Bearer " + auth.token])
# Send headers using your matchmaking HTTP/WebSocket client's existing auth contract.
```

`get_access_token()` keeps tokens in memory and refreshes them if needed. Parallel
refresh callers share one in-flight request. Network failures retain saved sign-in;
during background refresh. On startup, any failed saved-session restoration clears
the local credential and shows **Sign in**, requiring successful manual login before
entering the game. A definitive 401 also ends an active session. Sign out waits for server
revocation; a network failure reports an error and allows retry instead of silently
claiming that the device was revoked.

An active device can stay signed in indefinitely as refresh renews the 90-day idle
expiry. A device unused for 90 days, a revoked device, or a fresh/reinstalled system
may need another sign-in. Passwords are never persisted. A refresh response lost
for more than the server's 60-second retry grace can also require signing in again.

## Verify

From the accounts project directory:

```sh
npm test
npm run test:godot
godot --headless --path godot-client --editor --quit-after 90
```

Set `GODOT_BIN` to the Godot executable if needed. Tests use a real local Worker
and D1 database without contacting a deployed account service. Local HTTP is allowed
only for localhost/127.0.0.1 in a debug build; exported release clients require HTTPS.
Allow the editor to finish its initial scan before quitting with native addons.
Godot 4.6's immediate `--import --quit` aborted on a first scan in this environment;
the delayed command above passed from a fresh project cache. The smoke runner uses
that command before testing.

Buying the game is separate from account creation. This screen runs on first launch;
purchase verification needs the eventual storefront or your launcher's entitlement
service. The starter does not implement a launcher or payments. For in-game Discord
voice, register `discord_voice.gd` as **AncientNestDiscordVoice**, copy the bundled
`addons/discord_social_sdk` folder, and follow the [Discord setup guide](../docs/DISCORD_SETUP.md).
