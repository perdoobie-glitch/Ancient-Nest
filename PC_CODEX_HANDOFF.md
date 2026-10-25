# Windows Codex handoff

## Identity and source
Repository: https://github.com/perdoobie-glitch/Ancient-Nest
Integration branch: integration/unified-2026-10-23 (promote to main only by fast-forward after checks).
Use the exact verified commit supplied in the accompanying cloud response; do not silently move to another branch or latest main. Record git rev-parse HEAD before changes.
Canonical directory: C:\Users\Corey\Games\AncientNest-Reforged-2026-10-23-Canonical
Display name: Ancient Nest. This is the integrated 10.5-dev source, not a certified public release.
Read AGENTS.md, RECOVERY_STATUS.md and VALIDATION.md first.

## 1. Cleanup preparation before setup
Inventory only Ancient Nest GAME project copies, installed game copies, relevant shortcuts and game save/settings directories. Include dirty Git changes, untracked source, unique maps/assets, and Godot userdata under %APPDATA%\Godot\app_userdata. Do not dump credentials into reports.
Before moving anything: confirm the replacement branch/commit is remotely available; download into a temporary staging directory, verify its commit and all entries in the recovery branch manifest when comparing historical files. Archive unique work/settings/saves with a filename/size/SHA-256 inventory; verify archive contents and perform a sample restore. Keep credential storage private and unchanged.
Only then move clearly obsolete, fully backed-up copies and their shortcuts to the Windows Recycle Bin. Use an available Windows Recycle Bin API or File Explorer, not permanent del/rmdir. Do not recycle the only Reforged copy or anything of uncertain provenance. Preserve business/unrelated files, recovery archives, credentials, cloud data and this staged replacement. If the missing Reforged work cannot be recovered, defer retirement of any possibly newer copies. After cleanup preparation, use the canonical checkout; do not overwrite an existing directory.

## 2. Recover the missing integration
Locate the original Reforged checkout or archive/bundle containing commit 0156a0d66bb1f850494e7d75a8d32fe4917ea7d2. If found, preserve uncommitted/untracked assets too. Inspect history and compare source/features with the complete 10.2 baseline and newer 10.4 accounts. Import it onto a new integration branch without force-pushing or replacing current remote history. If absent, report that transfer from the original session is required; do not invent it.
Canonical game: game/. Coordinator: matchmaking/. Accounts: ancient-nest-accounts/. Monitor: monitor/. Historical copies and hashes are preserved on the recovery branch. Read VALIDATION.md for the new integration tests and remaining live gates.

## 3. Tools and local checks (CMD)
Install Git for Windows, Node.js 24 LTS (accounts require >=22), Python 3.11+ and Godot 4.6.3 with matching export templates. Install Discord desktop. Wrangler must come from each project's package lock. Preserve native WebRTC DLLs alongside the eventual game export.

From canonical repository root:
```cmd
set "NODE_OPTIONS=--dns-result-order=ipv4first"
cd ancient-nest-accounts
npm ci --ignore-scripts
npm test
python scripts/install-discord-sdk.py
npm run test:godot
```
The SDK installer pins Discord binding 5.0.0 and keyring 1.0.0 with checksums. Run the real Windows credential-store roundtrip:
```cmd
godot --headless --path godot-client --script res://tests/keyring_smoke.gd
```
For the current integrated coordinator, open CMD in the canonical repository root:
```cmd
cd matchmaking
npm ci
npm run typecheck
npm run build
npm test
cd ..
```
Canonical game editor and launch, from the repository root:
```cmd
godot --editor --path game
godot --path game
```
Historical baseline paths belong to the preserved recovery branch, not this active checkout. See matchmaking/README.md for current coordinator checks and explicitly historical 10.2 notes.
Run Setup Ancient Nest.cmd for dependencies and native SDKs, then Play Ancient Nest.cmd for the canonical full game. Existing godot-client is a test fixture only. Export/build commands target the full game; publish nothing until release gates pass.

## 4. Reconcile contracts before deployment
The integrated game/coordinator use 10.5-discord1. Profile, per-playlist rankings, match-result persistence and review contracts are now implemented; verify them live. Custom games must not change ranking. Keep authoritative account IDs and server-validated results; never trust client-supplied rank/team identity.
Server-owned team voice is now connected through /internal/voice after match start. Verify its real provider behavior. Handle reconnect, departures, match end, cancellation, host failure and expiry; retries must be idempotent. Never embed bot/coordinator credentials in the game. Reuse examples/matchmaking-discord-bridge.js as a starting point, then test actual coordinator lifecycle.
Verify signed/key-bound assertions, host readiness, admission-ticket expiry/replay rejection, elected host identity, roster membership and transport compatibility. Do not enable guest mode to conceal authentication failures.

## 5. Cloudflare authentication, backup and deployment
Account ID: 95cd0db7b4086189f21e49dbeea65e26.
Accounts: https://ancient-nest-accounts.ancientnest-llc.workers.dev
Existing master: https://ancient-nest-matchmaking.ancientnest-llc.workers.dev
Existing game WSS: wss://ancient-nest-matchmaking.ancientnest-llc.workers.dev/v1/matchmaking

