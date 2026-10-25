# Ancient Nest — The Last Departure

The current campaign begins on Connectuct, then returns to Old Earth. Earlier
Sanctuary-first campaign proposals are superseded; historical release documents
and multiplayer maps remain intact. Nine missions are planned; only Mission 1
is exposed as playable. Brutus is the expedition's battlefield AI. Ancient AI
is the distinct Old Earth intelligence. The cause of the crash remains unresolved.

## Launch and controls

From the canonical repository root, double-click `Play Ancient Nest Campaign.cmd`.
It uses `GODOT_BIN` or the existing pinned Windows Godot installation. Normal
startup still applies the existing 18+ policy. At sign-in choose **Campaign • Play
offline**, or sign in normally and choose **Campaign** from the main menu.
Select **Difficulty** (Easy, Medium, Hard, Angel), then **New Campaign**.
**Continue** is enabled only for a validated local checkpoint.

The source command from CMD is:

```cmd
"%GODOT_BIN%" --path game -- --campaign-menu
```

Use existing movement/look, jump, crouch, aim, fire, reload and weapon bindings.
Campaign adds configurable **Sprint** (Shift) and **Flashlight** (T) bindings in
Settings → Controls. **Interact** (E) is held for equipment checks, cargo, radio
and revival. **Enter** votes to skip cinematics. **Esc** opens campaign pause;
Difficulty remains visible and locked for the run. Separate dialogue/music/
effects sliders are available there. Solo pause/focus loss stops campaign
simulation; a co-op player's local menu does not pause the squad.

## Playable flow

1. **THE WORLD WE BUILT**: a 120-second authoritative timeline with six animated
   Connectuct camera passages, machinery/civilian character staging, music,
   quiet synthesized engine ambience, subtitles and replaceable voice slots.
   The ship remains docked at the end. Film capture rates do not control it.
2. **Departure readiness**: each player separately practices look, movement,
   sprint, jump, crouch, interaction, aim, fire, reload, weapon switching,
   flashlight and shield recovery. Follow numbered service terminals. The
   shield emitter reduces only shield strength; take cover behind the barrier
   and let the existing recharge rules restore it. Use the safe firing bay and
   dark inspection passage. One person's checks cannot complete another's.
3. **Boarding**: inspect the sealed industrial excavation charge at the manifest
   terminal, then hold Interact at the ship boarding point. All connected squad
   members must finish personal checks and board.
4. **Departure / return / crash**: controlled hull animation and camera staging,
   with an explicit expedition-day-46 transit transition. Old Earth's forests,
   the obsolete Ancient AI signal and flight fault precede the prepared wreck.
   Cinematic damage never kills the squad. Normal completion and skip share the
   same initialization path, camera/input restoration and resource assignment.
5. **Crash orientation**: escape, locate the charge using its short-range
   equipment locator and readable case, confirm fictional isolated/safe status,
   carry it and secure it in the surviving locker. Recovery is independent of
   combat; another member can help secure it when the carrier is at the locker.
   A brief preparation window includes the approved speaker-labeled dialogue.
6. **Assault**: five authoritative waves with readable intermissions and marked,
   replenishing supply racks. Kill every current wave enemy before advancing.
7. **Radio**: the damaged radio exists from crash initialization. It cannot
   start the ending until all five waves, all 34 enemies and charge security
   are complete. Any member may interact; Anki delivers the approved dialogue.
   Ancient AI speaks separately; the gold circuit illuminates at its line.
8. **Complete**: a one-time completion record; replay or return to campaign.
   Mission 2 is not loaded or advertised as implemented.

## Mission data and Difficulty

Editable data: `game/data/campaign_mission1.json`. State and save rules live in
`campaign_state.gd` / `campaign_save.gd`; the integration controller is
`campaign.gd`, with separate UI, world and cinematic modules.

| Wave | Name | Enemies | Approach plan |
| --- | --- | ---: | --- |
| 1 | Contact | 3 | One forest approach |
| 2 | Perimeter | 5 | Two approaches / simple flank |
| 3 | Pressure | 6 | Suppression / reposition |
| 4 | Breach | 8 | Three routes toward the wreck |
| 5 | Seizure | 12 | Covering elements / advance / flanks |

