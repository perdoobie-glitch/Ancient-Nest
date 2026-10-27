# Unified integration validation — 2026-10-23

Current update: [terrain, weapon caches, staged combat and story verification, 2026-10-26](docs/CAMPAIGN_TERRAIN_STORY_AND_CACHES.md). Separate City-Ambush-based worktree, denser motorcycle hazards and mounted ducking, physical elevation throughout levels 3–9, durable randomized weapon pickups, and 15-second opening/ending scenes. The [initial nine-mission validation](docs/CAMPAIGN_NINE_VALIDATION.md) and entries below remain historical evidence.

Newest private update: eight-round Naki pistol, richer city/army departure base, forest trail props and concealed Annu ambushes. [Details and local checks](docs/CAMPAIGN_CITY_AND_AMBUSH.md). Build: `C:\Users\Corey\Games\AncientNest-City-Ambush-20261025`; reopen **Ancient Nest - Take back Home** after export.

Latest expansion: [base/maze/physical loot validation](docs/CAMPAIGN_EXPANSION_AND_LOOT.md). Full main-route movement and climbing, staged Annu, physical loot and carbine sweep checks pass. Four native clients pass 39 progression/pickup checkpoints. Live matchmaking and production deployment remain outside this verification.

Latest source: [forest, ship, contact physics and gameplay fixes](docs/CAMPAIGN_FOREST_AND_GAMEPLAY_FIXES.md). Actual recorded quit/completed Films and rendered previews pass; the input walkthrough clears the tutorial, charge recovery and first real wave. Four-client campaign progression passes. Live matchmaking/WAN remains unverified. Four launcher landing failures reproduce with the untouched actor and are documented separately.

## Changes verified locally

Current follow-up removes dedicated sprint from actor speed, controls, tutorial,
RPC actions and replicated state. Legacy saved sprint evidence is accepted only
for migration and discarded on restore. Tutorial waypoints and floating station
labels show only the current local step. Isolated guidance/state/mission and
movement-controls regressions pass; see the current campaign guidance handoff.

The [landscape/structure pass](docs/CAMPAIGN_LANDSCAPE.md) records actual rendered
intro and input-route tests, new terrain/structure/trunk-occlusion checks and
failed rehearsals. Creation took roughly 20 minutes; test corrections extended
the requested 10-minute testing block. No human playthrough or narration quality
is claimed from these fixtures.

Guided Connectuct follow-up: [CAMPAIGN_GUIDANCE.md](docs/CAMPAIGN_GUIDANCE.md)
records tutorial/boarding changes, damaged-atmosphere rendering, corrected quality
levels, actual High/Low renderer samples and outstanding actor/audio validation.
Local speech file generation was denied; no voice asset or human performance is
claimed. Cue integration uses reviewed recordings when present, otherwise local
OS speech when available, with subtitles always preserved.

Campaign materials/performance follow-up (2026-10-25): see
[CAMPAIGN_VISUALS.md](docs/CAMPAIGN_VISUALS.md) for the exact before/after renderer
table, methodology and limits. Scenery/route equivalence passed 24 checks across
High/Low quality; campaign state/UI, mission/spawn/combat and all 36 four-client
ENet checkpoints passed. Forest scenery draw calls fell 74–81% in three fixed
views with added detail. These short uncapped scenery samples do not establish
sustained full-game FPS or physical-PC co-op performance.

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

## Windows dashboard follow-up — 2026-10-23
The canonical Windows checkout passed the dashboard layout test at four resolutions, real OpenGL rendering with mock friend data, Discord invite routing mocks, one-use voice handoff mocks and unified-account UI regression tests. The restricted test identity still cannot read the Windows root certificate store; these UI tests make no production network claim.

Owner-session deployment results independently confirmed accounts health/readiness, Discord configuration/readiness and game username capability at source ac11f050b15a0efd15cb0c17233b2dd5105ca6fb. Earlier environment-limit paragraphs above describe the original integration environment, not the subsequent owner-session deployment. Real two-account invitation delivery/acceptance, audio isolation and cross-internet matches remain required. This dashboard update changes client UI only. No executable or release was published.

## Global Discord dashboard follow-up — 2026-10-23
The matchmaking coordinator passed typecheck/build and all 38 tests, including new private lobby admission, leader-only changes, invalid capabilities, rotation after departure and search restrictions. Native Godot mock tests passed I/Escape across eight screen states, text-field typing, private request approval, open auto-replies, explicit invitation acceptance and capability forwarding to the master. Real OpenGL mock screenshots were inspected at desktop and compact sizes. Unified-account UI, voice handoff and existing invitation regressions passed. These do not establish real provider delivery, live private-lobby admission or two-PC play. Production coordinator deployment remains a separate owner-session step; no executable was published.