Run npx wrangler whoami; if unauthenticated, npx wrangler login and let Corey approve the browser. If network fails, diagnose DNS/proxy/TLS without disabling certificate checks. No temporary-preview deployment as a substitute.
Inspect deployed bindings and schema before choosing configuration. Current accounts source references DB ancientnestaccounts, ID a045391c-1896-4169-bd17-04140d1cbb27; this differs from older ancient-nest-accounts ID 29fde404-477e-443d-83ab-44072f1d2e53. Verify actual ownership/bindings; do not assume either is the right migration target.
BEFORE any migration, export the verified database with wrangler d1 export <verified-name-or-binding> --remote --output <private-backup-path>. Keep SQL outside Git, hash and verify nonempty schema/data, preserve restore instructions. Inspect migrations and run local upgrade tests against a private copy. The migration script now creates and hashes an export before remote changes; inspect it and perform a restore drill before production migration.
Preserve Worker names, Durable Object namespace/migration history and secrets. Account secrets: JWT_SECRET, COORDINATOR_API_KEY, DISCORD_CLIENT_SECRET; voice additionally DISCORD_BOT_TOKEN. Discord client ID in source: 1562796619722793010. Matchmaker also needs matching coordinator key, MONITOR_TOKEN and configured TURN credentials as its implementation requires. Set missing secrets through local secure prompts; never print values or overwrite working ones. Verify Discord portal redirects/scopes against the actual SDK flow.
Use inspected/tested package deployment commands after reconciliation, then verify /health, /ready, /auth/discord/config, /discord/ready and authenticated WSS. Public game endpoints must not redirect to Cloudflare Access browser login. Change only the relevant matchmaking Access app if needed; preserve unrelated protections. Update game origin to the verified deployed service. Preserve ALLOW_GUESTS=false in production.

## 6. Required release tests
On real Windows: native Discord SDK loading, keyring save/restore/delete, first consent, session restore, revoked/expired access, logout, unique usernames, account isolation and real microphone/team voice. Confirm wrong-team users cannot join; cleanup on disconnect/end/expiry; test existing Discord call coexistence.
Two PCs on separate internet connections: authenticate two users; 1v1 search, vote, elect host, host-ready/admission handshake, both enter gameplay, movement/shots/objectives sync, disconnect/reconnect and host-loss behavior. Exercise 2v2–5v5 with enough distinct clients; parties stay teammates and search sizes respect playlist capacity. Do not fake success with a health endpoint or same-machine clients.
Cloudflare coordinates; player PC simulates. Inspect actual transport before firewall changes. For native WebRTC, test direct UDP ICE and actual TURN relay with two NATs; permit the specific game executable through Windows Firewall. Reforged may use a different transport: determine actual listening UDP port before documenting router forwarding. Do not invent a fixed port or disable the firewall. If relay is absent and inbound UDP is required, document the exact port and CGNAT limitation and add/test relay or appropriate hosting. Confirm TURN leases, host readiness and admission tickets rather than claiming configuring a key proves connectivity.

## 7. Finish
Commit source fixes to a new branch, push without force, verify the remote commit/files. Preserve this recovery branch. Report local, live-service, Windows and two-PC tests separately. Publish no executable and trigger no auto-publishing workflow until required live/Windows tests pass. Provide build/install instructions only for the verified integrated source, list remaining blockers and their exact resolution, and record final URLs/protocol and canonical checkout.

## 8. Current source handoff: networking, master traffic and films (2026-10-25)

The current task expressly forbids production deployment, credential changes and production data deletion. This section takes precedence over older deployment/push instructions for this task. No production deployment or executable publication was performed. Preserve all existing dirty work; do not use reset/clean to construct a rollback. Protocol is now `10.5-discord2`, and requires matching coordinator and clients. The existing Cloudflare Worker remains the sole master. See the final sections of VALIDATION.md for settings, measured versus estimated traffic, trust limits and test coverage.

From CMD in the canonical root, with GODOT_BIN set to the installed Godot 4.6.3 console executable:

```bat
npm.cmd --prefix matchmaking run typecheck
npm.cmd --prefix matchmaking run build
npm.cmd --prefix matchmaking test
"%GODOT_BIN%" --headless --path game --script res://tests/master_control.gd
"%GODOT_BIN%" --headless --path game --script res://tests/network_policy.gd
"%GODOT_BIN%" --headless --path game --script res://tests/network_rewind_cover.gd
"%GODOT_BIN%" --headless --path game --script res://tests/film_playback.gd
"%GODOT_BIN%" --headless --path game --script res://tests/server_browser.gd
node scripts/network-authority-playtest.mjs film_network
node scripts/network-authority-playtest.mjs network_netcode --impaired
node scripts/lobby-lifecycle-playtest.mjs
set NEST_RATE_TICKS=2
node scripts/network-rate-playtest.mjs
```

