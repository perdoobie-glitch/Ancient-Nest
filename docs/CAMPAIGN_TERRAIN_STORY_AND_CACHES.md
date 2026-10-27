# Campaign terrain, field weapons and story pass

This pass continues the separate `AncientNest-Campaign-2-9-20261026` checkout from
local commit `218ac1d`. The original City-Ambush build and the first nine-mission
export remain available. The new private export goes in `builds/windows-relief`.
The root launcher prefers that export when present.

## Riding and terrain

Broken Canopy keeps four motorcycles and its 7.9 km route. Top speed is still four
times ordinary walking speed. The road now rises and falls through valleys,
embankments and three ravine bridges, with approximately 106 metres of vertical
relief. There are 966 new collision-tree obstacles arranged around changing
slalom gaps, more than ten times the previous route's lane-tree count. Sixteen
overhead branch gates require the bound Crouch control; sixteen low timber gates
require a timed hop. Jump, duck and ramp hazards have separate approach windows.
Grounded markers indicate the intended gaps without removing the collision trees.

Mounted crouch lowers both the physical capsule and the camera, changes the rider
pose, and replicates to co-op peers. The host checks headroom before standing up.
Crashes, righting the bike, Annu gunfire and the existing speed/time completion
guards remain active. An expert input fixture completes the route in about
5 minutes 15 seconds; this is pacing evidence, not a human difficulty rating.

The walking levels now use real terraces and sloped bridges. Floodgate access
climbs past hydraulic works; the sanctuary ascends through archive courts; the
foundry crosses service levels; the railway alternates embankments and lower
yards; the Sky Mirror climbs to its receivers; the reserve descends below the
entrance; the finale has elevated actuator maintenance decks and an extraction
terrace. Platforms, enemy positions, objectives, records, caches and navigation
all use the same height model.

## Firearms found along the route

There are eight cache locations on each level from 2 through 8 and six in level 9,
including raised exploration decks and sheltered roadside stops. Each is an open
physical equipment case with a real existing firearm. A shuffled selection is
chosen once by the host for each mission/run. The first cache offers something
different from the default Naki guns; later missions can include a rocket launcher.
Other choices include shotguns, rifles, SMGs, precision weapons and sidearms.

The choice is shared across co-op peers. A gun can be claimed once, does not expire
with fallen-enemy loot, and cannot be evicted by accumulating corpse drops. Claiming
a cache commits both its consumed state and the acquired inventory to the existing
safe checkpoint, preserving the checkpoint's health and encounter restart rules.
Retry and Continue therefore neither duplicate nor erase the pickup. Existing
Mission 1 and version-2 campaign saves are still accepted by save format 3.

## Moving combat and story scenes

Levels 3–8 no longer require every Annu in each intermediate zone to be defeated.
Patrols and ambush groups activate as the squad advances. Living defenders can
pursue across an opened route, while later positions activate ahead. Intermediate
machinery objectives remain usable under fire. The destination starts a timed
defense while freight, a transmission or the departure route becomes ready; leaving
the marked area pauses its countdown. The final boss retains real projectile hits,
exposed actuator windows and warned floor discharges before the departure defense.

Every level has a fifteen-second opening and closing story scene. Mission 1's
opening and ending are condensed into three readable five-second beats; its
interior departure/crash sequences remain separate. The original longer prose is
retained in the source as reference. Chapters 2–9 use moving cameras, existing Annu
and expedition rigs, subtitles and the existing optional system-speech path. Enter
votes to skip; all connected players must agree in co-op. The squad cannot move or
take damage during these scenes. Squad loading and solo pausing do not consume
their time; a co-op player's menu does not pause the rest of the squad.

Ancient AI gradually opens ancestral maintenance routes while protecting occupied
infrastructure. Annu conversations begin with suspicion of the sky visitors, then
react to the preserved water, the ancestral writing and the repaired approach
registry. The expedition recovers retired conductors instead of dismantling active
life support. The finale resolves contradictory custodial orders and departs with
reclaimed gold and the engineering archive. No new named character, faction,
playable class or character model is introduced.

## Compatibility and validation

