# Current project memory

This is the maintained entry point, not an automatic claim that every feature works.
Baseline inspected 2026-10-28: commit e0bf594ed299a3eed7c8b070e09befe3a05a7137.

## Source of truth
- game/: canonical Godot game; README describes six maps, weapons, bots, objectives, player-host networking.
- matchmaking/: coordinator, voting, host selection, admission and results.
- ancient-nest-accounts/: Discord identity, sessions, rankings and team voice.
- monitor/: service monitor. website/: browser menu preview.
- README.md: source/setup overview. VALIDATION.md: recorded tests and limitations.
- PC_CODEX_HANDOFF.md: Windows recovery/setup and remaining release gates. Some historical instructions refer to removed recovered folders; verify actual paths before following them.

## Verified scope
The baseline README identifies 10.5-dev / protocol 10.5-discord1 as a development integration.
VALIDATION.md records local tests. Those historical results have not been rerun as part of adding this memory tool.
Real Windows startup, Discord consent/microphone, two-PC internet transport and live services remain unverified in that report. Do not turn them into completed claims without new evidence.

## Ongoing workflow
Read all saved entries and the actual relevant source before changes. Requests are pending until a later completed record provides evidence. Completion records are claims supported by their evidence, not independent certification.
Record corrections with the old entry ID; preserve history. Update this overview as verified architecture, design and blockers change. Commit this file with the corresponding code change.
For visuals, link versioned scenes/assets and approved screenshots in notes. Do not claim a text summary reveals the rendered appearance of the whole game.
The memory tool is a small foundation that AncientAI can reuse; it does not claim to implement the larger AncientAI organizer.
