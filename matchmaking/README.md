# Ancient Nest matchmaking coordinator — 10.5-dev

The current integrated source uses protocol `10.5-discord1` in both the game and coordinator. This is a development integration, not a certified public release. Start with [AGENTS.md](../AGENTS.md), [the Windows Codex handoff](../PC_CODEX_HANDOFF.md) and [VALIDATION.md](../VALIDATION.md). Use the exact verified source commit supplied with the handoff and record `git rev-parse HEAD`; do not silently substitute latest main.

Canonical folders are `game/`, `matchmaking/`, `ancient-nest-accounts/` and `monitor/`. The account service's `godot-client/` is an authentication/native SDK test fixture, not the game launcher. Cloudflare coordinates matchmaking; the elected player's PC simulates the match.

## Current Windows checks (CMD)

Install the handoff's tools: Git for Windows, Node.js 24 LTS, Python 3.11+, Godot 4.6.3 and Discord desktop. Use each project's locked Wrangler dependency. From the canonical repository root, run:

```cmd
set "NODE_OPTIONS=--dns-result-order=ipv4first"
cd matchmaking
npm ci
npm run typecheck
npm run build
npm test
cd ..
```

Follow the handoff for account tests, pinned SDK installation and the real Windows keyring check. From the repository root, run `Setup Ancient Nest.cmd`, then `Play Ancient Nest.cmd` for the full game. The local two-client transport check is `python scripts/native-smoke.py`; it uses loopback-only guest fixtures, not production credentials. Keep production `ALLOW_GUESTS=false`.

## Recorded verification and remaining gates

[VALIDATION.md](../VALIDATION.md) records the 2026-10-23 results; these are not newly run tests or evidence of live deployment:

- 37 coordinator tests: the existing 36 plus one real-account-Worker integration test. The cross-service test uses local D1, mocked Discord identities and simulated game load acknowledgments.
- Two real Godot clients entered one playable match through native WebRTC on loopback using local guest fixtures, with two actors and exactly one host.
- Accounts passed 51 Node tests with mocked Discord provider calls. The native Linux SDK/auth fixture did not involve real Discord authorization.
- A clean locked installation still needs repeating on Windows: the recorded environment hit ENOSPC and used ignored dependency links.

Real Windows export/startup and credential storage, real Discord consent and microphone/team isolation, and two PCs on separate internet connections with direct ICE and actual TURN relay remain required. Larger real-player playlists, GPU/performance and human balance tests are also outstanding. Local fixtures and health/readiness responses do not certify those gates. Publish no executable until the required release tests pass.

## Production work is a separate, gated step

Use sections 4–6 of the Windows handoff for contract reconciliation, inspected configuration, backup and deployment prerequisites. The source expects release `10.5-dev` and protocol `10.5-discord1`; no live service state is asserted here.

Preserve existing Worker names, bindings, Durable Object namespace/migration history, cloud data and working secrets. Verify the actual account binding/database before migrations; export, hash, inspect and test restoration of a private backup first. The historical 10.2 statement that no account migration was needed does not apply to the integration's new migration 0006.

Retain the verified `ACCOUNT_API` origin, the shared `COORDINATOR_API_KEY`, `MONITOR_TOKEN`, `TURN_KEY_ID` and `TURN_KEY_API_TOKEN`; never copy secret values into documentation, game exports or website code. Do not change production services, Access rules or credentials as part of these documentation/local checks. Any subsequent service work must follow the handoff's inspected and tested procedure.

## Historical 10.2 release notes — retained verbatim

The following is the original 10.2 release documentation. Its version/protocol, kit paths, Steam references, migration statement and test counts describe that historical release only. They are not current setup or deployment instructions. The preserved source is on [the recovery baseline](https://github.com/perdoobie-glitch/Ancient-Nest/tree/fe249599b46a5bcc25edaf91bf856bc200b64b11).

---

# Ancient Nest 10.2 matchmaking master

This is the coordinated 10.2 map update. All players and the matchmaking Worker must use protocol `10.2-peerhost2`. Monitor 10.2 understands all six map names. Accounts/website 10.1 APIs and database remain compatible; no new account migration is needed for this map update.

## Updating an existing installation on Windows

1. Finish active matches. Back up your private configuration; never distribute it.
2. Extract the complete kit. Open `Services/cloudflare/Deploy Master.cmd`. Install Node.js LTS first if needed.
3. Sign in to the same Cloudflare account and deploy to the existing `ancient-nest-matchmaking` Worker. Preserve its name, MATCHMAKER binding, v1 Durable Object migration, namespace and secrets. Do not delete the Worker or database.
4. Keep your configured ACCOUNT_API origin and production ALLOW_GUESTS=false. This package defaults to https://ancientnest.net; retain a different working origin if you use one. Preserve MONITOR_TOKEN, TURN_KEY_ID, TURN_KEY_API_TOKEN and the COORDINATOR_API_KEY shared with Accounts.
5. Run `Check Cloudflare Server.cmd`. Expected release is 10.2 and protocol is 10.2-peerhost2. Health/readiness must return JSON rather than redirecting to browser login.
6. Update every game client and the monitor. Keep the existing HTTPS master origin in the monitor and wss:// origin plus /v1/matchmaking in game connection settings. The game default is wss://ancient-nest-matchmaking.ancientnest-llc.workers.dev/v1/matchmaking.
7. Test a complete match with two PCs on separate networks before reopening public queues. Local tests cannot certify your deployed secrets, Steam ownership or internet relay access.

## Maps and modes

0 Sanctuary; 1 Crossroads; 2 Savannah; 3 Connectuct; 4 Qaytal; 5 Temple. All six appear in map voting. Every new map supports Extraction, ISO Deathmatch, Team Deathmatch, Capture the Flag and Bomb Defusal. Queue capacities remain 2/4/6/8/10. Queued parties stay teammates and cannot exceed the selected team size. This update does not add a ten-person pre-search social party; the existing team-size party cap remains.

Player PCs run the match. Cloudflare coordinates parties, queues, voting, host election, handoff, reconnects, results and monitor snapshots. No game EXE belongs on Cloudflare; deploy this build project through Wrangler, not the static uploader.

## First-time setup

Follow the root 10.2 guide and the retained 10.1 first-time Accounts/website guide. Set up Accounts before production matchmaking. `Setup Production.cmd`, `Connect Accounts Stats.cmd`, `Configure TURN.cmd` and `Configure Monitor.cmd` assist with configuration. Reuse the same coordinator secret on both services. Never put private secrets in game exports or website JavaScript. Private-test guest mode is unranked and does not verify purchases; restore production settings before public use.

The public matchmaking paths must not require Cloudflare Access browser sign-in. If blocked, remove only the dedicated matchmaking Access application; keep unrelated website/admin protection. The Worker's own authentication and private monitor-token check remain necessary.

Build checks: npm ci, npm run typecheck, npm run build, npm test. 36 local backend tests passed for this release, including new map voting and rejection of older protocols. The native ten-client tests used local Miniflare and WebRTC, not the live Cloudflare account. No deployment was performed by this release environment.