Campaign peers require `campaign-6-relief-caches`. Competitive networking and
production services are unchanged. Campaign ENet peers now use a 15-second minimum
and 45-second maximum reliable-traffic timeout, allowing simultaneous chapter
construction on a shared PC. The existing 45-second loaded-seat deadline remains.
This uses Godot's documented [peer timeout API](https://docs.godotengine.org/en/4.6/classes/class_enetpacketpeer.html#class-enetpacketpeer-method-set-timeout).

The route review also corrected two real pursuit problems: an idle defender's
goal was inside a solid terminal, and healthy Annu treated their intentionally
absent energy shield as depleted. Goals now use a clear terminal approach; shield
retreat applies only to Naki, while injured Annu still retreat for low body health.

| Check | Evidence |
| --- | --- |
| Full motorcycle route | 314.88 seconds, 49 jumps, zero crashes with the automated expert pilot; 966 added road trees, 16 duck gates and 16 hop gates. Hazard checks include both successful inputs and crashes from incorrect inputs. |
| Walking routes | 166 physical movement checks pass across levels 3–9, including objectives, raised caches, archive records and supply approaches. |
| Actual weapon cases | 186 checks pass for all 62 firearms: valid catalog item, unobstructed grounded pickup approach, and physical support after settling. |
| Cache durability | 37 checks pass, including host-owned choices, consumed-state/inventory persistence and legacy saves. |
| Stage and boss integration | 254 checks pass across every level 3–9 stage, usable objectives with living defenders, extraction-area timing, actual boss projectile hits, warnings/cover, and final save state. |
| Real enemy pursuit | 16 checks pass for healthy/wounded Annu and shielded Naki, plus actual guards pursuing and shooting across 5 m and 7 m climbs and a 5 m descent. Existing bot movement/refinement adds 26 passing checks. |
| Loading and pause protection | Nine checks use actual explosions after a traversal stage advance with living Annu preserved. Damage and knockback are blocked during pending squad acknowledgement, solo pause and lost focus, then resume afterward. |
| Native co-op | Two processes pass 46 checks; four processes pass 54 checks, including mounted crouch, authoritative riding, shared cache identity/pickup, stage changes, wipe/retry and same-seat reconnect. These run on one Windows PC. |
| Story scenes | 192 checks pass for 15-second boundaries, saved intro/outro resumes, all-member skip, protected actors, camera/cue selection, distinct existing Annu targets, hero/first-person visibility handoff and the final ship departure. |
| Construction cost | Chapter 3–9 construction reduced from 1.8–3.2 seconds to 0.48–0.91 seconds, preserving all navigation samples and clearance checks. |

Reports under `%TEMP%`: `nest-campaign-validation-yrFIJq` (full riding route),
`nest-campaign-validation-MmWnpU` (branch/tree hazards),
`nest-campaign-validation-wLPBdm` (62 physical cases),
`nest-campaign-validation-JoVvsT` (durable caches),
`nest-campaign-validation-dHBM6m` (stage/boss integration),
`nest-campaign-validation-EtkYwW` (real pursuit and bot regressions),
`nest-campaign-validation-KvAPyP` (explosion protection and cache lifecycle rerun),
`nest-chapters-native-1CwOuW` (two clients), and
`nest-chapters-native-TlxluA` (four clients after the timeout correction).
Final cinematic checks: `%TEMP%/nest-campaign-validation-bKAP2j`.
Route and build-time logs are under `C:/Users/Corey/.cache/`:
`elevation-routes-optimized.log` and `nest-world-build-times-optimized.log`.

Final gameplay regression batch: `%TEMP%/nest-campaign-validation-QDtaL4` passes
the journey, lifecycle, state, complete Mission 1, physical loot, UI, guidance and
motorcycle hazard fixtures after the pursuit and loading-protection corrections.

To repeat the focused checks with isolated user data:

```cmd
node scripts/campaign-validation.mjs campaign_weapon_caches campaign_cache_access campaign_damage_barriers campaign_route_pressure campaign_chapter_cinematics campaign_chapter_routes campaign_motorcycle_route campaign_motorcycle_hazards campaign_journey campaign_journey_lifecycle
node scripts/campaign-chapters-playtest.mjs 2
node scripts/campaign-chapters-playtest.mjs 4
```

Earlier failed rehearsals are not counted as passes. They exposed invalid legacy
gun naming, cinematic occlusion, premature retreat, and ENet timeouts during
simultaneous loading. An early preview harness also referenced a HUD control
after its deferred deletion; the fixture now waits for the scene handoff and uses
the real campaign presentation update for HUD captures.

