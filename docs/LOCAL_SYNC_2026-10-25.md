# Verified PC baseline — 2026-10-25

Source: `C:\Users\Corey\Games\AncientNest-Reforged-2026-10-23-Canonical\game`.
Existing remote: `https://github.com/perdoobie-glitch/Ancient-Nest.git`.
Working branch: `feature/campaign-mission1-2026-10-25`.

The starting PC commit was `6d21576caa0438af5d10712c3164b2a065e93ab3`.
Its complete tree `a100eedf78e34c52a3a73608b2cd6e6400d032a4` is identical to
remote update commit `6d5f6d10acfd95d358fe86bcbf39619716447b9c` (PR 3).
There was no uncommitted or untracked source at checkpoint time. The new branch
starts from that verified remote commit; the original PC history remains on
its existing branches and in a verified Git bundle. No source was replaced by
an older remote checkout.

## Preservation and comparison

Checkpoint: `C:\Users\Corey\Games\AncientNest-Campaign-Checkpoint-20261025`.
It contains a verified complete-history bundle, staged/unstaged patch files,
working-tree/untracked inventories, and filename/size/SHA-256 manifests of eight
relevant local source projects. Private configuration and credential folders
were excluded from the content audit. No folders, settings or saves were removed.

| Project | Source/asset files inspected | Comparison with canonical game |
| --- | ---: | --- |
| Canonical `game/` | 1,992 | Current integrated 10.5 source, native accounts, six maps, hybrid networking and films |
| Documents `ancient-nest-the-game` | 35 | Early prototype, no current hybrid/account/film systems |
| Its nested `AncientNest` | 30 | Early prototype |
| Desktop `Ancient-Nest-Windows/v15-development/Game` | 242 | Older 15-test source; 14 same-path files identical, 17 differ, 211 other paths |
| Desktop `AncientNestFPS_Sanctuary_v3` | 91 | Historical prototype |
| Desktop `AncientNestFPS_FullPrototype_v2` | 76 | Historical prototype |
| Desktop prototype `AncientNest` | 30 | Historical prototype |
| `Before-Age-Notice-20261023` | 4 | Partial backup, not a runnable replacement |

Project identities, entry scenes, source contents and feature presence established
provenance; directory dates/names were not used as version evidence. Historical
assets/prototypes remain in place; none were copied wholesale into the active game.
Native account fixtures and the monitor are separate projects, not alternate games.

## Remote reconciliation

Direct `git fetch origin` fails to connect to GitHub from the restricted process.
The connected GitHub API supplied current branch heads and remote source/diffs.
`main` and `integration/unified-2026-10-23` remain at `e0bf594`.
The verified update branch at `6d5f6d1` already contains all current PC source.
The remote commit object was reconstructed, hash-verified and imported locally;
this is an API-assisted fetch, not a successful full-history network fetch.

Remote Windows checks at `78c1521` retain credential namespace/user-data isolation,
Windows filesystem URL fixes and graceful native harness shutdown. These changes
were already present in PC history (`14f3358`) and remain intact.
Remote documentation at `606118a` corrects obsolete historical game paths and
labels the old 10.2 master notes. These missing fixes are reconciled here, with
current protocol references updated to `10.5-discord2`. Historical 10.2 release
text remains verbatim. Other existing branches and PR 3 are preserved.

## Source hygiene and validation

`.gitattributes` has text/binary rules and no LFS filters; `git lfs track` reports
no patterns. No tracked file exceeds 50 MiB. Existing ignores exclude native SDK
downloads, node_modules, Godot caches, private environment files and local builds.
The two tracked cloudflare-paste SQL files are existing schema/setup source,
not private database exports. No credentials, user recordings or caches were added.
Pinned native dependencies remain installed locally and reproducible through the
existing setup scripts rather than committing SDK caches.

Godot 4.6.3 editor import exited 0 with no script/parse errors. Coordinator
typecheck/build passed; all 49 tests passed. The existing Windows root-certificate
store warning remains unresolved and is not counted as production TLS validation.
See VALIDATION.md and PC_WINDOWS_VALIDATION.md for historical tests and remaining
real Discord, credential-store and separate-PC/direct/TURN acceptance gates.

This baseline changes source documentation only. No services, credentials,
database schema/data, releases or default branch were changed.
