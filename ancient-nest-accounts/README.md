# Ancient Nest accounts and Godot sign-in

This Worker uses the exported 10.2 account service and its three database migrations
as the base. Version **10.3-accounts** adds persistent device sessions, safer
verification/OAuth handling, and Discord Social SDK team voice. **Email and phone
are both required when creating an account.**

The [Godot starter](godot-client/README.md) shows account creation on first launch,
then attempts saved sign-in automatically on later launches. Successful restoration
opens the game; any failed startup restoration clears the local saved sign-in and
shows **Sign in**. Players must authenticate successfully to continue. Passwords
are never saved. The ZIP includes the Windows/Linux x86_64 native dependencies.
The existing 10.2 source was located in connected Drive. Its download host is
currently blocked in this workspace. The smaller 8.0 game and 9.0 coordinator are
local references for the prepared adapter; they are not replacement releases. See
[existing-game integration status](docs/EXISTING_GAME_INTEGRATION.md).

## Cloudflare dashboard copy/paste

[Paste this prompt](cloudflare-paste/PASTE-INTO-CLOUDFLARE-ASSISTANT.txt) into your
Cloudflare assistant, or follow [the dashboard steps](cloudflare-paste/START-HERE.txt).
`cloudflare-paste/worker.js` is a self-contained ES-module Worker bundle. Fresh-database
SQL includes the current schema and migration history; it deliberately stops if
account tables already exist. Existing databases must use their pending migrations.
Rebuild these generated files after backend changes with `npm run build:dashboard`.

After deployment, open `/setup-test` to check readiness, receive and verify real
email/SMS codes, test session refresh, and link Discord. The page stores tokens only
in memory and does not contain provider credentials. It requires your real contact
information and working provider setup; mocked delivery tests are not live proof.

The Windows CI workflow tests the native SDK and a real OS credential-store round
trip, builds the Windows executable and starts it on a Windows runner. CI does not
prove microphone audio or a friends call: use `Test Discord Voice.cmd` with two
linked Windows clients for an owner-managed, 15-minute temporary team room.

## Existing Cloudflare configuration

`wrangler.toml` already binds `DB` to:

- Database: `ancientnestaccounts`
- ID: `a045391c-1896-4169-bd17-04140d1cbb27`
- Worker: `ancient-nest-accounts`
- Expected public origin: `https://ancient-nest-accounts.ancientnest-llc.workers.dev`
- Discord application: `1562796619722793010`

No live deployment or remote migration was performed in this workspace; Cloudflare
and Discord credentials are not configured here. Do not create another database.
Use the URL Wrangler prints after deployment; update `PUBLIC_URL` and the Godot
`ancient_nest/account_api` setting if it differs from the expected origin.

## Windows shortcuts and download

For the owner: extract the full download and double-click **Setup Ancient Nest.cmd**
at the repository root. On Windows 10/11 with Windows Package Manager, it installs
Node.js LTS if needed, installs locked dependencies, opens Cloudflare sign-in when
required, checks the existing database schema, applies migrations, and deploys the
Worker. It asks once for the Twilio sender, verified Resend sender, and any missing
provider secrets. Secrets are hidden during entry, passed to Wrangler through stdin,
and never saved to a local secret file. Existing Worker secrets are preserved;
the shared coordinator key must be supplied rather than replaced with a new value.
Use your existing Discord application and provider accounts before running setup.

The setup window reports success only after both readiness endpoints pass, including
all provider configuration flags. Readiness does not prove provider delivery or live
audio. A failed step stops the process and leaves a message in the window. Fix the
reported issue and open the shortcut again. The public sender configuration is
saved in local `wrangler.toml`; remote provider secrets stay in Cloudflare.

For players: extract **Ancient-Nest-Windows.zip** and open **Ancient Nest.exe**.
Keep the extracted DLLs beside it. Godot, Node.js, and terminal commands are not
needed on a player's PC. This is the account/voice client starter; it does not embed the existing full game. The service must be deployed before online accounts can work.
The Windows export is unsigned. Windows CI passed native loading, secure storage
and exported executable startup checks.
Interactive GPU/audio and the current full-game integration still need testing.

To reproduce the player build, install Godot 4.6.3 with its matching standard export
templates, run `npm run discord:install`, then `npm run build:windows` (Python 3
required for the build tools). This creates `dist/Ancient-Nest-Windows.zip` and a
SHA-256 checksum. The official export-template archive used for this build is
`Godot_v4.6.3-stable_export_templates.tpz`, SHA-256
`3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8`.
Build artifacts and native dependencies are ignored by Git; the full downloadable
package includes the compiled player folder.

