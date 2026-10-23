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
