# Replaceable campaign narration

Recorded actor assets are still missing. The game now prefers recordings and
falls back to local OS speech when available; this is synthetic system speech,
not a human performance. No connected generation tool was available, and local
WAV synthesis from the managed agent was denied. The complete approved narration is
preserved in `docs/Ancient_Nest_Codex_Master_Instructions.txt`, section 10, and in
`game/data/campaign_mission1.json`.

Drop reviewed recordings into these slots without changing the approved script:

| File | Authoritative timeline |
| --- | --- |
| intro_01.ogg (or .wav) | 00:00–00:20 |
| intro_02.ogg (or .wav) | 00:20–00:40 |
| intro_03.ogg (or .wav) | 00:40–01:00 |
| intro_04.ogg (or .wav) | 01:00–01:20 |
| intro_05.ogg (or .wav) | 01:20–01:40 |
| intro_06.ogg (or .wav) | 01:40–02:00 |

Each slot is twenty seconds including intentional silence. Direction: a mature,
restrained bass-baritone; quiet pride to concern to determination. Do not imitate
a recognizable actor, accelerate a recording unnaturally or rewrite the script.
Resolve any recording/timing conflict before integration. Speaker-labeled
subtitles and the entire mission work with these files absent.

Brutus's gameplay recordings use `guide_<id>.wav`. The exact spoken lines are
the `voice` fields returned by `NestCampaignGuide.next_step()` in
`game/scripts/campaign_guide.gd`. Deliver one naturally paced, clean mono PCM WAV
per cue, without speaking the filename, UI title or speaker label:

`look`, `walk`, `sprint`, `jump`, `service`, `calibrate`, `recover`, `aim`, `fire`,
`reload`, `switch`, `crouch`, `flashlight`, `wait`, `manifest`, `board`, `boarded`,
`crash`, `charge`, `secure`, `radio`.

The `look` cue includes the beginning-of-gameplay welcome. Guides refer to the
highlighted controls; do not replace that with hard-coded default key names.
Prepare distinct character recordings for the mission data's `departure`,
`crash` and `ending` dialogue as `<section>_<two-digit-line>.wav` (for example
`departure_01.wav`, `crash_03.wav`, `ending_08.wav`). A silent transit title is
not spoken. Keep lines within their existing 10/6/5-second section slots.

Recorded narration routes through Campaign_Dialogue. OS speech instead scales
its own gain by dialogue × master and follows pause/skip/exit, but its timing,
prosody and output routing depend on the installed engine. Isolated QA does not
emit speech. A manual listening pass is required before calling any voice final.
See `docs/CAMPAIGN_GUIDANCE.md` for current voice limitations and validation.

The original menu music is reused on a separate Campaign_Music bus. A quiet
original synthesized engine/standby loop is generated locally on the
Campaign_Effects bus; it is placeholder sound design, not voiceover. Dialogue,
music and effects have separate campaign pause-menu sliders. Existing combat
audio continues through its established buses and global settings.