## One-click invite acceptance — 2026-10-23
Removed the second game confirmation after the user clicks Join in Discord or Accept in the inbox. Mock tests verify immediate master routing, private capability forwarding, duplicate SDK event suppression and refusal during search/match. This client-only change requires restarting the updated receiving client; no server deployment is needed. The owner-session coordinator deployment of 2321014 completed with verified private backup and HTTP 200 health/readiness, including lobby privacy capability. The user reported live invite delivery; live acceptance into a party and WAN gameplay remain unverified.

## Remembered age and menu readability — 2026-10-23
Age-policy tests passed first-launch blocking, declaration persistence, startup skip, invalid-policy fallback and decline locking. A separate mock-authentication test passed migration of a valid earlier saved login and rejection of invalid/missing saved logins. Account UI and voice handoff regressions passed. Menu artwork now fits its available area to show the full scene width; transparent bottom controls remain. Settings search placeholder uses a darker explicit color. Both menu and settings native OpenGL previews were inspected. Real owner-session saved-login migration remains to be tried after restarting the updated client.

## Falling, airborne presentation, controls and Sanctuary — 2026-10-23
Passed: `falling_and_weapon_controls.gd` exercises actual movement steps at 60 Hz, verifies the unchanged ascending arc/apex, 1.10 falling acceleration in normal and replay calls, upward external impulses, no airborne bob/stride, direct keyboard inventory selection, host rejection of invalid slots and saved-binding migration. `model_locomotion.gd`: 25 checks, zero failures. `combat_geometry.gd`: 10 checks, zero failures. `movement_parity.gd` completed 600 simulated ticks (movement, braking, wall contact, jumps, air crouch and landing); this is local simulation, not WAN certification. `sanctuary_vaults.gd` passed all vault/shared-resource/other-map checks. Cosmetic weapon transitions passed.

Sanctuary map audit: 466 → 342 batches, 3537 source meshes in both, 79,956 triangles in both, 1,837 collision bodies in both. Native Windows GTX 1660 Ti short 960×600 route runs showed last-frame draw calls 635 → 561 and median frame interval 14.892 → 10.377 ms. These were single short sequential runs with one actual actor; shader/cache warmup and changing effects prevent attributing the entire FPS difference to batching. No sustained FPS or multiplayer load claim is made.

Limits/failures: the historical `traversal.gd` fixture failed its old J1 route then accessed a missing bot; it does not follow the current scaled map/bot settings. `v16_jump_height.gd` failed old 15%-increase and gravity constants (expects gravity 8.14065237, whereas the pre-change committed tuning is already 9.361750225500). These were not counted as passes or rewritten to hide failures. The new current-baseline apex test passed. Live Sanctuary routes, sustained performance, and two-PC movement remain to test. No executable published.

## Match formation and TURN failure recovery — 2026-10-24
A reproduced coordinator defect removed both selected players from the queue before TURN credential creation. A rejected provider request could leave the first player on a stale 1/2 count and the second on 0/2. Formation now validates supported relay credentials first, stops the affected parties' searches consistently on failure, broadcasts a sanitized error to both players and logs only stage/reason/HTTP status. It never logs keys, credential response bodies or temporary relay passwords. Initial probing reuses the fetched credentials; refresh failures terminate the staged room cleanly.

The new production-authenticated/mock-provider regression failed against the previous bundle and passed after the fix. It covers provider HTTP 403, both parties returning to non-searching state, redaction, recovery after provider repair, and exactly one credential request per successful initial match. All 39 coordinator tests, typecheck and build passed. `/ready` adds `formation_recovery:true` for deployment verification. This is a server-only fix compatible with the private-test ZIP. Deployment and the live provider status/two-PC result remain separate checks.

## Player-host first-person camera resume - 2026-10-24

The owner reported two real PCs entering a match, with the elected player-host left on an overhead view. The local joining client's log recorded `HYBRID RUNNING epoch=1 local=2 authority=false actors=2`. This establishes match entry, not fully verified gameplay or relay-only connectivity.

Reproduced locally: actors initially select their first-person camera; while simulation is frozen, the matchmaking loading UI selects the overhead menu camera. The host's resume rebuilt the gameplay HUD without reclaiming its camera. `network_match_started()` now reselects the existing local player's camera on initial presentation and resume. No network protocol, account data, or Worker settings are changed by this source fix.

`game/tests/matchmaking_camera_resume.gd` failed the host/client camera-resume checks before the fix and passed all six checks afterward on Windows Godot 4.6.3 headless. It covers a host in roster slot 3 (transport peer 1), frozen loading UI takeover, host resume, client resume, and HUD presentation. The environment also emitted a system root-certificate-store read error; this local presentation test performs no provider/network validation. The currently running older export is unchanged. An updated client and live two-PC camera verification remain required; no executable has been published.

## Repeated bullet failure and mirror-team capes - 2026-10-24

