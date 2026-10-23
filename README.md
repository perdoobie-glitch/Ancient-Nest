# Ancient Nest — unified development source

**10.5-dev**, protocol **10.5-discord1**. Displayed game name: Ancient Nest. Project identity: AncientNest-Reforged-2026-10-23.

One playable Godot game now combines the recovered full 10.2 game/maps with the current Discord account system. The coordinator, account-backed playlist rankings, service cards and team-voice lifecycle are integrated in this source. This is a development integration, not a certified public release.

| Folder | Purpose |
| --- | --- |
| game | Canonical playable game, six maps, weapons, bots, objectives and player-host networking |
| matchmaking | Cloudflare Durable Object coordinator; five playlists, voting, host selection, admission and results |
| ancient-nest-accounts | Discord identity, persistent sessions, playlist rankings and server-owned team voice |
| monitor | Godot master-service monitor |
| website | Existing browser menu preview, not the authentication backend |
| scripts | Shared local setup and native two-client transport test |

## Start on Windows
Install Git, Node.js 24 LTS, Python 3.11+ and Godot 4.6.3 (matching export templates if building). Ensure `node`, `npm`, `python` and `godot` work in CMD. Read [the PC handoff](PC_CODEX_HANDOFF.md), then run **Setup Ancient Nest.cmd** and **Play Ancient Nest.cmd**. The launch script now opens the full game. Native Discord/keyring downloads are pinned and checksum-verified; WebRTC runtime dependencies are included.

The account service's `godot-client` folder is a native/auth test fixture. It is not the game launcher. The old adapter-only root launcher and duplicate historical trees have been removed from the working tree. Recovery history remains intact.

## Server setup
Do not deploy until you inspect existing Cloudflare bindings and preserve credentials. Accounts need JWT_SECRET, shared COORDINATOR_API_KEY, DISCORD_CLIENT_SECRET and DISCORD_BOT_TOKEN. Matchmaking needs the same coordinator key, ACCOUNT_API, TURN credentials and MONITOR_TOKEN. Production guest mode stays disabled.

From ancient-nest-accounts: `npm ci --ignore-scripts`, `npm test`, `npx wrangler login`, `npm run db:remote`, `npm run deploy`. Remote migration now stops unless a database export and SHA-256 were created first. Review the configured DB ID before running it. Existing historical Steam-account data is not automatically mapped to Discord users; identity proof and a reviewed migration are required.

From matchmaking: `npm ci`, `npm run typecheck`, `npm run build`, `npm test`, then `npx wrangler deploy`. Game and coordinator must both use **10.5-discord1**. Preserve Durable Object migration history and existing Worker names. There is no dedicated simulation server: the elected player's PC runs the match.

## Checks
- Accounts: `npm --prefix ancient-nest-accounts test`
- Coordinator: `npm --prefix matchmaking run build` then `npm --prefix matchmaking test`
- Native account/SDK fixture: run `npm run test:godot` inside ancient-nest-accounts.
- Two local native clients: `python scripts/native-smoke.py` (uses loopback-only guest fixtures, not production credentials).
- Full-game account UI: `godot --headless --path game --script res://tests/unified_account.gd`
- Monitor: `godot --path monitor`

See [VALIDATION.md](VALIDATION.md) for actual results and limits. Do not claim local mocks prove live Discord or WAN matchmaking. Windows workflow now tests/builds without publishing downloads or releases. No executable was published for this integration.

Recovery baseline: [fe249599](https://github.com/perdoobie-glitch/Ancient-Nest/tree/fe249599b46a5bcc25edaf91bf856bc200b64b11). The separate earlier Reforged commit 0156a0d... remains unavailable; this source integrates the recoverable full game rather than pretending that commit was recovered.