## Install and deploy

Requires Node.js 22+ and access to the owning Cloudflare account.

```sh
npm ci
npx wrangler login
npm run db:list
npm run db:remote
npx wrangler secret put JWT_SECRET
npx wrangler secret put COORDINATOR_API_KEY
npx wrangler secret put RESEND_API_KEY
npx wrangler secret put TWILIO_ACCOUNT_SID
npx wrangler secret put TWILIO_AUTH_TOKEN
npx wrangler secret put DISCORD_CLIENT_SECRET
npx wrangler secret put DISCORD_BOT_TOKEN
npm run deploy
```

Set `TWILIO_FROM` in `wrangler.toml` to your SMS-capable Twilio number in E.164 format.
Verify `ancientnest.net` with Resend before using `EMAIL_FROM=noreply@ancientnest.net`;
use a sender/domain you control. Twilio destination restrictions and regional SMS
registration must also be satisfied. Provider accounts and messaging usage may cost
money. Without configured providers, account creation succeeds but returns
`send_errors` and email/phone cannot be verified until delivery is configured.

Use an independent random JWT secret of at least 32 bytes and the existing
matchmaking Worker's `COORDINATOR_API_KEY` (also at least 32 bytes). Enter secrets at
Wrangler prompts; do not paste them into chat or put them in the game. The Discord
Application ID is public configuration and is already in `wrangler.toml`.

For Discord, retain `http://127.0.0.1/callback` for native SDK authorization and add
`https://ancient-nest-accounts.ancientnest-llc.workers.dev/auth/discord/callback` for
browser account linking. Keep the application a confidential client. See the
[Discord setup and live voice checklist](docs/DISCORD_SETUP.md) for permissions,
SDK setup, team-room hooks, and desktop friends-call testing.

```sh
curl https://ancient-nest-accounts.ancientnest-llc.workers.dev/ready
curl https://ancient-nest-accounts.ancientnest-llc.workers.dev/discord/ready
```

`/ready` requires base secrets and migrated account tables; it also reports email,
SMS, and Discord configuration flags. `/discord/ready` checks Discord configuration
and tables. These checks do not validate upstream credentials or test audio.

## Migrations and existing accounts

| Migration | Purpose |
| --- | --- |
| `0001_create_users.sql` | Exported users and indexes |
| `0002_create_verification_codes.sql` | Exported email/phone challenges |
| `0003_create_sessions_login_attempts.sql` | Exported JWT sessions and login audit |
| `0004_persistent_sessions_and_voice.sql` | Refresh sessions, verification attempt limits, OAuth states, rate limits, team lobbies |

Apply all four migrations before deploying. The migration scripts inspect existing
columns first and refuse incompatible schemas without dropping data. Back up an
existing production D1 database before migration. If an earlier scaffold used
`username_key` or different session columns, stop and reconcile that schema; do not
rename migration files or reset production tables to bypass the check.

Existing exported 100,000-iteration PBKDF2 passwords remain valid and upgrade to
600,000 iterations on successful login. Existing exported HS256 JWTs remain valid
until expiry with the same JWT_SECRET and a matching, live, unrevoked D1 session.
Those players must sign in once to receive the new persistent device token.
Expired legacy verification codes expire normally; new codes are HMAC protected.
Existing mixed-case emails and phone formatting are retained; new registrations
normalize email case and E.164 phone formatting. No destructive normalization or
account merging is performed.

## API

All protected player routes use `Authorization: Bearer <game token>`. JSON bodies
require `Content-Type: application/json` and have a 4 KiB limit. Usernames allow
3–24 ASCII letters, digits, underscores, and hyphens; matching is case insensitive.
Passwords allow 8–128 characters. New registrations require a valid email and a
phone number including its country code.