Reproduced a persistent shot-exclusion defect: `launch_bullet` passed the actor's cached RID array by reference. Sniper penetration appended the victim's anatomy RIDs to that array, so subsequent bullets from the same shooter ignored that victim until the cache was rebuilt. A regression with a sniper hit followed by a rifle hit failed two checks before the fix and passed all three after copying the array for each bullet. The fix applies to authoritative and cosmetic bullets and preserves each sniper bullet's own penetration list. This explains a possible cause of the reported one-way/random damage; the exact two-PC report still requires a fresh build and live retest.

A new real two-process ENet test passed 11 host and 9 client checks: initial host damage, another sniper hit after respawn, replicated client death, and client-to-host damage. A local two-native-client matchmaking/WebRTC run also elected one host, consumed one host sniper round, advanced its score, and replicated the joining client's health from 100 to 0. These are local transport checks, not WAN/relay-only certification. The older `network_combat_authority.gd` fixture failed unrelated initial weapon/protection assumptions; its exploratory modifications were removed, and it is not counted as passing validation. New test processes use isolated APPDATA.

Mirror matchups now use red/green capes and matching team labels/scoreboard colors. Original cape geometry, fabric texture, roughness and other armor finishes remain. Eight material checks passed for both character types and restoration of original cloth when teams become mixed. Six camera-resume checks still passed. Godot's headless environment emitted a root-certificate-store warning, which does not establish provider health. `git diff --check` passed.

A separate Windows private test export succeeded at Desktop/AncientNest-CombatFix-20261024, with required native DLLs and licenses. No executable was published and no cloud settings were changed for this repair. Live repeated-hit, respawn, two-way damage and cape checks are pending. The requested server browser remains a separate follow-up, with its scope question (custom servers, matchmaking parties, or both) awaiting an answer.
## Main-menu server browser and default physics - 2026-10-24

Added Server Browser directly to the main navigation, retaining the existing menu artwork and style. It lists authenticated public waiting custom lobbies with owner, map, game type, matchup and player count. The creation form chooses a name, mode, map, matchup and 2-10 player limit. Join enters both teams' shared custom lobby; only its owner can start after at least two members join. The existing signed-admission WebRTC transport elects the player-host. Private, disconnected and active lobbies are excluded from public listings. Full-lobby admission and owner-only actions are enforced by the coordinator, independent of client controls. Custom matches bypass account ranking registration/jobs/reports and return to their lobby after the eight-second results interval.

New GameTypeSettings and official presets default to movement 110%, gravity 145%, jump height 125% and air control 115%. The user's final air-control instruction replaces the unfinished explosion-knockback request; knockback remains 100%. Explicitly saved custom types retain their stored values. Network settings transmit the selected physics to every peer.

All 40 coordinator tests passed, including the new browser admission/start coverage, together with typecheck/build. An expanded custom completion regression then passed after suppressing ranked-review messages for custom results. Eighteen native UI/settings checks passed at 1920x1080, 1280x720 and 640x480; real OpenGL menu/browser/create-form screenshots were rendered and inspected under .cache/ancient-nest-browser-qa. The movement/control simulation test passed. Two native Godot clients created, joined and started a custom lobby through local WebRTC with exactly one host, two actors, Annu/Annu teams and physics [110,145,125,115]. This is local QA; a cross-internet two-PC browser/physics test remains required. The known headless root-certificate warning persists; no credentials were changed by these tests.

Production matchmaking source was deployed through the already authenticated Cloudflare dashboard because Wrangler's expired token could not refresh over the shell network. Previous deployment edfb5085 remains in Cloudflare version history. Initial browser deployment 08aaf1b5 was followed by final custom-completion deployment c8df134e, observed Active / Latest with Version saved. Bindings, secrets and migration history were preserved, with no database migration. Bundle SHA256: 387F95ADE0517457E03EF1DF9259C882ABDA59A4D5389027CB99A6A2B1F5125D. A later navigation string accidentally entered the editor buffer was undone and never deployed.

Private Windows export succeeded at Desktop/AncientNest-ServerBrowser-20261024. The ZIP contains the executable, native/Discord DLLs, licenses and instructions, verified by opening the archive. ZIP SHA256: 630B7E07FA188E90A13C02A291AFB1A9F33C88FF8EA56972FC99DBFEE7DACDF4. This includes the prior bullet/cape/camera repairs. No public executable release or Git push was made. Both PCs need this complete build for live testing.
Production readiness was then read in the browser: ready=true, server_browser_supported=true, accounts authentication enabled, and coordinator/account-bridge/TURN/monitor configuration flags all true. These flags confirm configuration presence, not successful relay allocation or a WAN match.

The new exported Windows game was launched on the user's desktop. Its existing signed-in profile reached the updated main menu; clicking Server Browser connected to the production master, enabled Create Lobby/Refresh and displayed the live empty-lobby result. This confirms a real authenticated directory read from the exported client, but does not establish live two-player creation/join or combat.

## Menu/network playtest and measured snapshot cadence - 2026-10-24

