# Ancient Nest 10.1 release notes

Use the release root Setup Guide and CHANGELOG as the current integration instructions. This project is part of one coordinated 10.1 release; preserve live Worker names, routes, D1 data and secrets. Apply Accounts migrations 0003 and 0004 to the existing database, deploy the built website/Accounts first, then Matchmaking, then clients. The protocol is `10.1-peerhost2`; finish old matches before updating. Custom games and bot practice never grant server ranks. Accounts supplies five independent playlist ladders and the weighted service card; do not accept client-submitted Elo. Private review records retain disputed results without awarding unconfirmed points.

No live deployment or real Steam purchase verification was performed in the release environment. There is no Steam App ID configured. Public website identity login is separate from game ownership. See the root guide for the remaining Windows/GPU and multi-network acceptance steps.

# Ancient Nest 8.0 — Website frontend
Next.js + TypeScript + Tailwind. The included `out/` is a prebuilt static export with the account UI enabled and same-origin account API calls. The sibling account Worker serves it with its backend. Do not upload TypeScript directly through a static-only uploader.

To change/rebuild content: install Node LTS; npm ci; copy .env.example to .env.local; set the canonical NEXT_PUBLIC_SITE_URL and account-related public settings, keep NEXT_PUBLIC_ACCOUNTS_ENABLED=true; npm run typecheck; npm run build:static. Never place private API keys in NEXT_PUBLIC_* variables. Deploy using the sibling account Worker.

Main routes: /, /game, /play, /community, /news, /account, /profile, /profile/demo, /status, /privacy, /terms. Privacy/terms remain draft content to review before public operation. The game/master/monitor release is 8.0; the website retains the Ancient Nest brand. Real account creation requires the deployed Worker, D1 and server secrets.