| Method | Route | Input or purpose |
| --- | --- | --- |
| GET | `/signup/config` | Both contact fields are required |
| POST | `/register` | `{ username, password, email, phone }` → 201 session, verification flags, delivery errors if any |
| POST | `/login` | `{ username, password }` → session |
| POST | `/refresh` | `{ refresh_token }` → renewed session |
| GET | `/verify` | Validity, user, contact/Discord verification flags |
| GET | `/account` | Profile and verification status; phone partially masked |
| POST | `/verify/email`, `/verify/phone` | `{ code: "123456" }` |
| POST | `/verify/email/resend`, `/verify/phone/resend` | New challenge; invalidates previous one |
| POST | `/account/password` | `{ current_password, new_password }`; revokes every device session |
| GET | `/auth/discord` | Protected; returns browser authorization URL |
| GET | `/auth/discord/callback` | Public callback with one-use state and PKCE |
| POST | `/logout` | Bearer, or `{ refresh_token }` without Authorization; revokes this device |
| POST | `/internal/verify` | `X-Coordinator-Key` and `{ token }`; returns validity and verification flags |
| GET | `/health`, `/ready` | Liveness and readiness |

Session responses include `user`, `token`, `expires_at`, `refresh_token`,
`refresh_expires_at`, and `verification`. Access tokens last one hour by default;
`TOKEN_TTL_SECONDS` accepts 300–86400. Refresh tokens rotate on use and expire after
90 idle days. The immediately previous token can retry for 60 seconds and returns
the same successor. Tokens use Unix-second timestamps. Logging out revokes both
access and refresh tokens for that device; password changes revoke all devices.

The Godot client saves only refresh tokens in the OS credential store. Startup
restoration must succeed before entering the game. A failed startup attempt clears
local credentials and requires manual sign-in, including when the service is
unreachable. During an already-running session, temporary network/5xx/429 failures
retain credentials for retry; definitive 401 responses end the session. A failed
network logout reports an error so the player can retry server revocation.

Codes expire after 10 minutes with five guesses per challenge. Registration counts
toward the three-deliveries-per-contact, per-account, 15-minute limit. There is also
a shared 10-deliveries-per-IP limit. Authentication uses 30 requests/IP and
10/username per 15-minute window; device refresh/logout uses 120/IP. Counters are
atomic and HMAC-keyed. Login audit IPs are HMAC protected and deleted after seven
days. All responses disable caching; CORS accepts configured exact browser origins.
Errors use `{ error: "code" }` and never return raw upstream messages or SQL details.

## Game identity bridge

The existing game expects a key-bound account assertion. `POST /api/game/assertion`
accepts a game bearer token and RSA public key and issues a ten-minute assertion.
`POST /api/game/verify` verifies that assertion against the exact game-key hash,
D1 session and ban state. Assertions have a separate audience and cannot access
account endpoints. The integration installer backs up and edits only startup/account
plumbing; it does not rewrite gameplay. See the linked integration notes before
changing the current coordinator. Existing ranking/results routing must be preserved.

## Matchmaking and voice

Set the matchmaking `ACCOUNT_API` to the deployed origin and use
[the account bridge](examples/matchmaking-account-bridge.js) to verify each player's
access token remotely. Verify the existing coordinator's request contract before
switching it; its source was not supplied. Signature-only JWT validation cannot
observe logout or bans. Recheck long-lived connections at sensitive operations and
access-token expiry.

Verification flags preserve the exported service's behavior: registration requires
contact details, while an unverified account can still authenticate. `fully_verified`
means email, phone, and Discord are verified/linked. The coordinator must explicitly
require this flag if it should block matchmaking. The supplied verification panel
supports entering and resending codes; it does not impose a new admission rule.

The [voice bridge](examples/matchmaking-discord-bridge.js) creates a private
server-managed Discord lobby for each authoritative team roster and deletes it at
match end. The Godot SDK joins the assigned lobby, with push-to-talk on V and team
mute/deafen controls. It uses players' own Discord accounts. Desktop Discord is
left running; simultaneous friends-call audio still needs a live test on target
systems. Discord communication access/approval is also required.

## Local development and checks

Copy `.dev.vars.example` to ignored `.dev.vars` and replace its placeholders.

```sh
npm run db:local
npm run dev
# In another terminal:
npm test
npm run check
npm run test:godot
```

`check` bundles with Wrangler's deployment dry run. Tests use local workerd/D1 and
stub email, SMS, and Discord providers. Godot tests load the native SDK but use test
doubles for the OS keyring and live audio calls. The native keyring, microphone,
Discord approval, delivery providers, and two-client voice must be tested on actual
desktop systems before shipping. In a source checkout, install native dependencies
with `npm run discord:install`; the ZIP already includes pinned binaries/licenses.

Purchase validation, password recovery, a custom launcher, payments, and mobile/web
native adapters are not implemented. Account creation alone does not prove purchase.