The total is always **34**, for every Difficulty and party size. Reaction,
tracking, aim error, burst/rest intervals, awareness, cover, flanking,
coordination and aggression are data-driven. Later waves tighten pressure
modestly within the chosen profile. Health, armor and weapon damage retain
the established normal-preset rules; enemies are not made into bullet sponges.
The campaign uses the existing normal TDM physics/traits preset and restores
the user's previous multiplayer/custom rules when exiting. Only campaign
sprinting adds a 1.25 ground movement multiplier. Other modes are unchanged.

AI can acquire targets only through physical line of sight and smoke checks,
then uses last-seen positions when contact is lost. It does not update hidden
player positions through smoke/walls. Opaque smoke geometry/perception volumes
are invariant across quality settings. Concealed spawn candidates are checked
for obstructions, route connectivity, proximity and player viewing direction;
if no safe candidate exists the arrival is deferred rather than fabricated.
Existing collision-aware bot steering/recovery is reused; living enemies are
never silently removed to advance a wave.

Mission display-name mappings preserve shared catalogue IDs and combat values:

| Campaign label | Stable catalogue ID |
| --- | --- |
| Naki Carbine | assault_rifle (existing automatic rifle, mission-local label) |
| Naki Pistol | plasma_pistol |
| AK-47 | ak47 |
| Magnum | magnum |
| Optional Naki plasma rifle | plasma_br |

The reserve racks replenish on a 20-second shared cooldown and include ample
carbine/pistol reserves. Supplies and equipped resources are checkpointed.
Flashlights use real spot lights attached to each actor's eye/weapon direction;
the owning player's light may cast shadows and remote lights do not. They have
no resource drain, replicate independently, hide on incapacitation and are
freed with the actor. Four lights do not create four shadow-casting lights.

## Co-op setup and authority

Host: **Campaign → Difficulty → Host Co-op**, select a UDP port (7779 default),
create the expedition, then Ready. Guests: **Join Co-op**, enter the host's
reachable address and identical port, then Ready. The host launches once all
connected members are ready. Host is Anki; other members are expedition Naki.
Solo has no online-service or second-human dependency.

This uses the game's existing direct ENet host/command/prediction/snapshot stack,
not a second Cloudflare service. LAN/loopback is tested. Internet use requires
a reachable UDP host; this campaign path does not add automatic NAT traversal
or TURN. Competitive WebRTC/TURN matchmaking remains unchanged. No account
credentials or administrative keys are placed in campaign packets.

Only the host spawns enemies, runs AI, changes shared objectives, validates
interactions, saves checkpoints or completes the mission. Player requests are
sender-bound and rate-limited, scoped to the current run and phase epoch.
Stable enemy IDs make repeated registration/deaths harmless. Worlds and retry
sessions reset command sequencing so delayed old input/snapshots cannot mutate
the rebuilt encounter. Cinematics await load acknowledgements and unanimous
skip votes from connected members; disconnected members leave those quorums.
An unresponsive loading peer is removed after 45 seconds rather than blocking
the squad forever.

New members must enroll before the intro. Previously enrolled members may
disconnect/rejoin the same host from the same running client application; a
private random seat capability is retained in memory and is never broadcast.
After restarting the client application, that in-memory reconnect capability
is gone; start a new expedition to enroll again. Disconnected bodies cannot
act as bots or remain valid AI targets. Campaign host migration is deliberately
unsupported: host loss returns guests safely with an explanation.

Incapacitation disables firing/collision and the flashlight. Another living
member holds Interact nearby for a validated three-second revive; damage,
movement, expired bleedout or releasing the hold interrupts it. The window is
45 seconds. Full squad defeat offers host-controlled checkpoint retry; solo
death uses the same retry path. Equipment/ammunition remain independent.

## Checkpoint format

Versioned, bounded primitive JSON at `user://campaign/mission1.json`, with a
validated recovery `.bak`. A temporary file is flushed and validated before
replacement. Writes occur synchronously at safe milestones; there is no
asynchronous save work that could overtake a newer revision. Older revisions
of the same run are rejected. Main-file corruption falls back to the validated
backup; invalid/oversized/unsupported state disables Continue.

