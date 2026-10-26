# Connectuct guidance, atmosphere and narration integration

This follow-up builds on `9c94358`. The gameplay changes are campaign-local;
multiplayer modes, accounts, Discord, Film, weapon behavior and 60 Hz physics
remain intact. **Difficulty** remains Easy / Medium / Hard / Angel.

## Player flow

The approved monologue still occupies exactly 120 seconds. Its third camera
pass now looks up at Connectuct's damaged atmosphere. It hands control to Anki
on the departure deck, where a compact high-contrast card explains one action
at a time, shows the player's current bindings and points toward the relevant
station. Brutus has a welcome, individual lesson cues and repeatable briefings.

The route is look → walk → jump → equipment terminal → shield
calibration → recovery behind cover → aim/fire/reload/weapon selection → crouch
and flashlight → cargo inspection → enter the cabin and hold Interact to board.
No tutorial action is bypassed by the guide. Host-observed practice remains
independent for every squad member; all members must board before departure.
The boarding interaction moved inside the open ship cabin, instead of at the
hatch threshold. Departure, day-46 transition and Old Earth crash remain staged.

Latest owner change: sprint is removed from the current game, controls, tutorial
and campaign replication. Legacy checkpoints accept and discard their old
sprint flag. Campaign co-op now identifies as `campaign-2`; use the same updated
build on every expedition member. The multiplayer matchmaking protocol is unchanged.
Only the active local tutorial destination is marked. Completed/upcoming station
labels remain hidden even when nearby; look/jump/reload/switch and squad-wait
steps have no destination marker. Cinematics show no tutorial waypoints, and
finishing a step updates its marker immediately. Physical scenery remains visible.
This follow-up passed all 44 guidance checks, checkpoint/state and mission
regressions, existing movement/weapon-control checks, and all 36 checkpoints
with four native ENet clients. Reports: `%TEMP%\nest-campaign-validation-MXUrKN`
and `nest-campaign-Ifznx2`. The active-equipment rendered capture was inspected
in private `captures-active-step`; only that step's station/waypoint is shown.

On the crash handoff, an immediate readable instruction explains escape and
charge recovery. Its spoken cue waits for the existing 24-second story dialogue
and remains eligible through the first twelve seconds of wave one so that the
assault transition cannot cut it off. Carrying a recovered charge or enabling
the final radio produces a specific next instruction and marker.

Press **H** to repeat the current Brutus instruction. The binding is configurable
as Campaign Hint under Settings → Controls. An existing custom H binding gets
priority; a free F6/F7/F8 is selected for the new action. Pause also offers
**Repeat Brutus / Resume**. Bindings are displayed dynamically; the spoken
script refers to highlighted controls rather than incorrectly reading defaults.

Tutorial observation now retains restored checkpoint evidence instead of
clearing it when its local observation origin is recreated. Pausing/focus loss
preserves the briefing; leaving, cinematics and completion stop owned speech.
Captions remain available with dialogue volume at zero or without a voice.

## Actual voice status — incomplete actor assets

There is **no newly recorded human performance or generated voice file** in this
revision. No connected speech-generation tool was available. Windows speech
enumeration found David/Zira, but attempts to synthesize a WAV from the managed
agent failed (including `0x80070005` access denied). That restriction was not
bypassed. No private script was uploaded to a voice service and no paid service
was purchased. An authorized voice tool or supplied recordings is still needed
to finish the requested actor-quality narration.

The playable implementation now prefers reviewed recordings and otherwise uses
Godot's local OS text-to-speech when the desktop exposes an English voice. It
prefers David when present, with a restrained lower-pitched delivery. This is
synthetic system speech, not a human actor or a cloned celebrity. It is a fallback
with device-dependent quality; an installed Windows voice does not prove that
the current process can synthesize. When unavailable, subtitles and instructions
continue. Pause displays the available narration mode.

The game's existing narration, dialogue and effect gain settings are preserved.
Recorded audio uses Campaign_Dialogue. OS speech bypasses Godot audio buses, so
its volume is explicitly scaled by dialogue × master; muting stops current OS
speech. OS speech follows pause/skip/exit and never uses HTTP. Exact prosody,
in-utterance gain changes and phrase timing remain engine dependent. The fixed
120-second cinematic clock never waits for or stretches a recording. Subtitles
use phrase-length weighting instead of equal-duration text blocks.