## Final rendered review

Windows OpenGL captures cover all eight new levels' three-shot openings/endings,
terrain, cases, destination and player HUD. Underground shots now remain below
the reserve ceiling; guard cameras face inward from clear walking lanes. The
existing local hero is visible in story scenes, with first-person camera meshes
hidden until gameplay resumes. Chapter objective labels are hidden during scenes,
and long gameplay waypoint labels now clamp to the screen using their actual width.

Captures: `C:/Users/Corey/.cache/ancient-nest-relief-qa/captures-final`, with detailed
machinery/story views in the adjacent `captures-story-final` folder. Master and
HUD passes finish without script errors. Short 90-frame static samples on the
GTX 1660 Ti at 1280×800 High measured median 8.10–8.62 ms and p95 8.69–24.65 ms,
with 341–1005 draw calls in the sampled views. They are scenery samples, not
sustained gameplay frame-rate claims. The pre-existing Windows certificate-store
warning and two 87,380-byte OpenGL teardown texture warnings remain in logs.

A separate live-combat check used the same GPU at 1280×800 High, 4× MSAA and
shadows, with VSync/capping disabled. Each scene had a four-second warmup and a
20-second wall-clock sample. The stationary hero had very high health/shield and
did not fire, keeping the real Hard-difficulty defenders alive and firing. Levels
3/8 used the destination defense with its timer preset to expose later groups;
level 9 used an armed boss stage. Normal actor caps, AI, damage and weapon logic
remained active. This deliberately sustained incoming fire rather than measuring
ordinary player movement, enemy deaths or corpse accumulation.

| Level | Live guards | Median frame | p95 frame | Worst sampled frame |
| --- | ---: | ---: | ---: | ---: |
| 3 | 12 | 16.24 ms | 24.78 ms | 46.06 ms |
| 8 | 14 | 20.68 ms | 34.21 ms | 59.50 ms |
| 9 | 10 | 11.82 ms | 16.72 ms | 122.57 ms |

All three samples verified real firing and resource loss, with no script errors.
The Annu's standard weapons resolve through hitscan, so zero persistent bullet
nodes does not imply zero shots. The underground encounter does not sustain a
locked 60 FPS under this load; the finale had one sampled hitch above 100 ms.
Warmup maxima of 246/226/144 ms are separate from the table. The full methodology,
counts and six reviewed images are under
`C:/Users/Corey/.cache/ancient-nest-live-combat-render/`, including
`live-combat-render.json`.

## Private export and source handoff

Godot 4.6.3 exported `builds/windows-relief/Ancient Nest - Nine Missions.exe`.
The actual release executable starts with `--campaign-menu` and exits successfully
in the isolated startup check. Eight checks against its embedded pack pass:
chapter catalog, 15-second introduction, four bikes, eight field guns, checkpoint,
Continue, physical elevation and final machinery. The debug engine used for that
pack harness cannot load release-only native extension entries; the separate
actual release startup has no such extension errors. Neither check establishes
real Discord consent, audio or WAN readiness.

Executable SHA-256:
`D9C6772C78D52619FA45557905EEE3FC601A7123C2C548347AB6FCA8BE98E800`.
Logs: `C:/Users/Corey/.cache/ancient-nest-relief-export-final.log`,
`ancient-nest-relief-packed-final.log`, and
`ancient-nest-relief-release-startup.json`. Final source smoke/guidance/vehicle
checks also pass in `%TEMP%/nest-campaign-validation-ciK57k`.

The root launcher prefers this private export. Native release libraries and their
licenses accompany it; the previous export remains in `builds/windows`.
Repository publication uses `feature/campaign-nine-missions-2026-10-26`, keeping
the existing remote history and checking that the published tree matches the
committed local source. Exact source identities are recorded beside the executable
in `SOURCE_REVISION.txt`; private executable artifacts are not uploaded.

This is a private development build. Automated pilots and short rendering samples
do not establish human difficulty balance, sustained combat frame rate, WAN
playability or physical four-PC performance. Recorded actor narration is not
included; speaker-labeled subtitles and the existing optional OS speech fallback
remain available. No public executable release or production deployment is implied.