Safe milestones include preparation, boarding readiness, initialized crash,
cleared-wave boundaries and completion. Mid-wave encounter saves are unsupported
and rejected by the save loader. A retry starts the current unfinished wave
from its preceding safe boundary with stable IDs, not a partial set of enemies.
Securing the charge during combat merges that durable objective into the last
consistent checkpoint, so retry cannot duplicate or lose a secured case. A
carried-but-unsecured case restores to its designed search location. Equipment,
resources, rack cooldowns, Difficulty, objectives and completed waves restore.
Retry revisions remain monotonic. Competitive rewards/results are never invoked.

## Art, audio and Film limits

Connectuct, the ship, medical/engineering staging, forest, roots and wreckage
are functional procedural blockouts, not final production art. Existing Naki/
Annu character rigs, weapon models, effects and music are reused. Static opaque
smoke is a consistent gameplay occluder; ash/fire/electrical details are inexpensive
blockout effects. Final environment models, richer canopy/terrain, polished
crash animation and final sound design remain asset work.

No recorded campaign narration is supplied: no authorized speech-generation
tool was available. The exact approved script is preserved in the fetched
23-section instruction file and mission data. See `game/audio/campaign/README.md`
for six replaceable 20-second voice slots and direction. Missing voice does not
block the 120-second cinematic or gameplay. Brutus/Anki/relay/Ancient AI dialogue
currently uses speaker-labeled subtitles.

Existing multiplayer Film recording/playback remains supported and regression
tested. Campaign scenes are excluded from that arena-reconstruction format;
campaign Film capture is not implemented and does not change mission timing.
The 30–40 minute duration is an unverified human pacing target, not a measured
playthrough or a reason to add artificial delays.

## Validation and Windows handoff

Run from CMD with `GODOT_BIN` set to the pinned Godot 4.6.3 console executable:

```cmd
node scripts/campaign-validation.mjs
node scripts/campaign-playtest.mjs 2
node scripts/campaign-playtest.mjs 4
node scripts/lobby-lifecycle-playtest.mjs
npm.cmd --prefix matchmaking run typecheck
npm.cmd --prefix matchmaking run build
npm.cmd --prefix matchmaking test
```

The campaign validator isolates APPDATA per fixture, has process timeouts and
fails on script errors even if Godot exits 0. Native campaign tests use isolated
profiles and actual ENet processes. They drive some host-side tutorial evidence
and combat deaths to test state/replication; they do not certify human combat
balance, manual tutorial completion, real Discord, WAN or four-PC performance.
See the final validation entry and handoff for actual counts/report directories.

Rendered 1280×800 captures were inspected on this Windows PC. The capture script
is `game/tests/campaign_preview.gd`, with `NEST_CAMPAIGN_PREVIEW` set to an output
folder. Captures remain in the private local checkpoint directory rather than
being published as release assets.

Manual acceptance: play each Difficulty solo; complete every tutorial action
without test injection; try early and mid-wave charge recovery; test all supply
racks, aiming, reload/switch, smoke/cover, interrupted revives, bleedout, wipe,
retry, focus/pause, every vote/disconnect path and replay/Continue. Repeat with
two and four physical PCs, varied hardware and networking, then measure sustained
frame/tick times and memory with twelve enemies, four lights and effects.
The known native root-certificate-store warning remains a separate Windows
environment issue; do not disable TLS to work around it.

## Service deployment and rollback

No production deployment, credentials, schemas, bindings or account data changed.
Campaign itself needs no Cloudflare deployment. Existing networking defaults
remain 20s host heartbeat / 60s stale / 15s visible browser / 5s queue fallback /
10s timeout / exponential jitter up to 30s (longer valid Retry-After wins).
Simulation/input/snapshot targets remain 60 / up to 60 / 20–30 Hz.

For a future separately authorized normal-multiplayer rollout, follow
PC_CODEX_HANDOFF.md section 8: retain previous Worker version/client revision,
drain incompatible queues, deploy only the matching existing Worker with current
bindings, verify authenticated admission/results, and distribute the matching
client only after release gates. No account migration or secret rotation is
needed for this campaign. Roll back the Worker via its retained version and
restore its matching client; never reset Durable Object storage or credentials.
For a client-only campaign rollback, keep this working branch/checkpoint and
run the earlier verified client source/package. Preserve campaign saves, films,
pending results and all unrelated data. Do not reset or clean this checkout.
