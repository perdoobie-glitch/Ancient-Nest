# Ancient Nest accounts — 10.5 development

Discord sign-in and persistent OS-keyring sessions, linked game usernames, per-playlist ranking, overall service cards and server-owned team voice. This is the canonical account service for the integrated repository; see ../README.md and ../PC_CODEX_HANDOFF.md.

Required: Node.js >=22 (24 LTS recommended), existing Cloudflare Worker/D1 access, JWT_SECRET, shared COORDINATOR_API_KEY, DISCORD_CLIENT_SECRET and DISCORD_BOT_TOKEN. Never embed these in the game. Discord client ID: 1562796619722793010.

Run npm ci --ignore-scripts, npm test, npx wrangler login, then npm run db:remote and npm run deploy only after verifying database ownership/configuration. Migration 0006 adds ranking tables referencing existing users. Prior migration 0005 revokes old device sessions once and requires Discord proof. The migration tool exports/hashes the remote DB before changing it; preserve private SQL outside Git and test restoration. Do not run fresh-database SQL over an existing database.

Existing users/sessions are preserved. Historical Steam identities in a different database are not automatically linked to Discord. Authentication alone is not purchase verification.

Game assertions bind Discord-backed users to their RSA public keys. Ranking routes match the coordinator's profile/register/migrate/result/review contracts; only coordinator-authenticated matchmaking results affect ranks. Player-host consensus is not dedicated-server anti-cheat.

Voice assignment requires the coordinator key and uses server-owned rosters. Discord provider failures are retried. Completed/failed matches end their rooms; disconnected players retain reserved membership until teardown/expiry. Test real desktop audio, permissions and NAT before release.

The godot-client folder is an auth/native integration test fixture. The actual game is ../game. Run root Setup Ancient Nest.cmd to install native dependencies in both. Build script exports the full game, but publication is gated on live/Windows verification.
