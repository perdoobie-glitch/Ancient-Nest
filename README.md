# Ancient Nest — unified development source

**Campaign terrain and story update, 2026-10-26:** levels 2–9 now include 62 randomized weapon cases, substantial elevation changes, staged encounters along the route, destination defenses, and 15-second opening/ending scenes. Level 2 adds 966 collision trees, branch jumps and mounted crouching to the four-bike escape. Open **Play Expanded Campaign.cmd**, then **Mission Select / Play Levels 2–9**, or continue from Mission 1. [Current design and verification](docs/CAMPAIGN_TERRAIN_STORY_AND_CACHES.md) · [Initial nine-mission expansion](docs/CAMPAIGN_NINE_MISSIONS.md).

Working folder: `C:\Users\Corey\Games\AncientNest-Campaign-2-9-20261026`. Base is the exact City-Ambush source `59f005c3dcf3caed2f938c9d44098776c426d7e4`. The original City-Ambush build and checkout remain intact. New progress uses `campaign/nine_missions.json`; an existing Mission 1 checkpoint is read only for initial migration and is preserved. All co-op peers need `campaign-6-relief-caches`. The current private export is under `builds/windows-relief`; the previous export remains under `builds/windows`.

Previous City-Ambush update: eight-round Naki pistol, richer city/army departure base, forest trail props and concealed Annu ambushes. [Historical details and local checks](docs/CAMPAIGN_CITY_AND_AMBUSH.md). Preserved build: `C:\Users\Corey\Games\AncientNest-City-Ambush-20261025`.

The earlier route update expands the base and landing pad, builds a larger single-route maze with climbing gardens and staged encounters, and adds physical bot weapon pickups. Floating labels are smaller; plasma carbine shots travel twice as fast. See [that expansion and its checks](docs/CAMPAIGN_EXPANSION_AND_LOOT.md).

The earlier forest update adds the checkpoint campaign, curved expedition ship, plasma weapon racks, contact momentum, visible lobby map selection, Forge rendering and concluded Film previews/playback. Matchmaking includes account-timing and reconnect fixes; live coordinator connectivity remains unverified. See [that implementation and its checks](docs/CAMPAIGN_FOREST_AND_GAMEPLAY_FIXES.md).

**10.5-dev**, protocol **10.5-discord2**. Displayed game name: Ancient Nest. Project identity: AncientNest-Reforged-2026-10-23.

One playable Godot game now combines the recovered full 10.2 game/maps with the current Discord account system. The coordinator, account-backed playlist rankings, service cards and team-voice lifecycle are integrated in this source. This is a development integration, not a certified public release.

