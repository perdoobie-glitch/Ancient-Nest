# Website story / faction update verification

Content-only website update, locally verified 2026-10-19.

PASS: npm run typecheck.
PASS: NEXT_PUBLIC_ACCOUNTS_ENABLED=true npm run build:static (Next production export).
PASS: 343 actual local browser/Worker/D1 checks at375,768,1024,1440px, including
routes, metadata,404/assets, overflow, mobile navigation, account linking/revocation,
profile integration, and Axe WCAG A/AA checks. Steam provider was simulated.
PASS: 437 built internal links and fragment targets checked.
PASS: Rendered Home/Game/Play/Community use Perdoobie & Mishwad Studio; Game renders
all four story sections, Brutus Link, and the explicit Annu game-type exception.
Desktop game/story screenshot inspected; mobile and desktop snapshots included.

The first browser attempt found the account UI flag absent in the export environment.
The export was rebuilt with its prior true flag and the complete browser suite passed.
No account/stat API or gameplay logic was changed. Backend unit tests were not rerun
for this copy edit; previous backend results belong to the prior account handoff.

NOT verified: public Cloudflare deployment, live DNS or real Steam services, Claude's
current game branch, or website publishing. No deployment was performed by Codex.
This is a source/asset handoff for the user's existing Cloudflare Worker.
