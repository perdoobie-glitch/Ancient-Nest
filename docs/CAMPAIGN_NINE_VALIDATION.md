# Nine-mission campaign validation — 2026-10-26

Baseline research verified the owner's selected `AncientNest-City-Ambush-20261025/SOURCE_REVISION.txt` against clean source commit `59f005c3dcf3caed2f938c9d44098776c426d7e4`. Both original desktop shortcuts pointed at that export. All edits were made in the separate `AncientNest-Campaign-2-9-20261026` worktree. The earlier build, source branch, credentials and legacy campaign save are preserved.

The campaign uses the existing Naki and Annu rigs and existing Anki, Brutus, Ancient AI and Relay. It adds 34 stages across eight missions, 14 optional surviving records, opening machinery interlocks, replenishing supplies, physical weapon loot, and the three-actuator Ancient AI machinery encounter. Mission 1 remains the existing City-Ambush mission. See [story and environments](CAMPAIGN_NINE_MISSIONS.md) and [progression/save details](CAMPAIGN_JOURNEY_VALIDATION.md).

## Actual local checks

| Check | Result and scope |
| --- | --- |
| Motorcycle course | Actual `move_and_slide` riding across the full 7.9 km route, 309.55 active riding seconds, 33 stable jumps, zero crashes in the final automated pilot run. Six sectors; speed derives from the normal campaign walking speed multiplied by exactly four. This is automated pacing evidence, not human difficulty calibration. |
| Vehicle mechanics | Four physical motorcycle presentations, solo has one Naki rider, seat ownership, acceleration, braking, held-button release latch, crash/dismount/recovery, and time plus distance completion guards pass. Stationary Annu fired real projectiles and damaged a stopped rider. |
| State and saves | 32 chapter checks and 128 existing Mission 1 checks pass, including sequential guards, intentional chapter selection, migration, corrupt-file recovery and unchanged legacy save bytes. |
| New mission integration | 173 checks pass through every stage of missions 3–9: actual Annu actor deaths, physical objective interactions, hold areas, real projectile hits on all three boss cores, vulnerability timing, floor warning timing, exposed-lane damage, cover protection and final ship-console completion. |
| Physical traversal | 77 checks pass using actual actor movement to all mission 3–9 objectives, optional records and final supply racks; sufficient unobstructed encounter spawn positions are checked. |
| Runtime lifecycle | 17 checks pass: same-session snapshots, world/session replacement, exactly four bike nodes after rebuild, restored riding time, stale weakpoint removal, actual defeat/retry encounter reconstruction, and initial Continue into saved missions 2, 3 and 9. |
| Two native ENet clients | 34 checkpoints pass: mission 2 loading, four bikes on both peers, separate held interactions, guest throttle and authoritative movement, mission 3 world change, remote objective completion, wipe/retry and same-member reconnect. |
| Four native ENet clients | 42 checkpoints pass for the same path with all four established squad seats. These are four processes on one PC, not four physical PCs or WAN tests. |
| Regression checks | Existing campaign state, UI, guidance, complete Mission 1, physical loot, falling/weapon controls and contact momentum pass. Expanded mission selection and solo/co-op launch controls fit 1920×1080, 1280×800 and 640×480. |
| Render inspection | Real Windows OpenGL captures of the campaign menu, mission selection, player views and overhead scenes for all eight new missions were inspected. Follow-up art removes overly noisy floor materials and adds distinct large machinery and structural framing. |
| Private Windows export | Godot 4.6.3 Windows release export succeeded. The actual executable starts the campaign menu headlessly and exits with status 0. A separate debug-engine harness against the embedded release pack passed all five chapter-data, four-bike, save, Continue and finale checks; that harness could not load release-only native extensions, so extension readiness is established only by the actual release startup. |

Local reports: `%TEMP%/nest-campaign-validation-EwSFk7` (full course), `nest-campaign-validation-ZNNfwH` (mount release), `nest-campaign-validation-euvUlI` (actual ambush fire), `nest-campaign-validation-Vf3dCI` (state/migration), `nest-campaign-validation-v7jDj4` and `nest-campaign-validation-oZH8qp` (journey/lifecycle), `nest-chapters-native-to3Jmm` (two clients), `nest-chapters-native-UxWmhW` (four clients), `nest-campaign-validation-aK2lGn` (regressions), and `nest-campaign-validation-F3nvJZ` (expanded UI). Physical traversal log: `C:/Users/Corey/.cache/chapter-routes-2.log`. Render captures: `C:/Users/Corey/.cache/ancient-nest-nine-qa/captures-final`.

Early failed runs exposed and corrected parsed save-version typing, a typed terrain-array assignment, held interaction mounting/dismounting repeatedly, road defenders facing away from riders, and obstructed archive/dish/final-console approach positions. Final review also found that initial Continue temporarily created the preparation world for a later chapter; initialization now creates the saved chapter world, with six additional checks in `%TEMP%/nest-campaign-validation-YYb3HU`. Failed attempts were not counted as passing runs. The known native root-certificate-store warning remains. Render teardown also logged two small OpenGL texture leaks; no sustained memory/performance result is claimed.

Final source reruns: `%TEMP%/nest-campaign-validation-Kai3e0` (motorcycle course), `nest-campaign-validation-5MhTIB` (weapon/locomotion regressions), and `nest-chapters-native-FlucZK` (all 34 two-process co-op checks after camera changes). Private export and startup evidence: `C:/Users/Corey/.cache/ancient-nest-nine-export.log`, `ancient-nest-nine-packed.log`, and `ancient-nest-nine-release-startup.json`. Export SHA-256: `2F1D34D4FDF29615571E9256EE597D88DF016092190998E9F905E149F1C771E2`.

## Source publication

The new local branch preserves the full City-Ambush history. The prior remote campaign branch stopped at `7a84d78`, thirteen local commits before the supplied build. Source publication therefore includes those existing City-Ambush changes together with this expansion on `feature/campaign-nine-missions-2026-10-26`. The GitHub snapshot is built from the committed local Git tree, with tree equality checked before updating the new branch. The private executable and native binaries are not uploaded.

## Reproduce in CMD

```cmd
node scripts/campaign-validation.mjs campaign_journey_state campaign_journey campaign_journey_lifecycle campaign_chapter_routes campaign_motorcycles campaign_motorcycle_route campaign_motorcycle_ambush campaign_state campaign_ui campaign_mission
node scripts/campaign-chapters-playtest.mjs 2
node scripts/campaign-chapters-playtest.mjs 4
```

Use the provided runner: it isolates APPDATA and detects script errors even if Godot exits successfully. Do not run preference-writing fixtures against live user settings. Campaign co-op requires `campaign-5-nine-missions` on every peer. Competitive networking and production services are unchanged.

This is a private playable development expansion. Human difficulty tuning, long-session frame rate/memory, four physical PCs, WAN gameplay and real Discord/audio remain unverified. No new recorded narration is supplied; speaker-labeled subtitles and existing optional system speech remain. Source publication does not publish the private executable or claim those release checks passed.