The main menu now places the existing transparent navigation controls over full-viewport artwork. The empty lower strip was caused by artwork ending 180 pixels above the bottom, not by the navigation PanelContainer (which already used StyleBoxEmpty). Removing that reserved strip and using aspect-cover keeps the picture behind the controls. An OpenGL capture was inspected at .cache/ancient-nest-playtest-qa/main-menu.png. The browser creation form also preserves entered values when an in-flight directory response arrives.

Twelve local ENet experiments compared 20/30/60 Hz snapshots for two and ten actors, each on a clean loopback link and a UDP proxy adding 25 ms each direction, +/-12 ms jitter and 2% independent datagram loss. Physics and client input stayed at 60 Hz. Startup was excluded with a warmup; host serialization, payload size, interpolation buffer and extrapolation counters were recorded. The initial un-warmed run showed why startup-biased Performance monitor samples should not be treated as steady frame costs.

For two actors, median remote interpolation buffers were 75.0/53.7/36.9 ms (clean, at 20/30/60 Hz) and 93.1/77.9/56.3 ms (impaired). Mean snapshot encoding was roughly 0.32-0.35 ms; host frame p95 was about 3.4-4.1 ms. Snapshot payloads were approximately 22/32/65 KiB/s per recipient. These are local buffering measurements, not reductions in network RTT or measured WAN click-to-photon latency. Ten-actor 60 Hz payloads were about twice 30 Hz, with nine-recipient payload estimates of about 7.5 vs 3.6 Mbps before protocol/encryption overhead; observed frame costs varied under that AI load. The measurements do not justify forcing 60 Hz on every eligible host.

The coordinator now selects a bounded snapshot cadence from every outgoing recipient route, player count and measured CPU headroom. Sixty Hz requires CPU p95 <=8 ms and at least 1.2 Mbps per outgoing route for a duel, or 2 Mbps for larger rooms. The fallback is 30 Hz; six-or-more-player rooms below 0.9 Mbps per route retain 20 Hz. Admission requirements remain intact. Candidate-specific choices survive a backup-host change; the host sends the selected interval to clients and checkpoint-restored peers. Client interpolation retains adaptive jitter buffering with cadence-appropriate minimums. Older hosts lacking the new configuration field retain the original 20 Hz assumption. Simulation, input sequencing, weapon cadence and movement constants remain at 60 Hz.

The native lifecycle harness first reproduced defects rather than merely confirming menus: custom rooms lacked the build marker used for reserved-match lookup; reconnects could lose party metadata; explicit departures were treated like dropped connections; odd custom rosters were rejected as invalid checkpoints; and a reused CryptoKey produced reload errors. Repairs preserve transient disconnect reservations but record intentional departure, restore metadata, accept correctly sized odd rosters with a vacant team slot, replace signing-key objects safely, and avoid sends/removals on closed or missing WebRTC peers.

The final native run passed all 26 lifecycle checkpoints using real WebRTC clients and the loopback coordinator: public discovery, create/join, a third player, owner transfer, first-person views, odd-sized checkpoint commit, results returning to the same lobby, a second start, dropped-client rejoin, clean mode change after leaving, Search/Cancel, 1v1, two intact 2v2 parties, a committed checkpoint, host migration to the remaining three-player majority and the original host returning as a regular player. The final logs had no signing-key parse, closed-channel send, missing-peer removal or GDScript errors. Source-native fixtures bypass the provider only on loopback QA; they do not prove live Discord/WAN behavior.

All 41 coordinator tests and final typecheck/build passed. Thirty-one checkpoint tests, six signing-key replacement tests, twenty menu/browser/settings checks, Discord dashboard layout/filtering checks, six camera-resume checks and both-direction repeated sniper/respawn combat tests passed. Known headless root-certificate-store warnings remain, while local tests and rendered QA succeeded. Reports are preserved under .cache/ancient-nest-network-playtest-20261024 and the reproducible scripts are scripts/network-rate-playtest.mjs and scripts/lobby-lifecycle-playtest.mjs.

Production coordinator deployment cb1a4573 was observed Active/Latest with Deploy disabled after saving, replacing c8df134e which remains available for rollback. No bindings, secrets or database migrations were changed. Worker bundle SHA256: 319DBA5DC653EE46034996E995A840FDFE7BDA5DF24859099474A89BD7007524. Native Windows export succeeded at Desktop/AncientNest-Playtested-20261024; archive contents were verified. ZIP SHA256: 9AB2A62FEA0B845109902E3271CEDF83189588E9746366A6346CDD1326ABD4B7. EXE SHA256: 0D8B01FE228E101E7B10C08857A2B749607AEF643717A9BE64F5FD1F268FA608. This is a private test artifact; no executable was publicly published and no Git commit/push was made. Separate-PC internet and relay-only verification remain pending.
Live verification limit: the dashboard's deployment page showed cb1a4573 with 100% configured traffic, but /ready (including a fresh query URL) still lacked adaptive_snapshot_rates. The current public endpoint remained ready=true with account mode and prior capabilities. The last dashboard attempts failed with computer-use request timed out: get_window_state, including screenshot-only recovery. No further blind UI inputs were made. Production runtime propagation/binding/version verification and a real two-PC test remain open; do not infer public activation of the new behavior solely from the dashboard's Active label. The private-build instructions record this limitation.

