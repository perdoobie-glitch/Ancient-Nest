# Campaign journey progression and validation — 2026-10-26

This continuation is based on the City-Ambush export's exact source revision,
`59f005c3dcf3caed2f938c9d44098776c426d7e4`. Work takes place in the separate
`AncientNest-Campaign-2-9-20261026` checkout. The original export and canonical
checkout are retained.

`NestCampaignJourney` controls missions 2–9. Ordinary continuation requires the
previous mission to finish. The menu can deliberately start a selected mission
as a new expedition; `campaign_entry` records that entry and does not fabricate
Mission 1 combat history. Mission 2 completes only after the motorcycle
controller verifies actual riding time and route progress. Missions 3–9 require
the authored physical objective and the deaths of the registered Annu actors;
reaching an arbitrary elapsed time does not substitute for combat completion.

Each foot mission saves a safe stage entrance before its encounter is spawned.
Retry restores equipment and the complete encounter in a new simulation session.
The finale has three shootable machinery vulnerabilities, protection and cooling
cycles, clearly timed floor-lane warnings, and a final physical shutdown. Existing
solid geometry can shield a player from the machinery pulse. No new character
model or playable character is introduced.

The new default checkpoint is `user://campaign/nine_missions.json`. When neither
that file nor its backup exists, Continue can read a valid legacy
`user://campaign/mission1.json`. The next checkpoint writes only the new file.
The original file remains readable by the City-Ambush build. A corrupt existing
new checkpoint uses its validated backup; it never silently falls back to older
Mission 1 progress. Version 1 saves migrate in memory to version 2.

Host snapshots carry chapter state, progression, vehicle state and the boss
clock. Receiving a new session, mission or world recreates transient vehicle and
weakpoint objects. Ordinary snapshots retain those objects. Stage transitions
and unarmed checkpoints remove stale weakpoint collision areas.

Run the following from this checkout in CMD:

```cmd
node scripts/campaign-validation.mjs campaign_journey_state campaign_journey campaign_journey_lifecycle campaign_state
```

The runner gives every fixture an isolated APPDATA directory. Do not run fixtures
against live user preferences or save data.

Actual Windows Godot 4.6.3 headless results:

- `campaign_journey_state`: 32 checks, zero failures. Sequential guards, explicit
  mission selection, registered enemies, duplicate death rejection, save JSON
  roundtrip, safe-stage retry data, malformed data rejection, legacy import,
  unchanged original save bytes, and corrupt-new-save behavior.
- `campaign_journey`: 173 checks, zero failures. All 28 stages of missions 3–9
  instantiate their authored worlds and Annu actors. Actual actor deaths clear
  combat gates. Every physical objective and hold timer advances. All three boss
  cores receive real projectile collisions; protected and duplicate damage are
  rejected. Telegraph timing, exposed-lane damage and stone-baffle protection
  pass. The final peaceful stage requires deliberate interaction. Completion
  checkpoints reload for every mission.
- `campaign_journey_lifecycle`: 17 checks, zero failures. Native same-session snapshot stability,
  same-world/new-session motorcycle replacement without duplicate visual nodes,
  restored ride time, boss stage/new-session replacement and stale unarmed
  collider removal. Also exercises actual defeat/retry and full encounter
  reconstruction. Initial Continue from actual saved missions 2, 3 and 9 restores
  the correct chapter world before creating heroes. This caught and fixed an
  initialization path that briefly tried to spawn chapter actors in preparation.
- Original `campaign_state`: 128 checks, zero failures, retaining Mission 1
  progression, exact five-wave counts, durable charge rules, atomic saves and
  backup recovery.

Report directories for these runs are
`%TEMP%\nest-campaign-validation-Vf3dCI` (32/128 state checks),
`%TEMP%\nest-campaign-validation-v7jDj4` (173 progression checks and initial nine
lifecycle checks), and `%TEMP%\nest-campaign-validation-oZH8qp` (expanded lifecycle).

The first integration run exposed a physical Sky Mirror terminal inside the dish
base. The terminal positions were moved clear and the full progression run then
passed. An initial fixture also assumed the deliberately peaceful final stage
contained enemies; its assertion was corrected to verify deliberate final
interaction instead of calling it during a combat-bypass check. These corrected
failures are not counted as passes before their reruns.

These fixtures drive state and actor events under automation; they are not a
human combat-balance playthrough, a sustained GPU performance test, a real
Discord session, or physical-PC/WAN certification. The native environment still
logs the known root-certificate-store warning. Separate motorcycle, traversal,
rendered and co-op validation should be read alongside these progression checks.
No cloud deployment or public executable publication is implied.
