# Discord team voice setup

The project contains a Discord Social SDK integration for Godot 4.4+ on Windows
and Linux x86_64. It uses the player's existing Discord account, leaves the desktop
Discord application alone, and joins a server-assigned team lobby inside the game.
The configured Discord Application ID is **1562796619722793010**.
Manage it in the [Developer Portal](https://discord.com/developers/applications/1562796619722793010/information).
The actual game and matchmaking sources are not present, so the supplied Godot
starter and coordinator helper still need to be connected to those projects.

## Cost and account ownership

Discord states that its [Social SDK](https://discord.com/developers/social-sdk) is
available at no cost, with full communication features subject to access criteria
and approval. This does not cover your Cloudflare Workers/D1 hosting, launcher
distribution, domain, or storefront costs. No Nitro subscription is needed to use
the developer SDK.

A regular Discord account owns a developer application; there is no separate paid
developer account to purchase. The owner has created the configured application.
This workspace has no Discord sign-in/browser connection or live Discord/Cloudflare
credentials, so portal changes, communication approval, and remote deployment still
require the owner's authenticated setup.

## Configure your existing application

1. Sign in to the [Discord Developer Portal](https://discord.com/developers/applications)
   with the account that should own the game. If you want a separate studio login,
   create and verify that regular Discord account first through Discord's sign-up flow.
2. Open the existing **Ancient Nest** application (`1562796619722793010`).
   There is no need to create another application.
3. Copy the **Application ID** from General Information. This is public configuration,
   not a secret. Do not confuse it with the Public Key, Client Secret, or bot token.
4. In OAuth2 settings, add exactly `http://127.0.0.1/callback` as a redirect URI.
   Also add the browser-link callback
   `https://ancient-nest-accounts.ancientnest-llc.workers.dev/auth/discord/callback`.
   Keep the app a **confidential client** (Public Client disabled): this integration
   exchanges authorization codes on the accounts Worker, not in the game.
5. Obtain the OAuth2 Client Secret and the application's bot token in their respective
   portal settings. The bot token authorizes server-managed lobby operations; players
   do not have to join a Discord guild or invite the bot into a server for this design.
6. Enable/configure Social SDK access and follow the portal's process for communication
   permissions. Development access is not a promise of unrestricted public voice access.
   Configure any required app metadata, support links, privacy policy, and terms for
   your actual studio; this project does not invent or publish those details.

Portal layout and approval requirements can change; Discord's
[getting-started documentation](https://docs.discord.com/developers/discord-social-sdk/getting-started)
and [voice guide](https://docs.discord.com/developers/discord-social-sdk/development-guides/managing-voice-chat)
are the reference. Keep secrets out of chat, source control, the Godot project, and
launcher arguments.

## Configure the accounts Worker

`wrangler.toml` already sets `DISCORD_CLIENT_ID` to `1562796619722793010`.
For a different application, replace that public ID.
Then, from the accounts project on an authenticated Cloudflare machine:

```sh
npx wrangler secret put DISCORD_CLIENT_SECRET
npx wrangler secret put DISCORD_BOT_TOKEN
npm run db:remote
npm run deploy
```

Enter the corresponding portal secrets at Wrangler's prompts. Existing JWT_SECRET
and COORDINATOR_API_KEY remain required. All four migrations must be applied.
For local development, add these Discord values to the ignored `.dev.vars` file
instead of committing them.

Check `/ready` for the base account API, and `/discord/ready` for Discord configuration
and tables. `/discord/ready` reports booleans only. It verifies local configuration,
not upstream secret validity, access approval, or microphone/audio connectivity.
`GET /discord/config` exposes only readiness and the public application ID for the game.
The exchange endpoint accepts only HTTP loopback callbacks at `127.0.0.1/callback`,
with an optional SDK-selected port; other hosts, paths, userinfo, queries, and fragments
are rejected. The SDK-provided URI is forwarded unchanged in the token exchange.

## Godot setup

The downloadable project package includes the pinned native desktop dependencies.
When using the source repository, run:

```sh
npm run discord:install
```

This installs, with SHA-256 verification:

- [thiagola92/discord-social-sdk](https://github.com/thiagola92/discord-social-sdk),
  release 5.0.0, including its Windows/Linux x86_64 SDK runtimes.
- [shomykohai/godot-keyring](https://github.com/shomykohai/godot-keyring), release 1.0.0,
  for OS-user-scoped credential storage. Linux needs libsecret and a running Secret Service.

The installer disables native editor hot reload in the two extension manifests.
Close Godot before installing/updating native dependencies. Upstream marks this Discord
binding release experimental; validate on the exact engine, OS, and hardware you ship.
The binding and keyring licenses are included with the dependencies; Discord's SDK
is governed by [Discord's developer terms](https://support-dev.discord.com/hc/en-us/articles/8562894815383-Discord-Developer-Terms-of-Service),
and its third-party notices are installed as `SDK-License-Notices.txt`.

Copy these folders into the actual Godot project:

```text
addons/ancient_nest/
addons/discord_social_sdk/
addons/keyring/
```

Register `auth.gd` as **AncientNestAuth** and `discord_voice.gd` as
**AncientNestDiscordVoice** in Globals → Autoload. Register `verification_panel.gd`
as **AncientNestVerification** for the required email/phone code-entry UI. Set `ancient_nest/account_api` to
the deployed accounts HTTPS origin. Use the supplied account gate as the startup
scene and assign your actual game/main-menu destination as described in the
[Godot client README](../godot-client/README.md).

After game sign-in, a **Connect Discord** panel appears. The SDK handles authorization
state and a PKCE challenge; the server exchanges the code for tokens and verifies the
Discord identity before linking it to the game account. One Discord identity can be
linked to one game account. Players authorize their own accounts; no shared studio
Discord account is used for player audio.

Only the Discord refresh token is saved in the OS credential store, under a separate
entry per Ancient Nest account. Access tokens remain in memory. The server stores
Discord IDs, not Discord passwords or OAuth tokens. If secure storage is unavailable
or locked, the client reports that the connection could not be saved; it has no plaintext
fallback. A missing/revoked Discord grant prompts a reconnect without signing out of
the game account. Discord token rotation or a lost refresh response can require
reconnecting Discord.

## Matchmaking hook

Use [examples/matchmaking-discord-bridge.js](../examples/matchmaking-discord-bridge.js)
from the authoritative coordinator when a final match roster has been selected:

```js
await createTeamVoice(env, {
  matchId: match.id,
  teams: [
    { id: 'red', playerIds: redTeamAccountIds },
    { id: 'blue', playerIds: blueTeamAccountIds },
  ],
  expiresAt: Math.floor(Date.now() / 1000) + 2 * 60 * 60,
});
```

The helper calls `POST /internal/voice/matches` with COORDINATOR_API_KEY. The accounts
service looks up verified Discord IDs and creates a different Discord server-managed
lobby for each team. Only the specified teammates are members. Never accept a
client-supplied roster or Discord user ID as authoritative.

Each team can contain 1–25 players; the API permits up to eight teams and 100 total
players, subject to the 4 KiB JSON request limit. Match IDs and team IDs use 1–64
ASCII letters, digits, underscores, or hyphens. Leases last at most six hours. All
players must already have linked Discord. A user can have only one active/pending
voice assignment. Identical roster, ID, and expiry retries return the existing rooms;
conflicting requests return 409. Do not reuse match IDs for separate matches.

The Godot autoload polls `/voice/session` every five seconds while connected and
auto-join is enabled. It accepts only the authenticated user's server assignment,
waits for Discord membership propagation, and starts that lobby's call. It never
uses public room secrets or a client-selected team. For a lower-latency trigger, call
`AncientNestDiscordVoice._poll()` from a trusted existing match-start event as well.

At match end or cancellation, call:

```js
await endTeamVoice(env, match.id);
```

This deletes the Discord lobbies and clears assignments. Cleanup failure leaves a
`deleting` record, stops new assignments immediately, and retries on the once-per-minute
scheduled job. Expired or abandoned creations are also cleaned. Client calls stop
when their last issued lease expires even if the accounts service is temporarily
unreachable. The scheduler is a cleanup backstop, so call the end hook on normal
match completion and don't rely solely on lease expiry. Upstream lobby idle expiry
can also end an unused room; a failed/lost create response may leave an untracked
idle lobby, which Discord's idle timeout must reclaim.

For team changes or replacements, end the old match's voice rooms and create a new
assignment with a new match ID; dynamic roster updates are not implemented.

## Voice behavior and personal Discord

The game defaults to push-to-talk, bound to **V** through `team_voice_ptt`. Rebind that
input action in the actual game if V already has a gameplay use. The panel has team
mute, team deafen, voice-activity mode, and automatic team joining controls. Losing
window focus releases team push-to-talk. These settings act on the game's Call
object, not global Discord mute or deafen. Leaving a match ends only its team call.
The game does not move a player between guild channels or log them out of the
desktop Discord application.

Discord [documents simultaneous SDK calls](https://docs.discord.com/developers/discord-social-sdk/development-guides/managing-voice-chat).
This is not a verified guarantee that every target system can run a separate desktop
friends call and this SDK call simultaneously. That exact behavior, microphone sharing,
audio-device selection, and approval status still require the live test below.
Use a different push-to-talk key in the desktop client to avoid broadcasting to both
groups unintentionally. Respect the OS microphone permission prompt.

## API additions

| Method | Endpoint | Authorization | Purpose |
| --- | --- | --- | --- |
| GET | `/discord/config` | None | Public app ID and configuration readiness |
| GET | `/discord/ready` | None | Configuration/schema checks |
| GET | `/discord/status` | Game bearer token | Linked identity status |
| POST | `/discord/exchange` | Game bearer token | `{ code, code_verifier, redirect_uri }` → OAuth tokens |
| POST | `/discord/refresh` | Game bearer token | `{ refresh_token }` → renewed Discord OAuth tokens |
| POST | `/discord/unlink` | Game bearer token | Remove game link outside an assigned match |
| GET | `/voice/session` | Game bearer token | This player's assigned room, or `{ assigned: false }` |
| POST | `/internal/voice/matches` | Coordinator key | `{ match_id, expires_at, teams: [{ team_id, player_ids }] }` |
| DELETE | `/internal/voice/matches/:id` | Coordinator key | End all team rooms for the match |

Unlinking removes the game's association; it does not revoke the Discord Authorized
App permission or delete the Discord account. Players can revoke permissions in
Discord settings. Discord OAuth operations are limited to 20 per game account per
15-minute window. Upstream rate limits surface as temporary service errors with
Retry-After. No SDK access tokens, secrets, or authorization codes are logged.

## Validation and the remaining live test

```sh
npm test
npm run test:godot
npm run check
```

Backend tests use an isolated Discord HTTP stub and local D1: real Discord credentials
are not exercised. The Godot test loads the real native SDK, exercises PKCE helpers,
checks communication scopes, and verifies per-team controls and teardown using a
call test double. Authentication/persistence tests use a credential-store test double;
the native keyring API is loaded but not round-trip tested on a desktop keyring here.
The smoke runner allows 90 editor frames for initial native imports before quitting.
An immediate `--import --quit` aborted on first scan with Godot 4.6 in this environment;
the delayed import passed from a fresh cache, as did the actual runtime SDK tests.

Before shipping, use two linked Discord accounts on two actual game clients to check:
both same-team players hear each other; another team cannot hear them; PTT/mute/deafen
affect only team voice; reconnect and game relaunch restore access; match end removes
the call; revoked grants recover; and a separate personal Discord friends call behaves
as intended on each supported OS. The workspace cannot perform this live test without
the Discord application/approval, deployed services, and real game/matchmaking code.