The package was re-zipped after adding the production-verification limitation to its instructions. Final ZIP SHA256: 27A581267B91FA0C67AD1BF9BA622A8B2B11C2A32B9CFEFB04C2E6A6A1C7987F. The exported game's startup log also contained two engine-level can_process/is_inside_tree messages without a script stack; no gameplay failure was established from these messages. They remain an uncharacterized startup diagnostic, not counted as a clean exported-client log.

## Player-host authority hardening (source only, 2026-10-24)

Protocol is now `10.5-discord2`: client and coordinator must be upgraded together. No production deployment, credentials, bindings, database or existing private executable were changed for this work.

Existing input prediction, numbered acknowledgements/replay, immediate collision reconciliation with visual correction, bounded remote extrapolation, host-owned combat/objectives, signed epoch/match-scoped admission, native WebRTC direct/UDP TURN fallback and accounts/Discord remain in place. Added a rendering-independent authority admission/timing policy; bounded action queues and command lead; input/action/shot/melee/grenade/flight token buckets; action deduplication and sender/life/round/session checks; aim checked against host-recorded command aim; and a second cadence clock so forged sequence gaps cannot accelerate firing. Local firing now binds to the upcoming input because fire precedes movement recording in a physics tick. The host still uses the same weapon/movement rules for its own player.

Simulation stays fixed at 60 Hz. Automatic snapshot selection is 20 or 30 Hz before a match, without live rate switching. The rate experiment can explicitly request 60 Hz snapshots; it does not change simulation Hz. Adaptive interpolation is bounded to 75–200 ms, normally 75–100 ms. Hitscan rewind defaults to at most 150 ms (`maximum_hitscan_rewind_ms` is configurable down to zero). Nonce-bound host RTT samples supply one-way clock correction and rewind latency. A bounded rendering-delay declaration is checked against measured jitter; arbitrary shot timestamps do not control rewind. Host-observed action queue time is included. Traveling plasma/projectiles/explosions do not use hitscan rewind. Static current cover remains in the physics query; historical sealed objective cover and registered `network_rewind_blocker` bodies are also checked. Non-annotated convex changing cover uses a conservative bounding box, which can reject an edge shot. Future moving/destructible cover must be registered; do not assume unregistered geometry has historical collision.

Rewind trades shooter responsiveness against victims being hit after reaching cover, within the configured ceiling. Player hosting retains host advantage. A modified host can falsify simulation/results; signatures authenticate identity/admission and peer agreement is not proof of honest play. Local perspective recordings likewise must never be treated as proof of legitimate gameplay.

`Allow my PC to host online matches` is saved under Controls, advertised in capacity reports, enforced by election/migration and checked again by both native listener paths. Election still considers all measured routes, worst RTT, jitter, loss, outgoing headroom and CPU. Host capacity uses measured simulation spans during play, with process/physics admission samples before play. These are estimates, not a guarantee of CPU/upload headroom on another PC.

Packets retain compact batched/redundant inputs, replaceable sequenced state, independent reliable events and periodic full compressed baselines. Snapshot fragments are bounded to 850-byte application chunks and 24 chunks per snapshot. Full state is intentionally retained for the small arena roster; no dependent delta stream or speculative visibility culling was introduced. Gameplay does not use matchmaking HTTP endpoints. ENet diagnostics now count actual transport bytes/packets in both directions and rates; these are ENet counters, not Ethernet/IP overhead. The pinned WebRTC extension does not expose native wire counters through its Godot API: complete live WebRTC wire-byte accounting remains open. Do not label compressed snapshot bytes as actual WebRTC bandwidth.

Validation: 24 authority-policy assertions and four historical-cover checks passed; the full two-process netcode fixture passed all 22 checks on clean loopback and with 25 ms each-way delay, +/-12 ms jitter and 2% UDP loss. The impaired run accepted 24/24 compensated magnum shots (23 hits) and 24/24 automatic shots; four predicted jumps were performed once by the host; movement/knockback/stall/lift convergence was below 3 cm. Repeated sniper/respawn damage passed in both directions. Native WebRTC lifecycle passed all 26 checkpoints including custom games, 1v1, two intact 2v2 parties, reconnects, checkpoints, host migration and old-host rejoin. These are local fixtures, not separate-PC internet/relay certification. The legacy `physics_playtest.gd` failed old jump/shield/damage assertions and then accessed a missing damage-accounting field; it is not counted as passing and was terminated after the script error. Gameplay constants were not changed to satisfy that obsolete fixture.

