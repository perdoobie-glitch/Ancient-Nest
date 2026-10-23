# Unified integration validation — 2026-10-23

## Changes verified locally
- Full 10.2 game/maps retained; Discord startup/account adapter now also exposes playlist profiles and service cards used by game UI.
- New migration 0006 adds ranking/results tables linked to existing Discord user IDs. No production migration was run.
- Shared game/master protocol 10.5-discord1, development release 10.5-dev; monitor updated.
- Coordinator creates server-owned team voice after match start, with independent asynchronous retries and cleanup on results/failure; FFA has no team room. Provider failures do not block heartbeat or ranking delivery. Reconnecting participants keep their roster membership until match teardown/expiry; immediate per-member server eviction is not implemented.
- Remote migration script requires a nonempty SQL export and SHA-256 outside Git before applying migrations. This does not replace a real restore drill.
- Root Windows launcher starts full game; Windows build script targets full game and checks Discord/keyring/WebRTC DLLs. Automatic binary/artifact publication removed from workflow.

## Fresh passing tests
- Accounts: 51 Node tests, including three completed matches, per-playlist isolation, rating unlock, duplicate/conflicting results and custom-game rejection. Discord provider calls are mocked.
- Matchmaking: existing 36 tests including independent voice create retry/cleanup and responsive heartbeat under upstream delay; one additional real-account-Worker integration test (37 total).
- Cross-service test: actual account Worker and D1 issue RSA-key-bound assertions to two mocked-Discord identities; actual matchmaker authenticates them, forms/votes/selects a host, accepts loaded acknowledgments, resumes and registers roster/map in actual local D1. Game load acknowledgments are simulated in this test.
- Two real Godot clients: native WebRTC loopback matchmaking into one playable match, two actors, exactly one host. This separate test uses local guest fixtures and shared-CPU admission telemetry.
- Native Linux SDK/auth fixture: SDK loading, PKCE/scopes, isolated call teardown, login/session restoration/revocation/storage-failure behavior passed. No real Discord user authorized.
- Combined Godot project imports without script errors; 198 objective checks and account UI test passed.
- Monitor: 12 UI/data checks passed.
- Original recovered baseline geometry: 276 checks passed before integration; maps/physics were not changed by this integration.

## Environment limits and unverified gates
`npm ci` hit ENOSPC here. Account tests used jose 6.1.0, existing esbuild 0.28.2 and Miniflare 4.20260730.0 through ignored dependency links. Repeat a clean locked install on Windows. No node_modules/cache/native-secret data is committed.
Cloudflare request failed at the environment proxy: curl (56) CONNECT tunnel failed, response 403. Wrangler reported not authenticated. No live health/readiness, deployments, production database changes or real Discord credentials were tested.
Remaining: real Windows credential store, full-game export/startup on a physical Windows PC, real Discord consent and microphone/team isolation, real NAT/TURN across two internet connections, large real-player playlists, GPU/performance and human balance tests. Linux headless timing is not Windows GPU performance.
The missing earlier Reforged commit cannot be compared for parity; preserve/transfer it if available. Historical Steam accounts/ranks are not silently merged into Discord identities.
