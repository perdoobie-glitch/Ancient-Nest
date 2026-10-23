# Windows setup validation

Base: `e0bf594ed299a3eed7c8b070e09befe3a05a7137`, protocol `10.5-discord1`.

## Source and preservation

The exact GitHub archive was downloaded on Windows. All 2,997 source files match the GitHub blob manifest (11 command files use the CRLF conversion specified by `.gitattributes`). Exact blob, tree and commit objects were reconstructed from the archive and GitHub API and verified cryptographically. The local setup branch started at the exact pinned HEAD with a clean status. This is a shallow API-assisted checkout, not a successful network clone or a local backup of all remote history; fetch full history when command connectivity is restored.

Before setup, 2,832 files from older game projects, relevant desktop shortcuts, artwork and Godot save/settings folders were archived outside Git. All archived entries were hash-verified and six representative files restored successfully. Credentials, Wrangler state and private secret locations were preserved in place, not printed or exported into source. No project copies, recovery archives or shortcuts were removed. The missing earlier Reforged commit remains a reason to defer retirement of possibly newer copies.

## Fixes

- Decode filesystem URLs using `fileURLToPath` in coordinator tests. URL `.pathname` produced invalid Windows paths, especially under directories containing spaces.
- Shut down the loopback coordinator through a private stdin pipe before the native harness removes its own temporary files. Windows process termination bypassed Node's SIGTERM cleanup and left workerd holding SQLite files. Success is now printed only after process and temporary-directory cleanup completes.
- Give the game its own `AncientNest-Reforged-2026-10-23` user-data directory and `net.ancientnest.reforged20261023` OS credential namespace. Older builds' saved settings and credentials are not automatically loaded or cleared. Public game branding remains Ancient Nest.

## Fresh automated Windows results

- Locked accounts and coordinator dependency installs: passed, without dependency links.
- Accounts: 51 tests passed against local D1 and mocked providers.
- Coordinator: TypeScript check, bundle and all 37 tests passed, including the actual local account-Worker integration.
- Godot 4.6.3, native Discord binding 5.0.0, keyring 1.0.0 and matching Windows release template: downloads verified against the pinned checksums. WebRTC DLLs match the source manifest.
- Native SDK/PKCE/scope/call-isolation fixture and auth startup/session/storage-failure fixture: passed with isolated test AppData. These do not authorize a real Discord user.
- Full game imports without script errors. Account UI test passed. Objective regression suites passed 64 and 198 checks.
- Two real native Godot processes reached one local WebRTC match, two actors and exactly one elected host. The corrected harness exited 0 after cleanup. This uses loopback-only guest QA; production guest mode was not changed.
- Full Windows game export, required runtime DLL/license packaging and ZIP integrity checks: passed locally. Exported headless startup exited 0. No artifact or executable was published.

## Gates still open

The coding process cannot read the Windows root certificate store. Its real keyring write failed with "A specified logon session does not exist." These are unresolved environment/native gates, despite the successful mocked fixture and executable startup. Repeat the real credential-store round trip and HTTPS/game startup in the interactive Windows owner session. Do not disable TLS validation or add a plaintext credential fallback.

The handoff's canonical Games directory could not be created from the coding process. Source remains staged pending an owner-created folder or an approved alternate location. Earlier projects and credentials remain untouched.

Cloudflare command connections return EACCES even with IPv4-first. A separate owner-session inspection is required to complete browser authentication, inspect active bindings and migration history, export production D1 privately, and perform an isolated restore drill before any remote migration. No production migrations, deployments, secret changes or resource renames were performed during these checks. Never commit private SQL, secret values or saved sessions.

After reviewing the actual schema/history, reconcile the earlier local browser-login migration with the pinned source's Discord/provider and ranking migrations. Preserve existing data and IDs. Configure missing secrets privately and verify the correct identity/profile/rating/result contracts before changing the master's account URL. Deploy accounts and the matching 10.5 coordinator in a coordinated step; old 10.2 clients must not be claimed compatible with 10.5-discord1.

Still required live: real Discord consent, editable username association, restart/session restore, revoked/expired access, logout, microphone/lobby/team isolation, and Discord friends-call coexistence. Two physical PCs on separate internet connections are required for real NAT/TURN, 1v1 search/vote/admission/gameplay/result persistence/reconnect/host-loss checks. Positive teammate voice and larger playlists require enough distinct players; two local processes do not certify those behaviors. Publish no executable until the required live and Windows gates pass.