All six 20/30/60 Hz snapshot experiments with ten simulated actors passed state/snapshot checks. A focused 30 Hz repeat measured complete simulation-span p95 of 6.43 ms clean and 8.134 ms impaired, with zero/one >16.667 ms ticks respectively; broad process/frame cost was 10.156/21.363 ms p95. Snapshot encoding averaged 0.82/0.91 ms. ENet host traffic for one real receiving client measured about 53 KiB/s outgoing and 7–9 KiB/s incoming; nine-peer payload estimates were 3.55–3.65 Mbps, not nine simultaneous measured links. No tested evidence here warrants silently lowering simulation frequency. Ten human clients, varied CPUs, actual upload saturation and cross-internet relay-only matches remain unverified. Reports: `%TEMP%/nest-authority-ebrtcY`, `nest-lifecycle-15HNBg`, `nest-rate-playtest-INe0uc` and `nest-rate-playtest-mMlAYy`. Reproduce with `node scripts/network-authority-playtest.mjs network_netcode --impaired`, `node scripts/lobby-lifecycle-playtest.mjs` and `node scripts/network-rate-playtest.mjs`.

## Master traffic and individual films (source only, 2026-10-25)

Cloudflare already is the master: the existing Worker and SQLite-backed Matchmaker Durable Object coordinate discovery, queue ownership, reservations, host epochs, signaling and results. No second service was created. Accounts retain their existing D1/ranking policy and scheduler; no bindings, schema, credentials, production data or production deployment were changed. Gameplay continues over native WebRTC direct UDP/compatible UDP TURN, with ENet for direct/LAN fixtures. Gameplay snapshots are not sent through matchmaking HTTP.

### Communication settings

| Setting | Previous source behavior | Current default |
| --- | --- | --- |
| Match heartbeat | Each client sent heartbeat and JSON ping about once/second | One host every 20 s, plus coalesced immediate status changes |
| New-assignment host freshness | Socket liveness mixed with availability | 60 s since valid host update received by master |
| Non-host socket keepalive | JSON ping/heartbeat loop | 20 s native hibernation-compatible ping/pong |
| Visible browser refresh | Frequent UI-driven refresh | 15 s; immediate open; rate-limited manual refresh |
| Queue fallback | Push-dependent | Existing push preferred; 5 s HTTP fallback only while queued and push unavailable |
| Ordinary control timeout | Operation-specific | 10 s |
| Transient retry | Multiple operation-specific loops | Exponential jitter, cap 30 s; HTTP Retry-After respected |
| Simulation / input | 60 / up to 60 Hz | Preserved 60 / up to 60 Hz |
| Automatic snapshots | Earlier adaptive experiment could choose 60 Hz | 20–30 Hz selected before match; explicit 60 Hz remains benchmark-only |

Exact shared defaults: `game/data/network_defaults.json`, consumed by `game/scripts/control_policy.gd` and bundled through `matchmaking/src/control_policy.ts`. Godot physics remains fixed at 60 Hz in the project and match implementation: changing the JSON simulation target alone is not a tested lower-rate mode. Rewind ceiling is `maximum_hitscan_rewind_ms` in `game/scripts/match.gd`. Production bindings/deployment configuration remain `matchmaking/wrangler.jsonc`; regenerate `matchmaking/dist` with the package build after changing shared defaults.

The host scheduler is `master_scheduler.gd`; HTTP queue recovery is `queue_fallback.gd`; bounded persistent results are `pending_results.gd`. Browser scheduling/generation guards live in `matchmaking.gd`. Existing WSS remains responsible for ICE/signaling. The queue HTTP fallback authenticates a short-lived scoped ticket and does not provide replacement signaling. Ordinary players need no router configuration for the Cloudflare/WebRTC path.

Host updates use a short-lived private grant, sender identity, authority epoch and monotonic revision. Liveness uses receipt time. Listing and allocation reject stale hosts before cleanup; serialized DO allocation checks fresh ownership/capacity. Superseded sockets, old search tickets and old-room cleanup cannot overwrite a new assignment. Hibernation automatic keepalives do not extend an unauthenticated connection's admission deadline. Deadline-driven alarms replace the perpetual one-second cleanup alarm; unchanged room state is not repeatedly stored. Monitor metrics are per-activation counters, not billing totals.

Control outages preserve healthy existing gameplay through signed, expiring majority statements over the gameplay connection. These cannot elect a new epoch or admit new players. Master migration fences the previous epoch and waits out possible authority leases before replacement. Loss of the actual host still freezes play; a two-player match cannot manufacture a migration majority after losing one player. Heartbeat expiry alone does not elect another host. Authentication rejection stops blind reconnect; temporary failures use bounded backoff. Native WebSocket upgrade failures do not expose Retry-After headers through the pinned SDK; HTTP fallback and account-job retries do honor that header.

Results retain unique match IDs, participant authorization, consensus and existing account idempotency. Local pending results are account-scoped, at most 16 entries, with 32 completion markers and a 24-hour load retention. Account writes run asynchronously with bounded retries; permanent validation/auth failures are not retried blindly. A player host remains untrusted: identity authentication and agreement do not establish honest simulation or justify dedicated-server trust.

