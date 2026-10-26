# Ancient Nest: the return expedition

Development source: `C:\Users\Corey\Games\AncientNest-Campaign-2-9-20261026`.
This separate worktree starts at City-Ambush source commit `59f005c`. The owner's
playable `AncientNest-City-Ambush-20261025` folder and original source remain intact.

## Story research and continuity

The continuation follows `docs/Ancient_Nest_Codex_Master_Instructions.txt`,
`docs/CAMPAIGN_MISSION1.md`, and the actual dialogue in
`game/data/campaign_mission1.json`. The current campaign supersedes older
Sanctuary-first proposals. Older website faction prose is historical context;
it does not override the campaign's separate Brutus and Ancient AI identities.

Naki originated on Old Earth and have lived on Connectuct for millennia. Their
new world's failing ozone protection requires repairs using gold components in
control, protection and infrastructure systems. Gold is a necessary material,
not fuel burned by the machinery. Anki leads the expedition; Brutus is its
battlefield AI. Ancient AI is the older Old Earth custodian. Annu already inhabit
and defend Old Earth. The first mission ends with the excavation charge secured,
the relay contacted, and the crash cause still unknown.

The new story follows a practical chain: escape the forest, restore freight
access, understand the occupied world's infrastructure, reclaim abandoned
conductors, move them to an extraction corridor, repair the obsolete approach
registry, and release the reserve. The Sky Mirror's recorder comparison supplies
new evidence of an incompatible ancient quarantine handoff; Mission 1 itself
continues to leave that cause unresolved. The final machinery battle repairs
conflicting custodial orders instead of destroying Ancient AI. Anki brings
reclaimed gold and engineering knowledge to Connectuct while preserving the
Annu's active infrastructure.

No new player type, faction, named character or character rig is introduced.
Existing Naki and Annu actors carry combat. Dialogue uses Anki, Brutus, Ancient AI
and the existing Relay. Occasional distant birds are scenery. The final boss is
the custodian's reclamation machinery, built from mechanical geometry, not a new
creature or person. The extraction ship reuses the established expedition hull.

## Playable chapters

| Level | Mission | Progression and physical setting |
| --- | --- | --- |
| 2 | Broken Canopy | Four recovered motorcycles; a roughly five-minute forest service-road escape through six checkpoint sectors, fast tree slaloms, ramps, landings and Annu road ambushes. |
| 3 | The Floodgate | Restore intake pressure, defend the bypass, lower the freight basin and recover the route. Pump cylinders, flanges, pipe gantries, sluice screens, water surfaces, railings and the downstream dam establish the hydraulic plant. |
| 4 | Sanctuary of Records | Align arrival, living-grid and reserve archive rings, defend the recovered ledger, then transmit foundry coordinates. Columned courts, overhead broken arches, inscriptions, rooted stonework and gold floor circuits explain why active conductors must remain. |
| 5 | The Hollow Foundry | Restore cooling before current, defend salvage sorting, stabilize refinement and seal reclaimed crates. Furnace banks, vented equipment, roller conveyors, ducts, crane rails, hanging hooks and retired conductor stock show the actual purpose of the space. |
| 6 | Blackout Rail | Restore a signal breaker, hold the turnout heater, reserve the cargo branch and restore the orbital feed. Freight wagons, ribbed cargo, rail sleepers, signal lamps, platform awnings and overhead wires frame the fighting lanes. |
| 7 | The Sky Mirror | Align two mirrors, hold the corrected approach broadcast and open the corridor. Solar arrays, dishes, support rings, cable runs and lattice antenna towers lead to the flight-recorder revelation. |
| 8 | The Last Reserve | Use the recovered charge on the sealed gallery, verify retired stock, isolate its obsolete transfer lock and defend the reserve controls. A sealed stone interlock reveals broken fragments; ceiling conduits, vault faces, hanging fixtures and labeled crates distinguish the underground reserve. |
| 9 | Ancient Nest | Arm and destroy three exposed machinery actuators through separate vulnerability cycles, dodge warned floor discharges, then authorize departure at the extraction ship. A large rotating reclamation core, radial arms, piston banks, suspension cables, catwalks, cover baffles and gold circuits form the finale. |

Chapters 3–8 each have four ordered encounters, their own machine interactions,
refill racks and two optional surviving records. Combat uses the existing Annu
weapons, perception and loot. Hold objectives require a living squad member near
the active mechanism; leaving pauses progress. The stage cannot complete with
living defenders. Physical interlock shutters open after the preceding stage,
with navigation rebuilt to reflect the open route. The reserve's first sealed
wall opens to show rubble after use of the recovered charge.

The boss uses three shootable weakpoints and actual projectile hit processing.
Its floor indicators precede a discharge; separate dark lanes and stone cover
give readable escape routes. Its health is attached to exposed machine parts,
not a new health-inflated Annu character. The final stage has no extra defender
wave: it leads past recovered cargo to the ship's departure console.

## Data and presentation

`game/data/campaign_chapters.json` contains mission names, briefing dialogue,
34 ordered stage records, timings, enemy counts, optional evidence and endings.
`campaign_chapter_world.gd` constructs each space and applies visible machine
state. `campaign_motorcycle_world.gd` provides the separate road layout.
`campaign_journey.gd` owns host-authoritative progression and integrates with the
existing campaign state, checkpoint, interaction and co-op systems.

Fixed meshes use the established batching path. Moving machinery and stage
indicators are explicitly retained. Bird groups cross briefly on an 83-second
cycle in outdoor missions; they are cosmetic and add no AI actors. Mission
palettes separate wet concrete, weathered stone, foundry steel, night rail,
sunlit antenna fields, underground reserve and the darker reclamation chamber.

Narration remains speaker-labeled in-game text and the existing optional voice
path; this change does not invent recorded voice assets. The environment is
procedural game art using the existing material and model collection, not a
claim of new commissioned character or cinematic assets.

## Validation

Run all preference-writing checks with isolated profiles. The existing
`scripts/campaign-validation.mjs` runner provides isolation. Native route checks
also require `NEST_ISOLATED_QA=1` and a separate `APPDATA` directory. The route
fixture `game/tests/campaign_chapter_routes.gd` drives actual player movement to
every chapter 3–9 objective, both optional records and the final ammunition
rack, and checks the available Annu spawn positions.

The first physical-route pass found two issues: a reserve record was inside a
vault footprint, and the initial final-console route snagged before its target.
The record was moved onto the service aisle; the final console was moved to the
ship's departure apron, improving both access and the ending's geography. A
separate native integration pass found a Sky Mirror objective inside a dish
base; all of that mission's consoles were moved clear of the dish housings.
Final rerun results are recorded in the repository's main validation handoff.

Local automated movement, progression and rendering are distinct from a human
campaign playthrough. Difficulty balance, sustained GPU performance, physical
four-PC co-op and WAN acceptance remain manual checks. This campaign source
does not require a production service deployment, database migration or new
online credentials. Executable publication remains subject to the existing
repository release gates.
