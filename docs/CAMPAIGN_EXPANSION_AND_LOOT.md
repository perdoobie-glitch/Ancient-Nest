# Expanded campaign route and physical weapon loot — 2026-10-25

Canonical source: `C:\Users\Corey\Games\AncientNest-Reforged-2026-10-23-Canonical`.
Working branch: `feature/campaign-mission1-2026-10-25`.
Private build target: `C:\Users\Corey\Games\AncientNest-Expanded-Route-Loot-20261025`.
The Take back Home desktop shortcut targets that build. Older folders are retained.
The pre-edit checkpoint is `AncientNest-Campaign-Checkpoint-20261025\before-expanded-maze.bundle`.

## Base and Mission 1

The departure base now includes a marked circular landing pad beneath the ship,
four perimeter buildings, cargo stacks, service vehicles, a solar maintenance
area, tanks, communications hardware, planters and apron lighting. Pad paint is
flush and the tutorial/boarding approaches remain open. Added lights primarily
use emissive materials rather than additional shadow-casting lights.

Mission 1 uses a **200 × 200 m maze footprint** (40,000 m²), compared with the
previous 90 × 90 m footprint: **4.94 times the area**, rather than five times each
linear dimension. Corridor clearance is **17 m**, twice the previous 8.5 m, and
the dirt path is **11.6 m** wide, twice its previous width. Plant walls are **13 m**
high. There is one continuous main route with twelve attached dead ends and no
connecting shortcuts: 94 maze cells plus the crash courtyard entrance form one
connected tree with 94 edges. The authored spine has 82 distinct cells and about
**1.62 km** of travel, excluding the courtyard approach and optional detours.

Seven wide timber bridges cross the shallow streams. Twelve dead-end climbing
gardens contain solid rocks and connected branch platforms rising above three
metres. These are optional elevated positions; the main route stays traversable
without precision jumps. The map's collision, climbing platforms and opaque
cover are identical at every graphics setting.

Annu stage in front of the squad when it reaches each ordered approach, before
the encounter clearing. All defenders can deploy during that approach rather
than materializing on arrival. Spawn selection checks cover, distance, navigation
and other live enemies. Counts remain **3 / 5 / 6 / 8 / 12**. Five field ammunition
racks support the longer journey. The expedition relay is at the route's end;
all 34 enemies and the secured charge are still required before signaling for
help. Safe retries start at the previous cleared encounter. Old safe saves remain
readable, with progress placed on the revised layout.

Campaign co-op requires **campaign-4** on every member's machine. The main-menu
full artwork, Difficulty labels, active tutorial marker, removed sprint, accounts,
Discord, Film and existing multiplayer modes remain in the source.

## Weapon drops, labels and carbine

Campaign bots release the weapon they were actually wielding when killed. The
drop starts at the held pose, inherits motion, spins, falls, bounces against the
world and settles as a rigid body. Existing death-pose relaxation accompanies
the release. Hold **Interact** near the gun to equip it; pickup animates the model
toward the player's hand. Primary/secondary slot selection follows the weapon
definition, the blade remains available, and carried ammunition is preserved.
Picking up the same weapon adds its ammunition to reserves within existing limits.
Only the host grants inventory changes. Range/cover checks and a single claim
guard prevent remote or duplicate collection. Clients interpolate host-authorized
drop transforms over the gameplay connection. No drop traffic uses Cloudflare.

There are at most **24** loose drops with a **120-second** lifetime. They collide
with the world, do not obstruct living players, sleep after settling, pause with
solo play, and clear on retry/exit. Loose debris is not checkpointed; equipped
looted weapons and ammunition are saved at safe milestones. Claimed guns linger
briefly in replication so the squad can see the pickup animation.

Floating in-world labels now use half their former pixel scale and **75% opacity**.
HUD, subtitles, controls and menu text retain their readable sizes. The plasma
carbine catalog speed changed from **1000 to 2000 m/s**. Damage, burst cadence,
recoil, magazine size and range were not changed. Swept projectile collision still
checks the entire traveled segment, including at the doubled speed.

## Validation

All tests use isolated APPDATA and `NEST_ISOLATED_QA=1`.

- `campaign_maze`: 21 checks, including actual movement over the entire main route,
  connected/acyclic topology, dimensions, boarding/exit, bridge crossings, final
  relay interaction, actual jumping onto all five branch platforms and safe retries.
- `campaign_staging`: actual live defenders for every prescribed group are present
  while the player remains on its approach; exact counts and final radio guards pass.
- `campaign_loot`: real death/release, gravity, tumbling/settling, range protection,
  single claim, carried ammunition, pickup animation, checkpoint readback, labels,
  actual doubled projectile travel and swept cover collision pass.
- Four native ENet processes: **39 checkpoints** pass, including replicated physical
  drops and a remote held interaction that equips the dropped AK-47 for that player.
- Input walkthrough rehearsal: tutorial checks, boarding, crash exit, charge
  recovery/securing, reaching the distant stage approach and clearing the first real
  wave pass. Cinematics were skipped in this rehearsal; the 120-second introduction
  timeline is unchanged, and its new scenery was inspected through rendered views.
- The broader campaign/account/controls/browser/master/network/Film/age/Discord
  fixture run passed except an outdated assertion requiring cropped menu artwork.
  That assertion was updated to the user's requested full-art stretch behavior and
  the browser fixture passed on rerun. Earlier failed iterations remain in reports.

Key reports:

- `%TEMP%\nest-campaign-validation-crZdcu` — broad suite and full physical maze walk.
- `%TEMP%\nest-campaign-validation-KJxKIv` — loot/carbine collision, browser and staging reruns.
- `%TEMP%\nest-walkthrough-j0A4lJ` — input walkthrough and first wave.
- `%TEMP%\nest-campaign-ChWeHx` — four-client drop pickup/progression.
- Recovery directory `captures-expanded-proof` — rendered base, pad, maze, climbing,
  release/settling views, and actual geometry/navigation metrics.

Short 1280×800 GTX 1660 Ti scenery samples measured forest medians of
**1.27–3.04 ms on High** and **0.75–1.97 ms on Low** in three encounter views.
Reports: `%TEMP%\nest-campaign-render-O6NDR2` and
`%TEMP%\nest-campaign-render-Nl3Klv`. High overlapped headless tests; Low ran after
those tests. These are short scenery-only samples, not full-match FPS promises or
controlled before/after measurements. Static batching reduces 4,341 original High
forest meshes to 1,733 spatial groups. Shared materials, lower-segment flower stems,
bounded shadow distance and sleeping loot limit added work. Simulation/input and
snapshot targets remain unchanged.

No production deployment, release, default-branch merge or credentials change is
included. Live matchmaking/WAN and physical two-PC/Discord certification remain
unverified. The four previously documented launcher landing issues are outside
this update. Git push must be verified separately when connectivity is available.
