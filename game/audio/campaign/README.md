# Replaceable campaign narration

No recorded campaign narration is included. No authorized speech-generation tool
was available in the implementation session. The complete approved narration is
preserved in `docs/Ancient_Nest_Codex_Master_Instructions.txt`, section 10, and in
`game/data/campaign_mission1.json`.

Drop reviewed recordings into these slots without changing the approved script:

| File | Authoritative timeline |
| --- | --- |
| intro_01.ogg | 00:00–00:20 |
| intro_02.ogg | 00:20–00:40 |
| intro_03.ogg | 00:40–01:00 |
| intro_04.ogg | 01:00–01:20 |
| intro_05.ogg | 01:20–01:40 |
| intro_06.ogg | 01:40–02:00 |

Each slot is twenty seconds including intentional silence. Direction: a mature,
restrained bass-baritone; quiet pride to concern to determination. Do not imitate
a recognizable actor, accelerate a recording unnaturally or rewrite the script.
Resolve any recording/timing conflict before integration. Speaker-labeled
subtitles and the entire mission work with these files absent.

The original menu music is reused on a separate Campaign_Music bus. A quiet
original synthesized engine/standby loop is generated locally on the
Campaign_Effects bus; it is placeholder sound design, not voiceover. Dialogue,
music and effects have separate campaign pause-menu sliders. Existing combat
audio continues through its established buses and global settings.