### Measurements and estimates

Fake-clock tests measured three periodic host heartbeats in a simulated minute, no participant duplicates, prompt/coalesced status changes and bounded timeout/backoff behavior. Coordinator typecheck/build and all 48 Node tests passed, including reservation/capacity, queue cancellation/reconnect, old-epoch rejection and result idempotency. Godot master-control passed 18 assertions; authority policy 24; historical blockers four; server-browser menu/layout/rules checks 20. Local native lifecycle testing includes custom lobby ownership, reconnects, 1v1, intact 2v2 parties, checkpoint migration and a six-second control outage with an injected two-second lease. It is not a measured full-length provider outage or internet certification.

Estimated periodic volume: 20 s = 180 host heartbeats/hour, 129,600 over 30 continuously active days, or 1,296,000 for ten matches. These are logical WebSocket messages in this implementation, not one HTTP request per heartbeat and not a billing estimate. Nine non-host keepalives add 1,620 messages/hour for ten players. The former two messages/second/player would be 72,000/hour versus 1,800/hour for that periodic class now. Discovery, auth, retries, results, status events, storage and necessary two-second migration checkpoints/acknowledgements are excluded. Checkpoints remain on WSS because migration needs them; compact control messages and removal of redundant checkpoint echo reduce duplication without removing that required transport. No production request count or billing reduction was measured.

With recording enabled, a separate focused 30 Hz loopback run with ten simulated actors and one actual receiving peer measured simulation p95 8.782 ms clean / 8.925 ms impaired, one overrun each, encoding mean 0.874 / 0.894 ms, and capture mean 0.855 / 0.905 ms per recorded sample. ENet outgoing totals were about 49,822 / 72,567 bytes/s, incoming 6,998 / 9,158 bytes/s; payload-only nine-route estimates were 3.50–4.10 Mbps. Reports: `%TEMP%/nest-rate-playtest-gPLoy0`. Different runs/system load prevent claiming a controlled before/after performance improvement. Control handler CPU spans, master request latency, simulation spans and gameplay RTT are reported separately; reduced control traffic does not automatically reduce gameplay ping. Full WebRTC wire bytes and a controlled master-request frame-spike experiment remain unmeasured.

### Films

Main menu Films opens asynchronous archives with all participant names/teams, configurable previous/next bindings (PageUp/PageDown defaults), free camera and recorded/reconstructed first-person views. Perspective switching preserves time/speed/pause. Local camera, FOV, weapon presentation/recoil/reload, health/ammo, HUD preferences, recorded radar contacts and hit/sound events are timestamped at 29 samples/s with events between samples. Recorded aim controls the camera. Seeking/reverse stop effects; forward playback emits only events crossed once. Missing/late/disconnected tracks are labeled unavailable or Reconstructed View. Reconstructed HUD does not scan authoritative enemies for radar/hover information.

Implementation: `film_archive.gd`, `film_recorder.gd`, `film_transfer.gd`, `film_viewer.gd`. Archives and temporary tracks share `user://films`, seven-day/2 GiB cleanup, a 256 MiB per-film limit, 32 MiB per-track limit, ten participants and one-hour duration limit. Primitive-only compressed blocks are checksummed and bounded. Disk/compression/decode/export work is asynchronous. Recording can be disabled under Controls. Transfers use the authenticated participant transport after match end, a separate reliable channel, 850-byte chunks and a 256 KiB/s ceiling with per-frame batching. The old transport may remain only for film collection up to 30 minutes; gameplay RPCs are rejected, a new search releases it immediately, and unavailable tracks remain reconstructed. Early departure/new matches can interrupt collection. These interactive reconstructions are not screen recordings, pixel-perfect reproductions or trusted anti-cheat evidence.

Playback tests passed 25 assertions with ten actors, nine synthetic local tracks and one missing track, including both factions, switching, zoom/death/respawn, late availability, aim lock, free camera, radar, reopening and stepping. Actual two-process ENet collection passed 28 checks, including slowed transfers after return-to-menu and gameplay rejection. Report: `%TEMP%/nest-authority-hAKlz0`. The 2.2-second fixture measured 58/61 samples, 29,579/31,421 microseconds total capture work (~0.51 ms/sample), ~52–55 KB combined archive writes, and 11,284/15,563 perspective payload bytes transferred per direction; no dropped recording blocks or rejected chunks. These short runs do not establish one-hour sizes, ten simultaneous uploads or WAN throughput. Preview images were visually inspected with the native renderer. Custom Forge geometry fidelity and ten independent real player tracks still require local validation; authoritative snapshots alone cannot reproduce each original display.

