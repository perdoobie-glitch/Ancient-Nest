# Recovery audit — 2026-10-23

Repository: https://github.com/perdoobie-glitch/Ancient-Nest
Branch: recovery/source-audit-2026-10-23
Parent inspected: 596496d945e558be8eb7b468f17c5e149abdce91 (main).

## What was recovered

The complete previously packaged 10.2 development source was available in this session at /workspace/work/v10-three-maps. `recovered/v10.2` contains all 3,208 non-PDF files from the Complete Source archive: Game, Monitor, historical Services/cloudflare, historical Services/ancient-nest-accounts, historical Services/ancient-nest-web, and release notes. Native WebRTC dependencies and source assets are included. No exported game executable is added. SHA-256 hashes of each recovered file are in recovered/SOURCE_SHA256.json.

Original archive SHA-256: 2ca972be98c0caa88bc1afaf87ddaff9bf49b40b215fcab2a207a98aca0b3da9.
Archive: https://drive.google.com/file/d/1AqvpA4VTPnkLuEn7LxnHpt7zmh9DEDJJ/view
The PDF omitted from the source checkout is available separately: https://drive.google.com/file/d/1zg8lh7wGJEXBIieuWoizYWR2_35TystN/view

Actual game features inspected: version 10.2, native WebRTC peer-host client, protocol 10.2-peerhost2, six maps including Connectuct/Qaytal/Temple, objective scripts, game weapons/assets, monitor and Cloudflare coordinator. This is more than the login-only starter present on main.

## What is still missing

/workspace/scratch/cda7e25c31e8/AncientNest-Reforged-2026-10-23 is absent from this session. No reforged directory was found in available workspaces or the cloned main branch. GitHub returned HTTP 422, "No commit found for SHA: 0156a0d66bb1f850494e7d75a8d32fe4917ea7d2". Only main was returned by the branch search and clone.

The Reforged source archive or Git bundle MUST be transferred from the original session/PC before that exact newer integration can be recovered. A hash alone cannot restore it. Do not rename the older baseline to make it appear recovered. Preserve project identity AncientNest-Reforged-2026-10-23 for the future integrated project and displayed name Ancient Nest.

## Integration findings

Current main contains account/Discord version 10.4, not a full game. It implements /api/game/assertion and /api/game/verify with proof-bound identity. Its guarded game adapter recognizes the 10.2 account interface in principle, but requires native SDKs and full behavior testing.

The recovered 10.2 matchmaker expects /api/game/profile, /api/internal/reviews, /api/internal/players/ratings and /api/internal/matches/* from its historical account service. The newer 10.4 service does not implement these contracts. It offers a different /internal/voice/* contract; no voice lifecycle requests exist in the recovered coordinator. Neither rankings nor team voice may be claimed compatible simply by changing ACCOUNT_API.

Historical 10.2 accounts and current 10.4 accounts use different schemas/configuration and database IDs. Never deploy one over the other or run migrations against a guessed database. Keep both sources for reconciliation.

## Cloud limits

Current cloud network policy excludes Cloudflare/Discord. A GET to the account Worker failed before reaching it: curl (56) CONNECT tunnel failed, response 403, proxy server envoy. Thus older observations of /health 200, /ready 503, /auth/discord/config 404 are NOT reverified.
Wrangler 4.151.2 reports: "You are not authenticated. Please run wrangler login."
No configured Cloudflare credentials or desktop/browser-control tool exists here. Browser login must be completed from the Windows session. No Workers, databases, migrations or secrets were changed. No executable published.
