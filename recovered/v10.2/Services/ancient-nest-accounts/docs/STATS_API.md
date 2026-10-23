# Trusted matchmaking stats API — version 1

These endpoints are for the PRIVATE matchmaking coordinator/hub only, over HTTPS.
Header: `Authorization: Bearer <COORDINATOR_API_KEY>`. Generate at least 256 random bits.
Never put this secret in a player-host executable, Godot resource/export, browser,
installer, command-line argument, client config, or source archive. Our helper
`integration/coordinator_client.py` is for the private hub; call blocking operations
via a worker/thread (e.g. asyncio.to_thread) so the WSS loop remains responsive.

Game host -> authenticated existing hub WSS protocol -> private coordinator -> these
APIs -> D1 -> website/profile reads. The game does not write stats directly.

## Register before the match starts
POST `/api/internal/matches/register`:

```json
{
 "match_id":"89bbcece-3d72-4cd2-a90d-924e8cf7aa76",
 "scope":"matchmaking",
 "game_type":"team_deathmatch",
 "hosting":"player_hosted",
 "map_id":"sanctuary",
 "authority_id":"host-public-key-fingerprint",
 "roster":[
   {"account_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","team":0},
   {"account_id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","team":1}
 ]
}
```
Allowed game_type: free_for_all, team_deathmatch, bomb_defuse.
Hosting: player_hosted or dedicated_server. Both are rated when coordinator-authorized.
2–10 verified human accounts, no duplicate UUIDs. Team modes require equal team 0/1
sizes (1v1–5v5). FFA: sort account UUIDs lexically, assign team 0,1,... in that order.
Map/authority IDs: 1–100 letters, numbers, `_ . : -`. UUIDs must be lowercase.
Unknown accounts/custom scope/unbalanced teams are rejected. One active rated match
per account. Existing registration is idempotent only for IDENTICAL normalized content.
Successful new registration returns registered:true, match_id, epoch:1. Never mark a
match as rated locally if registration failed. Active reservation lasts four hours;
hourly cleanup voids expired entries and releases slots without stats. Call void
promptly when matchmaking is abandoned. Do not silently rate an unregistered match.

## Result
POST `/api/internal/matches/result`:
```json
{
 "match_id":"89bbcece-3d72-4cd2-a90d-924e8cf7aa76",
 "epoch":1,
 "authority_id":"host-public-key-fingerprint",
 "winner_team":0,
 "players":[
  {"account_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","kills":10,"deaths":2,"assists":1,"flags_captured":0,"flags_stopped":0},
  {"account_id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","kills":2,"deaths":10,"assists":0,"flags_captured":0,"flags_stopped":0}
 ]
}
```
Complete original roster is mandatory, including disconnected humans. Winner_team=0,
1 or null for a draw; FFA uses per-player score comparisons (winner_team ignored).
All counters must be integers 0–10,000. Current three modes have no flags, so flag
counts must be zero. Future CTF support needs an explicit mode/backend extension.
The payload does NOT contain RP, Player Rating, rank number or client damage values.

The database computes stats and Elo atomically. An authority guard inside the same
transaction rejects inactive/expired/stale-epoch commits. Unique match ledger prevents
duplicates, including concurrent retries. Same payload after success returns
committed:true,duplicate:true; conflicting replay returns 409. Store the exact result
in a durable PRIVATE HUB outbox and retry network/5xx/429 with backoff until confirmed.
Do not retry 400/401/403/409 endlessly or mint a fresh match ID to evade rejection.
Keep original result identity across reconnects and hub/host restarts.

## Migration / cancellation
POST `/api/internal/matches/migrate`:
`{match_id,previous_epoch:1,authority_id:"new-host-fingerprint"}` -> `{epoch:2}`.
Only the coordinator may elect/update authority, after its own authenticated migration
protocol. Old host cannot submit the final result under the new epoch. Persist and
restore epoch/roster/game counters. Migration retries with stale previous_epoch are
rejected, not treated as a new migration. Serialize authority transitions and results
per match in the coordinator. This API does not implement snapshot transfer itself.

POST `/api/internal/matches/void`: `{match_id}` releases active reservations and gives
no rating/stats. Never use void to conceal a completed losing game. Finalized results
are immutable through these endpoints. Disconnecting must not give a player a free
escape from the match outcome. If a replacement bot occupies the human's slot, record
its bot gameplay separately in the game: no fake bot account or bot kills credited to
the human. Keep that human in the roster for team outcome; actual human counters only.

## Ranking rules
Only authorized matchmaking counts; custom/direct-IP/offline/Nest Forge/bot-practice
is unrated. Initial rank #1, RP0. RP range0–3200. Stage = min(21,floor(RP/150)+1),
stage21 covers3000–3200. Each group has I/II/III:
1–3 Forgebound;4–6 Striker;7–9 Sentinel;10–12 Vanguard;13–15 Praetorian;
16–18 War Marshal;19–21 Ascendant.

Performance score = kills − deaths + .25 assists + flag captures + flag stops.
Backend stores quarter-point integer units. Order all humans across both teams by
score. For N players, rating=100−50*(position−1)/(N−1). Average occupied positions
for ties. Six players:100,90,80,70,60,50; all tied:75. Negative scores are valid.
Player Rating stays null/Unrated for first four completed eligible matches; at5 it is
the mean of those5, then the rolling latest5. It is separate from RP and no placement
jump overrides starting at the bottom.

Team Elo expected=1/(1+10^((opponent_mean_RP−own_mean_RP)/400)); delta=round(32*(result−expected)).
Outcome win1/draw.5/loss0. Clamp RP0–3200, decisive outcomes at least1point unless
at a boundary. Equal teams +16/−16. Use registered PRE-MATCH RP, shared base delta
for teammates; actual delta can differ at floor/cap. Individual performance does not
change team-mode Elo. FFA implementation uses mean pairwise score outcome against all
other entrants with their mean RP (explicit policy, not the team formula).

## Trust limit
Player-hosted ranked matches are supported. The coordinator must authenticate the
currently elected host, match ID, roster, epoch, event sequence and normal match end;
check plausible totals and corroborate reports where practical. A valid signature
proves who reported, NOT that a malicious player-host simulated fairly. This kit does
not implement anti-cheat, host event validation, durable hub outbox, consensus, or
snapshot migration in Claude's current branch. Those integration responsibilities
must be completed/tested before public competitive release. Backend validation alone
is not a claim of tamper-proof ranked P2P.