Final regression repeat: all 28 native lifecycle checkpoints passed in `%TEMP%/nest-lifecycle-qN3Nog`, with no script/parse/closed-channel errors in its logs. Fixed an explicit fresh connection inheriting a prior playlist reservation after socket-close races; unexpected reconnect still preserves its party/queue. The dedicated two-case queue recovery regression passes alongside the 48-test full suite (one new test added afterward). Checkpoint state passed 31 checks after updating its obsolete immediate-failure timeout expectation to bounded reconnect; signing-key replacement passed six. Diff whitespace checks passed. Native headless runs emitted `Failed to read the root certificate store`; loopback tests do not validate external TLS. Diagnose the Windows trust-store warning before using these runs as any evidence about production connectivity; do not disable TLS verification.

## Campaign Mission 1 — Windows integration, 2026-10-25

Read all 23 sections through END OF INSTRUCTIONS from the fetched
`codex/campaign-master-instructions-2026-10-25` branch (`f2c4902`), with its
instruction blob and commit reconstructed and hash-verified locally. The
current PC baseline/network branch remained intact at `e8fd54a` / `4d71526`;
the instruction branch adds only the specification and does not replace the
newer game. A verified pre-implementation Git bundle preserves all branches.

Implemented Campaign entry with **Difficulty** (Easy/Medium/Hard/Angel), offline
entry after the existing age policy, the 120-second Connectuct timeline, personal
preparation, boarding, staged departure/crash, charge recovery/security, exact
3/5/6/8/12 waves, guarded radio/ending and versioned safe checkpoints. Direct
ENet co-op uses the existing actor/input/snapshot stack for up to four players;
campaign results do not enter competitive ranking. See `docs/CAMPAIGN_MISSION1.md`.

Actual checks:

- Coordinator typecheck/build and all 49 tests passed again.
- Isolated campaign state/save suite: 128 checks passed; mission integration:
  29 checks passed; UI: nine checks at 1920×1080, 1280×800 and 640×480 passed.
- All five prescribed waves have concealed, connected spawn candidates for
  every enemy. A maximum-wave fixture spawned twelve actual AI actors, observed
  37.38 m of navigation motion, four flashlight nodes and smoke perception
  rejection. Its last 180 simulation-span samples had p95 0.214 ms on this PC.
  This is a short headless fixture, with accelerated spawn staggering and
  protected test actors, not a human balance test, sustained GPU result or
  measured four-PC performance claim.
- Two-client and four-client native ENet mission runs passed 36 checkpoints
  each, including independent readiness, shared Difficulty, unanimous skip,
  actual remote movement after crash session reset, flashlights, down/revive,
  single charge recovery, disconnect/reconnect, wipe/retry, independent weapon
  consumption, all waves and one-time completion. Final four-client report:
  `%TEMP%/nest-campaign-62tGxn`; two-client report: `nest-campaign-gZEGjI`.
- Isolated regression runner passed accounts UI, falling/weapon controls,
  browser, heartbeat control, network policy, Film playback, age policy and
  mocked Discord dashboard. A stale dashboard mock was given its missing game
  reference, explicit playlist and no-op rich-presence method; no Discord
  provider behavior is claimed from those mocks.
- Regular multiplayer native lifecycle rerun passed all 28 checkpoints in
  `%TEMP%/nest-lifecycle-P4kNVI`. An earlier run rejected host migration for lack
  of a fresh checkpoint/majority; it is recorded as a failed run, not hidden or
  counted as acceptance. The later run passed without relaxing authority rules.
- Godot import/parser checks passed. Five real OpenGL 1280×800 captures were
  inspected: campaign menu, Connectuct intro, preparation, crash and playable
  forest. Captures are in the private local implementation checkpoint folder.
- Private Windows release export and executable startup exited 0. The packed
  game also passed an intro-to-preparation campaign smoke fixture using the
  pinned console engine. Debug extension DLLs were included locally for that
  packed-resource check. No executable, archive or release was published.

Early implementation checks caught and fixed blocked navigation/spawn candidates,
stale retry revisions, input sequencing after world changes and visibility/
readiness distinctions. One native test start overlapped an editor cache rebuild
and failed to resolve new global script classes; the import and quiet rerun then
passed. Do not run imports/exports concurrently with source-based native tests.

Test isolation incident: a legacy controls-migration test was initially run
against live APPDATA and replaced the local preferences file with its fixture.
An older profile and the overwritten fixture are preserved privately for
recovery; exact latest settings could not be reconstructed. Restoration is
pending the owner's choice. Further tests use isolated profiles, and the two
preference-writing legacy fixtures now refuse to run without the isolated-QA
flag supplied by the runner. No credentials were printed or rotated.

Missing/unverified: recorded narration and final environment art; manual
end-to-end tutorial/combat balance and 30–40 minute pacing; long-session
performance/memory; two/four physical PCs and WAN direct/TURN acceptance; live
Discord/audio and native credential/TLS acceptance. Campaign co-op currently
uses reachable-host ENet, not automatic TURN. Campaign Film recording and host
migration are unsupported. Existing root-certificate warnings remain; TLS
verification was not disabled. No production deployments, schemas, credentials,
default-branch merges or releases were changed.
