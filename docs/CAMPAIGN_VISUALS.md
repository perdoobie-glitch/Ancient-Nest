# Campaign materials and performance pass — 2026-10-25

This is the earlier materials milestone. The subsequent
[guided introduction and atmosphere](CAMPAIGN_GUIDANCE.md) supersedes its build
path and corrects Low/High campaign quality handling. The benchmark below is
historical; the current runner explicitly selects viewport quality/MSAA.

Campaign-only visual work above `4b341b8`; existing multiplayer maps, weapons,
movement, difficulty, prescribed waves and 60 Hz physics are unchanged.

World-space mipmapped noise adds tiled brushed panels, vertical bark grain,
layered soil/moss and foliage color variation. Connectuct has teal/ochre transit
markings, facade windows, equipment screens, planters and hull ribs/navigation
strips. The forest adds low opaque fern clusters, jagged rock dressing, wreckage
panels and warm engine accent lighting. Materials share the existing noise image;
no downloaded assets, image-generation service, new dependency or purchase.
This remains stylized procedural environment art, not final production art.

Directional light uses two shadow splits and a 65 m shadow distance, instead of
the engine's large default range. Color/roughness variation and directional
surface shading remain visible with shadows off. Accent lights have no shadows
and fade with distance. Low quality skips accent lights, reduces ground cover
and uses one texture sample rather than two. Existing player settings still
control shadows and quality; no preference file is migrated or overwritten.

Static meshes merge by material, shadow mode and 16 m horizontal / 12 m vertical
cell. Hull batches remain children of the cinematic ship. NPCs, movers, charge,
locker and ending light remain separate. Collisions and smoke perception remain
unchanged. Small ground-cover fronds use opaque MultiMesh cells, distance culling
and no shadow pass, avoiding alpha overdraw and per-frond nodes/update scripts.

Navigation now tests only the four possible predecessor neighbors per grid
point, replacing the quadratic candidate loop. An 8 m spatial cover index
reduces repeated full cover scans; exact footprint and segment checks remain.
The scenery regression compares every edge against the previous pairwise rule
and 2,500 random indexed queries against exhaustive queries for each region at
High/Low quality. All 24 checks passed, including moving hull and independently
visible mission objects. No routes or collision bodies were removed.

## Measurements on this PC

Godot 4.6.3, OpenGL Compatibility, NVIDIA GTX 1660 Ti, 1280×800, VSync/FPS cap off,
three fixed cameras, 45 warmup + 120 sampled frames/view, default quality/shadows.
Baseline source `4b341b8`, then this pass. Native test profiles are isolated.
Draw counts include shadow passes. Values describe the entire combined visual,
batching and shadow-range change, not batching alone.

| View | Draw calls before → after | Median frame ms before → after | p95 frame ms before → after |
| --- | ---: | ---: | ---: |
| Preparation, spawn | 444 → 340 | 1.244 → 1.207 | 2.024 → 2.015 |
| Preparation, south | 460 → 353 | 1.092 → 1.073 | 1.838 → 1.349 |
| Preparation, east | 385 → 314 | 1.125 → 0.975 | 1.750 → 1.760 |
| Forest, west | 2,804 → 527 | 3.222 → 0.996 | 4.785 → 1.483 |
| Forest, south | 2,812 → 547 | 3.222 → 0.954 | 4.710 → 1.462 |
| Forest, east | 2,116 → 518 | 2.824 → 1.094 | 4.456 → 1.727 |

Synchronous construction: preparation 414.9 → 83.4 ms; forest 874.7 → 169.5 ms.
Forest merges 1,070 static meshes into 267 spatial batches; preparation 494 into
156. Rendering counts also include NPCs, dynamic scenery, ground cover and lights.

Short scenery-only samples exclude AI/gameplay, thermal soak, physical-PC co-op
and sustained full mission performance. They are not gameplay FPS guarantees or
GPU timestamp measurements. Preparation gains are small and its east p95 is
essentially unchanged. Other desktop load and cache warmth can affect timings.
The 12-AI/four-light headless combat fixture passes (38.35 m observed motion,
0.197 ms simulation-span p95 over the final 180 ticks); baseline repeat was
0.219 ms. That small difference is not evidence of a combat CPU speedup.

Raw baseline reports: private checkpoint folder `render-before.json/.log`.
Final renderer reports: `%TEMP%\nest-campaign-render-gG27fl`.
Scenery/spawn: `%TEMP%\nest-campaign-validation-oFrLdJ`.
State/UI: `%TEMP%\nest-campaign-validation-DNZMgT`.
Mission/combat: `%TEMP%\nest-campaign-validation-NDI8jU`.
Four-client ENet: `%TEMP%\nest-campaign-5Obn3q`, all 36 checkpoints passed.
Five rendered preview captures were inspected in private `captures-polish`.
The existing root-certificate-store warning persists; no TLS bypass was added.

## Reproduce from CMD

```cmd
node scripts/campaign-render-benchmark.mjs
node scripts/campaign-validation.mjs campaign_scenery campaign_spawn campaign_mission campaign_combat campaign_state campaign_ui
node scripts/campaign-playtest.mjs 4
```

The renderer runner creates a temporary isolated APPDATA and JSON/log reports.
It opens a short-lived real renderer window and fails on script/shader errors,
timeouts, nonzero engine exit or missing report. Do not run imports/exports
concurrently with source tests or time other test suites against the benchmark.

Private updated PC build: `C:\Users\Corey\Games\AncientNest-Campaign-Visual-20261025\Ancient Nest.exe`.
The existing Campaign Private Test desktop shortcut points here after validation.
The previous `AncientNest-Campaign-Private-20261025-Final` build remains intact.
Close a previously running game and reopen the shortcut to load these resources.
No production deployment, release publication or default-branch merge.
