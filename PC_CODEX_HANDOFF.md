# Windows Codex handoff

## Identity and source
Repository: https://github.com/perdoobie-glitch/Ancient-Nest
Branch: recovery/source-audit-2026-10-23
Use the exact verified commit supplied in the accompanying cloud response; do not silently move to another branch or latest main. Record git rev-parse HEAD before changes.
Canonical directory: C:\Users\Corey\Games\AncientNest-Reforged-2026-10-23-Canonical
Display name: Ancient Nest. This checkout is recovery material until integration passes, not a finished Reforged release.
Read AGENTS.md, RECOVERY_STATUS.md and VALIDATION.md first.

## 1. Cleanup preparation before setup
Inventory only Ancient Nest GAME project copies, installed game copies, relevant shortcuts and game save/settings directories. Include dirty Git changes, untracked source, unique maps/assets, and Godot userdata under %APPDATA%\Godot\app_userdata. Do not dump credentials into reports.
Before moving anything: confirm the replacement branch/commit is remotely available; download into a temporary staging directory, verify its commit and all entries in recovered/SOURCE_SHA256.json. Archive unique work/settings/saves with a filename/size/SHA-256 inventory; verify archive contents and perform a sample restore. Keep credential storage private and unchanged.
Only then move clearly obsolete, fully backed-up copies and their shortcuts to the Windows Recycle Bin. Use an available Windows Recycle Bin API or File Explorer, not permanent del/rmdir. Do not recycle the only Reforged copy or anything of uncertain provenance. Preserve business/unrelated files, recovery archives, credentials, cloud data and this staged replacement. If the missing Reforged work cannot be recovered, defer retirement of any possibly newer copies. After cleanup preparation, use the canonical checkout; do not overwrite an existing directory.

## 2. Recover the missing integration
Locate the original Reforged checkout or archive/bundle containing commit 0156a0d66bb1f850494e7d75a8d32fe4917ea7d2. If found, preserve uncommitted/untracked assets too. Inspect history and compare source/features with the complete 10.2 baseline and newer 10.4 accounts. Import it onto a new integration branch without force-pushing or replacing current remote history. If absent, report that transfer from the original session is required; do not invent it.
The full older game is now under recovered/v10.2/Game. Current account/Discord code is ancient-nest-accounts. Historical coordinator is recovered/v10.2/Services/cloudflare. Historical account/website/monitor sources remain alongside it for reference. Use a working copy for changes; preserve the hashed baseline.

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
For the historical coordinator, from its folder:
```cmd
npm ci
npm run typecheck
npm run build
npm test
```
Baseline game editor (offline only until integration):
```cmd
godot --editor --path recovered10.2\Game
```
Baseline launch:
```cmd
godot --path recovered10.2\Game
```
Existing root Play/Setup scripts target the account starter; do not present them as a full-game installer. Connect Existing Game.cmd is only a guarded adapter, not completed coordinator/ranking/voice integration. Do not run it blindly against the preserved baseline.

## 4. Reconcile contracts before deployment
Keep 10.2-peerhost2 for an unchanged baseline; choose and document a new shared protocol only when both integrated client/server change together. Recover or implement the profile, per-playlist rankings, match-result persistence and review contracts required by the coordinator. Custom games must not change ranking. Keep authoritative account IDs and server-validated results; never trust client-supplied rank/team identity.
Integrate server-owned team voice using the existing /internal/voice API, only after roster/team assignment. Handle reconnect, departures, match end, cancellation, host failure and expiry; retries must be idempotent. Never embed bot/coordinator credentials in the game. Reuse examples/matchmaking-discord-bridge.js as a starting point, then test actual coordinator lifecycle.
Verify signed/key-bound assertions, host readiness, admission-ticket expiry/replay rejection, elected host identity, roster membership and transport compatibility. Do not enable guest mode to conceal authentication failures.

## 5. Cloudflare authentication, backup and deployment
Account ID: 95cd0db7b4086189f21e49dbeea65e26.
Accounts: https://ancient-nest-accounts.ancientnest-llc.workers.dev
Existing master: https://ancient-nest-matchmaking.ancientnest-llc.workers.dev
Existing game WSS: wss://ancient-nest-matchmaking.ancientnest-llc.workers.dev/v1/matchmaking

Run npx wrangler whoami; if unauthenticated, npx wrangler login and let Corey approve the browser. If network fails, diagnose DNS/proxy/TLS without disabling certificate checks. No temporary-preview deployment as a substitute.
Inspect deployed bindings and schema before choosing configuration. Current accounts source references DB ancientnestaccounts, ID a045391c-1896-4169-bd17-04140d1cbb27; this differs from older ancient-nest-accounts ID 29fde404-477e-443d-83ab-44072f1d2e53. Verify actual ownership/bindings; do not assume either is the right migration target.
BEFORE any migration, export the verified database with wrangler d1 export <verified-name-or-binding> --remote --output <private-backup-path>. Keep SQL outside Git, hash and verify nonempty schema/data, preserve restore instructions. Inspect migrations and run local upgrade tests against a private copy. Existing Setup script applies migrations without making this export: complete backup first, not after.
Preserve Worker names, Durable Object namespace/migration history and secrets. Account secrets: JWT_SECRET, COORDINATOR_API_KEY, DISCORD_CLIENT_SECRET; voice additionally DISCORD_BOT_TOKEN. Discord client ID in source: 1562796619722793010. Matchmaker also needs matching coordinator key, MONITOR_TOKEN and configured TURN credentials as its implementation requires. Set missing secrets through local secure prompts; never print values or overwrite working ones. Verify Discord portal redirects/scopes against the actual SDK flow.
Use inspected/tested package deployment commands after reconciliation, then verify /health, /ready, /auth/discord/config, /discord/ready and authenticated WSS. Public game endpoints must not redirect to Cloudflare Access browser login. Change only the relevant matchmaking Access app if needed; preserve unrelated protections. Update game origin to the verified deployed service. Preserve ALLOW_GUESTS=false in production.

## 6. Required release tests
On real Windows: native Discord SDK loading, keyring save/restore/delete, first consent, session restore, revoked/expired access, logout, unique usernames, account isolation and real microphone/team voice. Confirm wrong-team users cannot join; cleanup on disconnect/end/expiry; test existing Discord call coexistence.
Two PCs on separate internet connections: authenticate two users; 1v1 search, vote, elect host, host-ready/admission handshake, both enter gameplay, movement/shots/objectives sync, disconnect/reconnect and host-loss behavior. Exercise 2v2–5v5 with enough distinct clients; parties stay teammates and search sizes respect playlist capacity. Do not fake success with a health endpoint or same-machine clients.
Cloudflare coordinates; player PC simulates. Inspect actual transport before firewall changes. For native WebRTC, test direct UDP ICE and actual TURN relay with two NATs; permit the specific game executable through Windows Firewall. Reforged may use a different transport: determine actual listening UDP port before documenting router forwarding. Do not invent a fixed port or disable the firewall. If relay is absent and inbound UDP is required, document the exact port and CGNAT limitation and add/test relay or appropriate hosting. Confirm TURN leases, host readiness and admission tickets rather than claiming configuring a key proves connectivity.

## 7. Finish
Commit source fixes to a new branch, push without force, verify the remote commit/files. Preserve this recovery branch. Report local, live-service, Windows and two-PC tests separately. Publish no executable and trigger no auto-publishing workflow until required live/Windows tests pass. Provide build/install instructions only for the verified integrated source, list remaining blockers and their exact resolution, and record final URLs/protocol and canonical checkout.
