# City base, trail detail and concealed Annu ? 2026-10-25

The Naki plasma pistol now has an eight-round magazine (both catalog capacity fields). Damage, reserve ammunition and cadence are unchanged. The doubled carbine projectile speed is preserved.

Departure gains fourteen perimeter city buildings with window rows, four raised guard posts, ten striped concrete barriers, twelve fuel drums and evacuation signs. Existing hangars, service vehicles, solar yard and landing pad remain. New skyline buildings are scenery outside the playable apron; equipment stays clear of tutorial and boarding lanes. Fixed geometry uses the existing batching and shared materials; no new dynamic lights or per-object update loops.

Mission 1 gains seeded, repeatable edge dressing: supply cases, rocks, fallen branches, cut stumps, tilted trail markers and mushroom clusters. The central dirt route, encounter locations, climbing gardens and navigation remain intact. Placement is identical across difficulties and peers.

Selected existing Annu (every third defender, offset one) wait concealed at the validated ahead-of-party spawn locations. They spring with a single jump when any living squad member comes within 22 metres, when damaged, or after a 30-second fallback. Then normal AI perception, reaction, movement and cover/smoke visibility apply. These are actual pre-staged enemies, not extra enemies teleported beside the player. All five waves retain 3/5/6/8/12 counts. Host authority and physical loot are preserved.

Validation: Godot import succeeds. The staging fixture verifies eight-round runtime capacity, waiting and single-leap release for every wave, and the exact 34 total. Full physical maze traversal and climbing pass. Spawn safety across four directions, scenery/navigation equivalence, twelve-bot combat and physical weapon loot pass. An initial ambush fixture exposed difficulty-adjusted shields incorrectly triggering release; waiting now compares against the actor's actual initial health/shield and the fixture passes. Reports: `%TEMP%\nest-campaign-validation-j9lbVi` (staging/maze) and `%TEMP%\nest-campaign-validation-qxfzTH` (remaining passing fixtures; its first staging attempt failed before correction).

Rendered captures: `C:\Users\Corey\Games\AncientNest-Campaign-Checkpoint-20261025\captures-city-ambush`. Private Windows target: `C:\Users\Corey\Games\AncientNest-City-Ambush-20261025`. Previous builds and recovery bundles are retained. No production deployment or release; live WAN/Discord certification is not implied.

Two native clients pass all 39 campaign checkpoints, including reconnect, revive, pickups and completion (`%TEMP%\nest-campaign-CPKMGq`). High-quality scenery samples are in `%TEMP%\nest-city-render.json`; these short runs overlapped network fixtures and do not establish full-match FPS.