Current source adds host-only master scheduling, queue recovery, bounded retries, authority continuity and individual film perspectives. Communication defaults are centralized in [network_defaults.json](game/data/network_defaults.json). See [validation and measurements](VALIDATION.md#master-traffic-and-individual-films-source-only-2026-10-25) and [the current Windows handoff](PC_CODEX_HANDOFF.md#8-current-source-handoff-networking-master-traffic-and-films-2026-10-25) for tests, remaining WAN requirements and future rollout/rollback instructions. Production was not deployed for this work.

| Folder | Purpose |
| --- | --- |
| game | Canonical playable game, six maps, weapons, bots, objectives and player-host networking |
| matchmaking | Cloudflare Durable Object coordinator; five playlists, voting, host selection, admission and results |
| ancient-nest-accounts | Discord identity, persistent sessions, playlist rankings and server-owned team voice |
| monitor | Godot master-service monitor |
| website | Existing browser menu preview, not the authentication backend |
| scripts | Shared local setup and native two-client transport test |

## Start on Windows

Campaign entry: run **Play Ancient Nest Campaign.cmd**, choose **Campaign • Play
offline** after the age notice or enter Campaign from the main menu. Choose
**Difficulty** (Easy, Medium, Hard, Angel), then New Campaign. Mission 1 includes
the 15-second Connectuct intro, personal preparation, boarding, forest crash,
charge recovery, five Annu waves and radio ending, with solo saves and direct
1–4 player co-op. Environment art is a functional blockout; recorded narration
is missing and uses subtitles/replaceable slots. See
[Mission 1 and Windows/co-op handoff](docs/CAMPAIGN_MISSION1.md) for setup,
controls, actual tests and limits. Historical multiplayer modes remain available.
The newest [guided introduction](docs/CAMPAIGN_GUIDANCE.md) adds clear controls,
waypoints, cabin boarding and a damaged-atmosphere sky. It supports recordings
and local system-speech fallback; recorded actor assets remain unavailable.
The subsequent [landscape pass](docs/CAMPAIGN_LANDSCAPE.md) adds mountains,
freight structures, ruins, varied foliage and cabin detail with traversal tests.

Install Git, Node.js 24 LTS, Python 3.11+ and Godot 4.6.3 (matching export templates if building). Ensure `node`, `npm`, `python` and `godot` work in CMD. Read [the PC handoff](PC_CODEX_HANDOFF.md), then run **Setup Ancient Nest.cmd** and **Play Ancient Nest.cmd**. The launch script now opens the full game. Native Discord/keyring downloads are pinned and checksum-verified; WebRTC runtime dependencies are included.

The account service's `godot-client` folder is a native/auth test fixture. It is not the game launcher. The old adapter-only root launcher and duplicate historical trees have been removed from the working tree. Recovery history remains intact.

## Publisher age policy
The Windows game starts with **MATURE AUDIENCES — 18+** before Discord sign-in, saved-session restoration, and the studio/menu sequence. This is a publisher-designated restriction, **not an official ESRB or PEGI rating**. The notice discloses violence, blood effects, and online player communication. No rating-authority logo is used.

First-time players affirm they are at least 18. After successful sign-in, the client remembers a local declaration and policy version in its isolated user-data folder; later launches skip that prompt. Existing saved sign-ins from the earlier age-gated client are validated once to carry the declaration forward. Invalid saved logins, declined declarations and incompatible policy records do not silently grant eligibility. Declining keeps sign-in/gameplay unavailable for that process. No birth date, Discord ID or account identity is stored in the age preference. This is self-declaration, not independently verified age assurance, and can be bypassed by a modified client. It is not evidence that a rating authority or Discord approved the game. Formal rating, platform/compliance review, and live release checks remain required as applicable.

Check: `godot --headless --path game --script res://tests/age_policy.gd` verifies pre-confirmation account/SDK/credential blocking, declining, and the adult transition into sign-in using a fake credential store.

## Game names and Discord invitations
New Discord players choose a unique game username (3–24 ASCII letters, digits, `_` or `-`) before entering the game. Previously chosen names stay attached to their existing profile. Public game profiles contain no Discord name or Discord ID. Names can be changed through the player/account panel; matchmaking, chat and scoreboard use the game name. Discord remains the private authentication provider, and native Discord invitations naturally use the sender's Discord account in Discord itself.

Open **Play**, create a party, select a playlist with room for teammates (2v2 or larger), then **Invite** to choose a Discord friend. Invites use Discord Social SDK Rich Presence and the existing server-validated party code. Copy party code / Join Party remains available. Full parties, active searches and matches do not advertise a join secret. Clicking Join in Discord or Accept in the dashboard joins directly, replacing the current idle party without another confirmation. It never interrupts an active match or ranked search. Blocked/non-friend relationships are excluded from the picker. No invitations are sent automatically.

The SDK registers this installation's launch command after age confirmation and account sign-in. A recipient must have launched their installation successfully at least once. Cold-launch invite callbacks have a provider timeout, so a lengthy first login may require a fresh invitation. Actual friend delivery, acceptance, native cold launch, and cross-internet play require live tests with two different accounts/PCs; local mocks do not certify them.

Account username selection uses the existing `users.metadata` object, preserving other metadata; no new database migration is required. Deploy the matching account-service source before relying on the new server-side username prerequisite. Development checks include `game/tests/game_username_onboarding.gd`, `game/tests/discord_invites.gd`, and the account-service tests.
## Server setup

Do not deploy until you inspect existing Cloudflare bindings and preserve credentials. Accounts need JWT_SECRET, shared COORDINATOR_API_KEY, DISCORD_CLIENT_SECRET and DISCORD_BOT_TOKEN. Matchmaking needs the same coordinator key, ACCOUNT_API, TURN credentials and MONITOR_TOKEN. Production guest mode stays disabled.

From ancient-nest-accounts: `npm ci --ignore-scripts`, `npm test`, `npx wrangler login`, `npm run db:remote`, `npm run deploy`. Remote migration now stops unless a database export and SHA-256 were created first. Review the configured DB ID before running it. Existing historical Steam-account data is not automatically mapped to Discord users; identity proof and a reviewed migration are required.

From matchmaking: `npm ci`, `npm run typecheck`, `npm run build`, `npm test`, then `npx wrangler deploy`. Game and coordinator must both use **10.5-discord2**. Preserve Durable Object migration history and existing Worker names. There is no dedicated simulation server: the elected player's PC runs the match.

## Checks

Tests that write preferences must use isolated profiles. Run
`node scripts/campaign-validation.mjs` (or pass fixture names) rather than running
the age-policy or controls-migration scripts directly against live user data.
- Accounts: `npm --prefix ancient-nest-accounts test`
- Coordinator: `npm --prefix matchmaking run build` then `npm --prefix matchmaking test`
- Native account/SDK fixture: run `npm run test:godot` inside ancient-nest-accounts.
- Two local native clients: `python scripts/native-smoke.py` (uses loopback-only guest fixtures, not production credentials).
- Full-game account UI: `godot --headless --path game --script res://tests/unified_account.gd`
- Monitor: `godot --path monitor`

See [VALIDATION.md](VALIDATION.md) for actual results and limits. Do not claim local mocks prove live Discord or WAN matchmaking. Windows workflow now tests/builds without publishing downloads or releases. No executable was published for this integration.

Recovery baseline: [fe249599](https://github.com/perdoobie-glitch/Ancient-Nest/tree/fe249599b46a5bcc25edaf91bf856bc200b64b11). The separate earlier Reforged commit 0156a0d... remains unavailable; this source integrates the recoverable full game rather than pretending that commit was recovered.

## In-game Discord dashboard (Windows client update)
Settings → Discord contains online friends, friend search, explicit game invitations and game voice controls. Main-menu and matchmaking shortcut buttons open this page. Invisible friends appear offline; only Discord SDK-authorized friend data is shown. Invitations require a connected, joinable party with space, and no invitation is sent automatically. The old floating voice panel stays hidden.

Matchmaking Search/Cancel Search and navigation remain pinned outside the scrolling player-card area. A disconnected master shows Reconnect; Search becomes available after the party connection is ready.

`game/tests/discord_dashboard_layout.gd` checks pinned actions at 1920×1080, 1280×720, 960×540 and 640×480, mock friend presence/filtering and settings navigation. These checks do not establish real friend delivery, two-player audio or WAN matchmaking.

### Global Discord shortcut and lobby controls
Press **I** to toggle the persistent Discord dashboard from game screens; **Esc** closes it. The main menu shows a bottom **[I] Discord dashboard** button. Letter I remains usable while typing in text fields. The panel preserves the current screen and match; online simulation continues while gameplay/editor input is blocked. Age confirmation and Discord authentication remain user actions.

The dashboard controls the master matchmaking party lobby. Connect a lobby and choose a team playlist with space. Its leader can choose **Open** or **Private** while not searching. Open lobbies automatically reply to Discord friends' join requests. Private lobbies require a member's invitation or approval. **Join game** asks a friend currently playing this Discord application to join; accept the returned invitation under **Invitations & join requests**. Accepting replaces your current idle party directly without an extra confirmation. Active matches/searches cannot be interrupted to join another lobby.

Server-side private admission requires a 128-bit-format random invitation capability (UUID with 122 random bits), sent only in authenticated party-member state and through Discord's invitation flow. Party codes alone cannot join private lobbies. Privacy changes and member departures rotate the capability. This is a transferable invitation, not a recipient-bound credential; anyone a member shares a valid invitation with may use it until rotated. Keep party state and invite payloads out of public logs. Existing parties default to Open for compatibility. No Discord IDs are added to public game profiles.

Deploy the matching coordinator before testing privacy. Until it advertises `lobby_privacy_supported`, the privacy selector stays disabled. Existing Workers, namespaces and secrets are preserved; no D1 migration is needed. Updated invitation payloads require updated game clients. Two real Discord accounts are still required to certify provider delivery, acceptance and audio; two PCs on separate internet connections are required for WAN play.

## Movement, weapon controls and Sanctuary rendering
Default direct weapon controls are **1: Primary weapon**, **2: Secondary weapon**, **3: Melee weapon** under Settings → Controls. Naki draws its equipped Nexus Blade; Annu uses its existing knife attack. Quick melee remains F. Cycle weapon defaults to C (mouse wheel also cycles). Older default cycle-on-1 bindings migrate to a free key without replacing a custom C binding; custom cycle bindings are retained. Missing/invalid inventory slots do nothing, and the host validates direct selection.

Airborne movement stops first-person running bob and procedural stride immediately, selecting the existing airborne animation. Downward acceleration is 10% stronger; the ascending acceleration, launch impulse, jump apex and existing terminal-speed cap are retained. Upward external impulses keep the ascending acceleration until total vertical motion turns downward. Hosts and all clients must run the updated movement code for prediction/replay parity.

Sanctuary's fixed architecture uses 24-unit horizontal batching cells, retaining the existing vertical separation, materials, geometry and collisions. Other maps retain their existing cells. The measured map changed from 466 to 342 static batches with 79,956 triangles and 1,837 static collision bodies in both runs. Wider cells reduce render submissions but make culling less granular; actual frame rates depend on viewpoint and hardware. No geometry, routes or gameplay objects were removed.