The lifecycle harness runs a loopback Miniflare master and isolated native clients; it never deploys. Its CPU-admission fixture permits shared-PC testing and is not CPU certification. Its outage test expires a shortened lease and blocks control for six seconds while leaving gameplay intact. Repeat a real 60+ second control outage on isolated staging, keeping UDP/TURN available, then restore the same master. Verify one accepted epoch, no second host, reconnect recovery, continued shots and concise noninterrupting status. Test true host loss separately. For two-player host loss, lack of a majority should fail clearly rather than create another authority.

Windows/WAN matrix: two distinct accounts/PCs on different internet connections, Discord consent/session renewal, browser open/close/manual refresh, rapid cancel/requeue with delayed replies, direct ICE and forced compatible TURN, occupied/stale/full lobbies, all playlists, willing/unwilling host selection, both-direction damage/reload/respawn/objectives, 2–10 actual participants, loss/jitter/upload saturation, weak CPU and host loss/rejoin. Capture gameplay RTT, master latency, simulation p95/overruns, actual wire traffic via packet capture and control handler spans independently. Check the pinned WebRTC API limitation before calling snapshot payload bytes wire measurements. Do not lower simulation Hz to reduce Cloudflare traffic.

Local headless Godot logged a root-certificate-store read warning. Resolve it and test real HTTPS/WSS certificate validation on the target Windows PC; loopback success does not prove production TLS connectivity. Do not bypass certificate verification.

Film matrix: record a completed match, wait for collection, open Films, select every player's name/team, pause/cycle/seek/step at forward and reverse 1x/2x, zoom/recoil/reload/weapon changes, faction radar rules, confirmed feedback, death/spectator/respawn, late join and disconnect. Missing tracks must say Reconstructed View or unavailable. Export/reopen on another PC; test long recordings/retention, interrupted upload, early new search, ten independent perspective uploads, Custom Forge layouts and viewport/HUD preferences. Inspect upload/download and disk usage plus capture/worker CPU. Film connections may persist after return-to-menu solely for bounded transfer, and must reject gameplay RPCs; new search must not wait for them. Archives and local tracks are player-submitted interactive reconstructions, not proof of honest play.

Future production rollout instructions (do not execute under the current task): obtain separate deployment authorization after staging/WAN acceptance; preserve a reviewed source revision and the previous Worker version ID/client package; privately export any database only if a schema change is later proposed (none is needed here). Drain queues/matches rather than mixing protocols. Build/test the matching client/coordinator, deploy only the existing matchmaking Worker using its existing namespace/bindings, then distribute the matching client. Do not deploy accounts or rotate secrets for this change. Verify ready/authenticated connection, browser, assignment, host receipt/revision and result idempotency; observe the metrics without verbose per-heartbeat logs.

Rollback instructions: stop new admissions and drain active matches, then restore the previously recorded Worker deployment through Cloudflare's version rollback and restore its matching prior client package. Never mix `10.5-discord1` and `10.5-discord2`, delete Durable Object storage, recreate bindings or reset credentials as rollback. Preserve pending-result journals and films; do not replay an unknown old result as a new match. Rollback is a future authorized operational action, not something performed by this handoff.

## 9. Campaign Mission 1 — current Windows handoff

Specification fetched and verified from `codex/campaign-master-instructions-2026-10-25`
at `f2c4902`; the full 23-section file is preserved in docs. Current work stays on
`feature/campaign-mission1-2026-10-25`, above baseline `e8fd54a` and networking
`4d71526`. The instruction branch does not replace the current PC game.

Read `docs/CAMPAIGN_MISSION1.md` for canon, flow, **Difficulty**, controls,
direct co-op setup, saves, missing narration/art, test commands, manual Windows
acceptance and deployment/rollback boundaries. Run `Play Ancient Nest Campaign.cmd`
from the canonical checkout. Offline campaign is available after the existing age
notice, without a Cloudflare/Discord login. Online matchmaking retains its
authentication. The campaign is unranked and uses host-owned saves.

Private local build:
`C:\Users\Corey\Games\AncientNest-Campaign-Private-20261025-Final\Ancient Nest.exe`.
Desktop shortcut: **Ancient Nest - Campaign Private Test**. Keep all DLLs/licenses
beside the executable. No release, ZIP or executable was published. Older builds
and project folders remain intact. Source/packed-campaign checks passed; human
playthrough, physical-PC/WAN/voice and sustained performance remain to verify.

Use `node scripts/campaign-validation.mjs` for regression scripts. It isolates
APPDATA and fails on script errors/timeouts. Never run a preference-writing
fixture against live user data. The controls/age fixtures now require the
runner's isolated-QA flag. A first legacy controls test overwrote the live
preferences with fixture bindings; the exact previous settings could not be
recovered. The overwritten file and an older profile are preserved outside Git
in `AncientNest-Campaign-Checkpoint-20261025`; restoring the older profile awaits
the owner's choice. Credentials and authentication secrets were not changed.

Normal multiplayer still requires a matching `10.5-discord2` coordinator; no
production deployment is authorized or performed here. Campaign direct co-op
needs a reachable UDP host, not a new Worker. Follow section 8 for any future
separately authorized coordinator rollout and version rollback.
