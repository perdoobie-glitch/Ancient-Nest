# Ancient Nest Discord sign-in and team voice

Version **10.4-discord** replaces the player password/email/phone signup with **Continue with Discord**. The game uses the Discord Social SDK to authorize through the running desktop client where supported, with the SDK's browser fallback. First-time consent or reauthorization can require approval; this cannot silently authorize a player without consent.

Discord is the identity provider. The existing Worker and D1 are kept as a small game-profile/session/voice bridge: a verified Discord ID maps to one stable game ID and a unique, editable game username. There is no new game password, email signup, SMS signup, Resend requirement, or Twilio requirement. JWT/coordinator credentials remain server-only. Authentication does not prove game ownership.

## Player flow

1. Click **Continue with Discord** and approve if prompted. No second voice authorization is required after a successful initial sign-in.
2. The bridge exchanges the authorization code with PKCE and fetches the actual Discord identity. Client-supplied IDs are never accepted as proof.
3. A previously Discord-linked profile keeps its game ID and username. A new identity gets a unique default username; use **Save game username** on the signed-in screen or the integrated game's account panel to change it. Profiles are never merged by a matching username/email.
4. Saved game sessions use the OS credential store and rotating, hashed server-side refresh tokens. On next startup, successful restoration continues automatically. Any startup restoration failure clears the saved game login and requires Discord sign-in again. Temporary background outages retain the working saved session.
5. The existing team-room voice controls remain. Voice membership is server-owned. Desktop friends-call coexistence still requires a live two-person Windows test.

## Deploy the update

Use [the Cloudflare copy/paste prompt](cloudflare-paste/PASTE-INTO-CLOUDFLARE-ASSISTANT.txt), or run `Setup Ancient Nest.cmd` from the full source download. Existing Worker name and D1 ID remain so matchmaking can continue using the same profile bridge. Do not delete the database or the matchmaking Worker.

For an already deployed project:

```sh
npm ci --ignore-scripts
npm run db:remote
npx wrangler deploy
```

Migration **0005_discord_sign_in.sql** preserves profiles and history, adds the identity-provider marker, and revokes existing device sessions once so players must prove Discord identity after the switch. Unlinked legacy profiles are retained but cannot be recovered by typing their old username. Manually linking/migrating an unlinked historical account requires proof of ownership; this release does not guess identity mappings.

Set `AUTH_MODE=discord` (the default). `/register`, `/login`, password changes, email/SMS verification, old Discord linking and the old delivery-test page return `410 use_discord_sign_in`. Legacy implementations remain only for compatibility regression tests and intentional rollback using `AUTH_MODE=legacy`; the shipped UI has no password/email/phone fields. Existing email/phone data and unused provider secrets are preserved; no destructive cleanup is performed.

Required secrets: `JWT_SECRET`, `COORDINATOR_API_KEY` matching matchmaking, `DISCORD_CLIENT_SECRET`; team voice also needs `DISCORD_BOT_TOKEN`. Public Discord application ID: `1562796619722793010`. Email/SMS providers are not used in Discord mode. Configure Discord Social SDK support/redirects for the application as required by Discord's portal. Check `/health`, `/ready`, `/auth/discord/config`, and `/discord/ready` after deploying. A ready flag does not prove live Discord consent or microphone audio.

## Existing game and downloads

The connected repository contains the login/voice starter and a guarded adapter, **not the finished 10.2 game source**. The complete 10.2 archive was located in connected Drive, but its download host is blocked in this environment. The smaller 8.0 and 9.0 archives are references only. Other chats and files existing only on your PC are not automatically synchronized here.

`Connect Existing Game.cmd` installs the adapter into a compatible local source folder, backing up changed files and preserving original gameplay/assets/startup. It refuses unknown account interfaces. The actual 10.2 game must be inspected and integrated before calling the result a full-game release. Do not replace it with a new arena or downgrade to the reference game.

The Windows workflow builds a downloadable **Ancient-Nest-Windows** Actions artifact. This is the Discord login/voice starter until the actual game is connected. CI validates native loading, credential storage, export and executable startup; it does not test a real Discord user's authorization or microphone. Run `Test Discord Voice.cmd` with two signed-in Windows clients to create an owner-managed temporary room.

## Validation

`npm test` tests the Worker against local D1 and mocked Discord/provider endpoints, including Discord-only signup, stable profile mapping, username ownership/conflicts, bans and invalid grants, persistent sessions and existing security regressions. `npm run test:godot` checks native SDK loading and the real startup UI/session behavior using local fixtures. `npm run build:dashboard` regenerates the bundled Worker and fresh-database SQL. Live Cloudflare deployment and Discord account consent require credentials/access not configured in this workspace.
