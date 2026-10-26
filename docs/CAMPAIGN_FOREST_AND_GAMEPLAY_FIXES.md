# Forest route, expedition ship and gameplay fixes — 2026-10-25

Source: `C:\Users\Corey\Games\AncientNest-Reforged-2026-10-23-Canonical`.
Branch: `feature/campaign-mission1-2026-10-25`.
Recovery bundle before edits: `C:\Users\Corey\Games\AncientNest-Campaign-Checkpoint-20261025\before-forest-maze.bundle`.

## Mission 1

An authored dirt-trail loop crosses a branching forest garden with opaque plant
barriers, colored flowers, rocks, shallow flowing streams and four timber bridges.
The loop returns to the crashed ship. Living squad members trigger only the next
ordered encounter by reaching its clearing: Fern Gate, River Garden, Root
Sanctuary, Golden Grove, then the Radio Approach. Waiting does not start waves.
Counts remain **3 / 5 / 6 / 8 / 12**. Clearing all 34 enemies and securing the charge
unlocks the radio to signal for help. Safe retries resume from the previous clearing.

Campaign peers must use **campaign-3**. The 120-second introduction, active-step-only
tutorial waypoint, Difficulty labels and removed sprint remain intact. A firing-bay
wall that overlapped the cabin approach was relocated outside the hull. Crash spawns
now clear passenger seating and face the rear exit.

The ship has a lofted curved white pressure hull, gold strakes, swept rounded wings
and green plasma windows. Shell and wing collisions follow the geometry; the rear
hatch and ramp remain open. Campaign starts with plasma carbine and plasma pistol,
plus the restored wieldable Nexus Blade (default key **3**, quick melee **F**).
Hold **Interact** at either onboard rack to equip a plasma sniper or plasma assault
rifle. Racks are available before departure and at the crashed ship. Existing
two-weapon checkpoints remain readable; new checkpoints include the blade.

Opaque geometry and physics stay identical across quality settings. Small flowers
do not cast shadows. Static scenery is spatially batched, water animation runs in
the shader, and the sun retains bounded shadow distance. Curved hull panels remain
independent meshes because merging their custom vertex streams removed panels in
the rendered check. No gameplay simulation or network tick rates were reduced.

## Lobby, Forge and Film

- Map selection is directly visible in lobby Game Setup, with host authority and
  voting locks preserved.
- Forge explicitly enables the viewport's 3D renderer and initially faces the map.
- Films start at their first recorded sample and play a participant perspective.
  Pause and Play work; Play at the end restarts the film. An idle lobby connection
  no longer blocks opening a recording.
- Ended or quit matches receive a finalized library card with map, mode, duration,
  participant count, outcome and a thumbnail captured once during rendered play.
  Disk work remains asynchronous; previews and indexes share Film retention.
  Legacy recordings remain openable with a fallback preview.

## Contact momentum

The shared actor solver retains moving-support velocity when jumping or leaving
the support. Uphill surface motion can add up to 6 m/s of upward momentum; normal
flat-ground jump traits remain unchanged. Existing ground friction and air drag
still dissipate motion. Moving side/ceiling contacts transfer a bounded velocity
component, with mass weighting for rigid objects. Static walls add no energy and
repeated contacts cannot accumulate unlimited impulse. Opposed moving contacts
search for a short clear escape direction and apply a capped velocity, without
teleportation. Fully enclosed geometry cannot guarantee an escape. No new moving
crusher or replicated rigid-prop game mode was introduced.

## Matchmaking

Account HTTP verification no longer races the shorter WSS hello timeout. Results
from an old account request cannot authenticate or fail a replacement socket.
Sockets closed before hello now enter bounded retry and expose Reconnect. Server
rejections retain their actionable reason. Established gameplay is not stopped by
a control-service rejection. Credentials, URLs and production services were not
changed or deployed.

The configured PC and packaged coordinator addresses match. Both a PC-side public
health request and an independent web-tool request failed from this agent session.
That does **not** prove a production outage. Live matchmaking/WAN success remains
unverified; the user's failure stage/message is still needed to diagnose any
remaining service, account or gameplay-transport problem.

## Verification and limits

Tests run with isolated APPDATA and `NEST_ISOLATED_QA=1`, never live preferences.

- `campaign_maze`: real capsule walking through boarding, rear ramp, the complete
  maze loop and bridges, radio return, ordered/living-only triggers, foliage
  ray occlusion, and retry placement.
- `campaign_mission`, `campaign_spawn`, `campaign_state`, `campaign_guidance` and
  `campaign_scenery`: exact counts, radio guards, legacy/current saves, concealed
  navigable spawning, HUD/waypoints, cover index and batching invariants.
- `gameplay_followup`: map selection, visible Forge, usable racks/blade and strict
  JSON checkpoint readback; actual recorded quit/completed matches, preview cards,
  autoplay/pause/restart and playback from an idle ENet lobby. Rendered run adds
  actual thumbnail checks (27 checks).
- `contact_momentum`: unchanged flat jumps, actual ramp/support transfers, bounded
  object momentum, opposed real contact escape queries and airborne drag.
- `matchmaking_connect`, `master_control`, `server_browser`, `network_policy`:
  delayed/stale authentication, pre-hello failure, actionable rejection, continued
  established gameplay, cadence/retry and browser guards.
- Four native ENet processes: 36 campaign progression checks, all five waves,
  disconnect/reconnect, revive, shared charge, retry and completion.
- Rendered previews in the recovery directory: `captures-maze-final` and
  `captures-followup-final`. No human actor recording or new voice asset is claimed.

Short High-quality scenery samples at 1280×800 on GTX 1660 Ti measured forest
median 1.32–2.59 ms and p95 2.29–3.68 ms in the three sampled views. These samples
exclude AI and sustained thermals, and overlapped headless test activity; they are
not an uncapped gameplay FPS promise or a controlled before/after comparison.
Report: `%TEMP%\nest-campaign-render-EHkj5P`.

Known baseline failure: `map_launchers` has four existing deck-landing failures.
Running it with the untouched HEAD actor produced identical four landing positions
to the updated solver (`nest-campaign-validation-nzJQ2Y` versus
`nest-campaign-validation-SGrvuf`). This update does not certify or repair those
existing launcher destinations. Earlier failed iterations are retained in temporary
reports and are not counted as passing runs.

No release, default-branch merge, production deployment, credential change or
two-physical-PC/WAN certification is included. Private local builds are for testing.