Godot's supported API and platform limitations:
[DisplayServer text-to-speech](https://docs.godotengine.org/en/4.5/classes/class_displayserver.html),
[text-to-speech setup](https://docs.godotengine.org/en/4.5/tutorials/audio/text_to_speech.html).

Delivery filenames and direction are in `game/audio/campaign/README.md`.
Recorded voice playback and actual audible OS speech still require a manual
desktop listening pass. Isolated QA deliberately does not speak through the
owner's speakers; tests prove cue selection/state behavior, not sound quality.

## Visuals and performance

A static sky shader adds an amber irradiated horizon, violet/teal damaged
atmospheric bands, broken cloud veils and a hot sun. This is fictional visual
storytelling, not a claim that ozone gas visibly forms cracks. Fog no longer
washes out the sky. City towers have teal, copper, slate and ivory facades,
rooftop setbacks, small planted balconies, color-coded practice bays, repair
infrastructure and atmospheric-monitoring towers. Nearby station signage and
the current waypoint take priority over a wall of overlapping labels.

The earlier scenery batching and navigation index remain. Sky radiance is static
at 128 resolution; there are no volumetric clouds, extra shadow lights or
per-frame sky rebuilds. Guidance refreshes at 10 Hz and audio bus gains update
only when changed. Corrected the campaign's reversed quality interpretation:
**0 Low / 1 Balanced / 2 High** now matches the existing graphics menu. Low uses
fewer ground-cover/ash instances, one material sample and no accent lights;
the player's existing shadow preference remains effective. Settings are not
automatically changed or saved by this update.

Updated renderer harness explicitly selects quality and applies the matching
viewport MSAA. Consequently these new samples are **not a controlled comparison**
with the earlier harness, which omitted viewport quality setup.

On this GTX 1660 Ti / Godot 4.6.3 / OpenGL / 1280×800 / uncapped / three fixed
views, High (including 4× MSAA) measured preparation median 1.18–1.42 ms and
p95 1.64–2.23 ms; forest median 1.12–1.19 ms and p95 1.77–2.18 ms. Low measured
preparation median 0.86–0.88 ms and forest 0.64–0.67 ms. These are short
scenery-only timings, not gameplay FPS, GPU timestamps or sustained thermals.
High reports: `%TEMP%\nest-campaign-render-zMDWSR`; Low: `nest-campaign-render-4Ng1yb`.

## Validation and private PC build

All 38 guidance checks passed (`%TEMP%\nest-campaign-validation-yRpGWC`). The
eight-fixture campaign/control regression passed in `nest-campaign-validation-hcILTq`.
Guidance tests cover lesson order, every required check, custom binding labels,
checkpoint evidence preservation, pause/resume, panel/marker fit at 1920×1080,
1280×800 and 640×480, cabin boarding, cinematic voice stop and crash briefing
continuity. Campaign state/UI, mission, scenery/spawn, combat and control
regressions pass. Four native local ENet clients passed all 36 campaign
checkpoints in `%TEMP%\nest-campaign-1Xv3el`; this does not certify WAN/four PCs.
Six actual rendered captures were inspected in the private checkpoint folder's
`captures-guided`. A first new-class test ran before editor import and failed;
the class cache was imported and the subsequent mission run passed. This was
not treated as an accepted test. The existing root-certificate warning persists.

From CMD:

```cmd
node scripts/campaign-validation.mjs campaign_guidance campaign_mission campaign_scenery campaign_spawn campaign_combat campaign_ui campaign_state falling_and_weapon_controls
node scripts/campaign-playtest.mjs 4
node scripts/campaign-render-benchmark.mjs 2
node scripts/campaign-render-benchmark.mjs 0
```

Newest private build: `C:\Users\Corey\Games\AncientNest-Campaign-Guided-20261025\Ancient Nest.exe`.
The Campaign Private Test desktop shortcut points there. Close an older running
game and reopen that shortcut; **New Campaign** plays the whole Connectuct
intro/tutorial. Continue retains the last saved safe phase. Earlier builds,
project folders and checkpoints are preserved. Nothing was deployed, merged
into the default branch, or published as a release.
