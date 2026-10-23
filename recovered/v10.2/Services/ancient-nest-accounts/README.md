# Ancient Nest 10.1 release notes

Use the release root Setup Guide and CHANGELOG as the current integration instructions. This project is part of one coordinated 10.1 release; preserve live Worker names, routes, D1 data and secrets. Apply Accounts migrations 0003 and 0004 to the existing database, deploy the built website/Accounts first, then Matchmaking, then clients. The protocol is `10.1-peerhost2`; finish old matches before updating. Custom games and bot practice never grant server ranks. Accounts supplies five independent playlist ladders and the weighted service card; do not accept client-submitted Elo. Private review records retain disputed results without awarding unconfirmed points.

No live deployment or real Steam purchase verification was performed in the release environment. There is no Steam App ID configured. Public website identity login is separate from game ownership. See the root guide for the remaining Windows/GPU and multi-network acceptance steps.

# Ancient Nest 8.0 — Website and Accounts
This folder deploys the account API and sibling `ancient-nest-web/out` website assets. Read chapters 14–18 of the release PDF. It is separate from the matchmaking master and does not run 3D games.

Fresh setup: open CMD here, run `npm ci`, `npx wrangler login`, then `npx wrangler d1 create ancient-nest-accounts`. Copy the returned database UUID into `Configure Website.cmd`. Run `Deploy Accounts.cmd` to check/build, apply versioned migrations and deploy. Run `Configure Account Secrets.cmd` for a fresh service, or restore the ORIGINAL signing/pepper/coordinator secrets for an existing service. Attach the chosen HTTPS canonical domain to the correct Worker. Never delete a live D1 database to make setup pass.

Default Worker name is `ancient-nest-accounts`; the database ID is intentionally a placeholder. The wizard can deliberately target the existing `broken-wave-9d1e` website, but this replaces its code/assets; back up newer edits first. Your own D1 ID and actual SITE_ORIGIN are required. Keep the two sibling account/web folders together.

Stable private secrets: ACCOUNT_SIGNING_KEY, CODE_PEPPER, COORDINATOR_API_KEY. The master needs the same COORDINATOR_API_KEY; use MasterServer/Connect Accounts Stats.cmd. No signing/coordinator/publisher keys belong in the game or frontend. Local `.secrets/` files must never be uploaded with a release.

Steam OpenID login identifies a Steam account without a game App ID. REQUIRE_OWNERSHIP=false and empty STEAM_APP_ID are transparent prerelease identity testing, not purchase validation. Later configure your real App ID, STEAM_PUBLISHER_KEY and tested REQUIRE_OWNERSHIP=true. Direct-sales checkout and other marketplace entitlement adapters are not implemented.

The backend includes installation linking, private proof-bound game assertions, official stats/ranking, agreed-result registration and D1 deduplication/authority guards. Editable local game ranks are separate from official website records. Browser tests simulate Steam; real Steam and store-license verification need your live deployment.

Development: npm ci; npm run typecheck; npm run build; npm test. Browser integration: npm run test:browser, with sibling web dev dependencies and Chromium installed. API documentation and migrations are included in docs/ and migrations/. Some reference docs originated before the 8.0 integration; the release PDF and this README are the current deployment instructions.
