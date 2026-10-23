# Deploy to the existing Cloudflare Worker

This kit has not been deployed. Use a trusted terminal or your Cloudflare agent with
actual code-upload capability. DNS/account access alone does NOT deploy code files.
Do not paste production secrets in Claude, Codex, Cloudflare AI chat, Git, or screenshots.

Existing resources from your report:
- Worker: broken-wave-9d1e, with static assets
- Worker URL: https://broken-wave-9d1e.ancientnest-llc.workers.dev
- www.ancientnest.net attached; apex ancientnest.net not confirmed attached
- Cloudflare zone: ancientnest.net, active
- Account ID95cd0db7b4086189f21e49dbeea65e26

## 1. Back up and choose ONE origin

Save existing deployed Worker code/config and assets and note all bindings/routes.
Do not delete DNS/email records, existing databases or rename the Worker.
Either attach ancientnest.net as a custom domain (if that is the intended canonical
host), or use the existing workers.dev HTTPS origin for a preview. Verify it works.
Set the SAME origin in frontend NEXT_PUBLIC_SITE_URL, Worker SITE_ORIGIN, game public
account config and private hub account API config. An unbound apex must not be used
for auth. Redirect alternate hosts toward the chosen host, preserving URL/query,
before accepting sessions; never redirect the callback away to a different origin.

## 2. Prepare source and static assets

Keep `ancient-nest-web` and `ancient-nest-accounts` side by side. Node24LTS recommended.
In ancient-nest-web, copy .env.example to .env.local, set site URL to chosen origin,
NEXT_PUBLIC_ACCOUNTS_ENABLED=true, leave Steam app ID EMPTY. Do not add secrets there.

```sh
npm ci
npm run typecheck
npm run build:static
```

In ancient-nest-accounts:

```sh
npm ci
npm run typecheck
npm run build
npm test
npx wrangler login
npx wrangler whoami
```

Confirm the selected account matches your Ancient Nest account. The frontend's normal
`npm run build` is also supported for Vercel/Next hosting, but this Worker deployment
uses `out/` static export plus a separate bundled API Worker.

## 3. Create/bind D1 without resetting data

If no account DB exists:

```sh
npx wrangler d1 create ancient-nest-accounts
```

Put the returned database_id in wrangler.jsonc (replace REPLACE_WITH...). Bind as
ACCOUNTS_DB. If a database already exists, inspect applied migrations/back it up and
reuse it; do NOT rerun raw CREATE TABLE manually or wipe existing users.

```sh
npx wrangler d1 migrations apply ancient-nest-accounts --remote
```

Apply both0001 and0002 through the migration system. Do not assume creating a database
creates tables. Keep D1 backups enabled/retention suited to your policy.

## 4. Generate/set secrets privately

On trusted local machine, once:

```sh
npm run generate:keys
npx wrangler secret put ACCOUNT_SIGNING_KEY < .secrets/account-signing-private.pem
npx wrangler secret put CODE_PEPPER < .secrets/code-pepper.txt
npx wrangler secret put COORDINATOR_API_KEY < .secrets/coordinator-api-key.txt
```

For PowerShell use Get-Content -Raw <file> piped to `npx wrangler secret put NAME`;
do not use commands that print secrets or put them directly in shell history.
Store encrypted backups outside this project. The coordinator credential must also
be set in the PRIVATE hub's secret environment, never in game builds/player-hosts.
Changing these secrets casually can invalidate active assertions/link codes.

No Steam App ID yet: leave STEAM_APP_ID empty and REQUIRE_OWNERSHIP="false" for clearly
labeled pre-release identity integration. This does not verify a purchase. After
Steamworks assigns YOUR App ID, set it and a publisher-owned STEAM_PUBLISHER_KEY via
Wrangler secret; set REQUIRE_OWNERSHIP="true" only after testing licensed/unlicensed
accounts and provider failures. Never put publisher credentials in frontend vars.

## 5. Review and deploy code + assets

wrangler.jsonc uses name=broken-wave-9d1e, main=dist/worker.js, ASSETS binding pointing
to sibling ancient-nest-web/out, run_worker_first=["/api/*"], D1 binding and hourly
cleanup. Preserve any other required existing settings intentionally.

```sh
npx wrangler deploy --dry-run
npx wrangler deploy
```

Review output and test preview before production route changes. A static-only drag-
and-drop upload cannot deploy this database/auth service. The secret configuration,
D1 and combined Worker/assets deploy are all necessary. No such deploy has been run
by Codex in this session. Production CLI/domain/certificate verification remains open.

## 6. Verify on the actual canonical domain

- GET /api/account ->configured:true,authenticated:false; no fake identity.
- /account ->real Steam link to /api/auth/steam. Click and complete real Steam login.
- Return to chosen-origin /account with authenticated username and UUID.
- Choose unique username, verify Origin/CSRF failures rejected.
- /profile ->rank#1/RP0/Unrated/no fabricated stats for new account.
- Steam license ->not_configured while App ID/key absent, never verified.
- Claude's real game branch ->show code/fingerprint->websiteapprove->device appears.
- Restartgame->proofrefresh; renameaccount->sameUUID/newusername.
- Unlink->newverification rejected; logoutwebsite does not unlink another device.
- Privatehub ->authorize/register actual matchmaking->result->profile updates once.
- Repeat exact result ->no double stats; changed result ->409; oldhostepoch ->409.
- Offline/custom/NestForge does not enter rated ledger.
- Verify HTTPS, www/apex redirects, cookie scope, callback query preservation, mobileUI.
- Confirm no signing key/publisher key/coordinator key in browser network responses,
  static files, game executable, installer, public config, logs, or source ZIP.

Live Steam identity, real purchase/licenses, actual installer/game/hub, and public
DNS/cert behavior must be verified AFTER deployment; local simulated-provider tests
are not a substitute. Integrate the private hub per STATS_API before claiming live stats.

## Brief for your Cloudflare agent

“Deploy the supplied combined Worker+static-assets project to existing Worker
broken-wave-9d1e, preserving its custom domain and unrelated resources. Use one active
canonical HTTPS origin consistently. Create/reuse D1 ancient-nest-accounts binding
ACCOUNTS_DB and apply versioned migrations0001/0002 without resetting data. Configure
private secrets outside chat. Do not claim static assets alone enable auth. Keep
Steam App ID empty, checkout unavailable, and license status unconfigured until the
real store integration exists. Report actual deployments/bindings/migrations/HTTPS
checks; do not fabricate active services.”
