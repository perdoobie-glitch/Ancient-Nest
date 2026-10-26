# Landscape and structure pass — 2026-10-25

This campaign-only pass follows `7a84d78`. The owner requested roughly twenty
minutes of creation and ten minutes testing; creation ran 18:25–18:45 UTC.
Testing required additional time to resolve traversal/test-driver issues and
separate startup shader compilation from visible cinematic timing. Voice work
is deferred by the owner; no new voice service, purchase or recording.

## Art direction and objects

Connectuct retains ivory/slate architecture with teal service equipment, copper
framing and restrained gold navigation accents. Added a three-layer mountain
backdrop (36 mesh chunks), a lower valley basin and raised deck foundation,
two open freight shelters, elevated stopped transit cars, a communications dish,
cargo stacks, maintenance benches/tools, docking cradles and clinic facade details.
The ship now has clearer seat pads, ceiling cable/light runs, cockpit consoles,
floor chevrons and a continuous hatch ramp. The mountainous horizon is shared
across all intro views rather than individual painted backdrops.

Old Earth uses related muted slate, moss, amber/rust and worn-metal colors.
Added layered ridges, nine distant ruined arches, twenty outer conifers/dead
snags, perimeter rock formations, exposed log end-grain, fungi clusters, supply
rack details, scorched hull panels and a damaged sensor mast. Existing canopy
trees now include conical silhouettes and muted autumn foliage. Soil has a
subtle worn trail and engine scorch marks. Mountains/ruins beyond the perimeter
are scenery, not newly playable areas or Mission 2 content.

Creation is deterministic. Existing materials/noise/mesh tools are reused; no
downloaded art or external image generator. Large decorative scenery remains
outside combat approaches; new reachable city freight structures have collision.
The fixed scenery joins existing spatial material batches; the animated ship
retains its own coordinate-space batches. Far mountains do not cast shadows.
Added simple full-height collisions to existing opaque tree trunks so hitscan
and AI perception agree with the visible trunk above its old low root collider.

## Readability and traversal fixes

The dark passage's raised floor bar became a flush warning stripe, retaining
the overhead crouch beam. The cabin hatch now has a continuous convex ramp,
also used for the forest escape. Boarding is tested by physical presence inside
the cabin plus the authoritative boarding interaction, not exact alignment with
a navigation-grid point. Cinematic camera interpolation is disabled explicitly;
camera animation still runs at render frequency and gameplay remains 60 Hz.

The test pilot stays crouched until it clears the entire passage, follows the
last navigation segment to interactions, and uses real bound key/mouse events.
Its earlier stand-up-before-beam and semi-automatic-input mistakes were fixture
failures, not accepted successes. It injects no tutorial completion flags or
teleports during the route. Rehearsal mode skips cinematics explicitly; normal
mode watches the entire introduction, departure and crash.

## Verification and limits

Fifteen High-quality rendered views cover the six intro passages, mountains,
hangar/freight structures, preparation, crash and forest approaches. Private
captures: checkpoint folder `captures-landscape`. The expanded scenery suite
passes 38 checks at Low and High, including all mountain layers, structures,
attached ramps, every original navigation-edge rule, exhaustive-vs-indexed cover
queries, dynamic mission objects and above-root trunk occlusion. All prescribed
wave spawn checks, mission integration, guidance and maximum twelve-AI combat
fixtures pass. The latter observed 39.82 m of navigation with four flashlights
and simulation-span p95 0.192 ms (last 180 ticks, short headless sample).

Four local ENet clients passed all 36 mission checkpoints in
`%TEMP%\nest-campaign-e7Sxd8`. Scenery/mission/combat reports:
`nest-campaign-validation-cKC56j`; expanded scenery: `nest-campaign-validation-cdolcM`.
These do not certify physical-PC/WAN or human combat balance.

The first timed capture included synchronous PNG saves and first-frame shader
warmup; its 126.25-second wall result failed the timing assertion. A subsequent
clock-only probe still included first-frame setup (125.28 s). The corrected
normal test measures from the first visible frame and keeps PNG encoding out of
the cinematic: its visible intro was 120.89 seconds on this loaded PC, within
the fixture's 1.2-second scheduling tolerance. The authoritative timeline remains
120 seconds; no physics/Film rate or campaign clock was changed to force a pass.
These observed tolerances are not a claim of sample-exact wall timing on every PC.

The normal rendered walkthrough uses actual key/mouse input, movement, shield
recharge and held interactions. It covers preparation, manifest, boarding,
departure, crash and charge recovery/security. It is an automated playthrough,
not a human controller/voice listening acceptance session. Startup shaders,
focused-window behavior and PNG capture cost are distinguished from gameplay.
The pre-existing root-certificate-store warning remains; no TLS bypass.

Final results are combined evidence, not a claim that an earlier failed run
passed: `nest-walkthrough-wjeYkW` passed the normal visible intro, all tutorial
inputs, normal departure/crash and charge recovery, but its stationary test
shooter did not clear the wave. The corrected input rehearsal in
`nest-walkthrough-BKudGD` passed all 21 checks, including the three actual first
wave enemies. Its test pilot pursues fixture-known actors and compensates aim
recoil, while firing only with actual line of sight. It changes no production
AI, weapon, health or enemy counts and proves no human combat balance. Prior
incomplete/failed rehearsal logs remain in their temporary report folders.

High-quality renderer sample (1280×800, 4× MSAA, GTX 1660 Ti, uncapped, three
fixed views): city medians 1.35–1.58 ms / p95 1.92–2.34 ms; forest medians
1.37–1.54 ms / p95 1.95–2.47 ms. Report `nest-campaign-render-ZwRWZu`.
The scene is intentionally richer: city static geometry merges 932 meshes into
303 batches; forest 1,557 into 422. Compared with the previous pass it adds
geometry/submissions; this is not a measured FPS improvement. The short sample
overlapped a headless input rehearsal and is not a controlled GPU benchmark,
sustained whole-mission FPS or thermal test. No simulation rate was reduced.

From CMD:

```cmd
node scripts/campaign-walkthrough.mjs
node scripts/campaign-walkthrough.mjs --intro-only
node scripts/campaign-walkthrough.mjs --rehearsal
node scripts/campaign-validation.mjs campaign_scenery campaign_guidance campaign_mission campaign_spawn campaign_combat
node scripts/campaign-playtest.mjs 4
node scripts/campaign-render-benchmark.mjs 2
```

Profiles and recordings are isolated under a fresh temporary directory. Existing
user settings/saves are untouched. The private build is
`C:\Users\Corey\Games\AncientNest-Campaign-Landscape-20261025\Ancient Nest.exe`;
the Campaign Private Test desktop shortcut points there after export validation.
Older projects/builds and recovery bundles remain intact. No production service,
credential, default branch, release or published executable was changed.

At the owner's request, an identical SHA-256-verified executable copy is named
`Ancient Nest - Take back Home.exe` in the desktop folder
`C:\Users\Corey\Desktop\Ancient Nest - Take back Home`, with its DLLs and licenses.
A same-named desktop shortcut targets that copy. This changes the filename only;
project identity, saves, multiplayer protocol and the displayed game name remain
Ancient Nest. The original exported executable is preserved.
