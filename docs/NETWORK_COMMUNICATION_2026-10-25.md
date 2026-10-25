# Coordination communication follow-up

Baseline: `e8fd54a8a44754b87f8a2e8f07055b6f88e9f8f8`.
The existing Cloudflare Worker/Matchmaker Durable Object remains the only master.
Native WebRTC data channels (direct UDP or compatible TURN) carry gameplay;
the existing ENet direct/LAN path remains. HTTP queue status is a scoped control
fallback, not a replacement for SDP/ICE signaling or gameplay. Required WSS
migration checkpoints remain until a tested replacement exists.

The baseline already implements the requested centralized defaults in
`game/data/network_defaults.json`: 20-second host heartbeat, 60-second host
staleness measured by master receipt, 15-second visible browser refresh,
5-second queue fallback when push is unavailable, 10-second control timeout,
and exponential jittered retries capped at 30 seconds. A valid longer
Retry-After takes precedence. Simulation/input targets remain 60/up to 60 Hz;
automatic snapshot targets remain 20–30 Hz. No physics, weapons, movement,
simulation or replication rates change in this follow-up.

The existing host scheduler staggers its periodic updates, coalesces status
changes and uses match/epoch-scoped short-lived grants and revisions. The master
rejects old authorities and filters stale hosts before listing/allocation.
Joining players do not duplicate host heartbeats. Heartbeat expiry alone does
not elect a host or terminate healthy established gameplay. Existing authority
lease/majority continuity and host-loss rules are preserved.

## Fixes

The server browser now polls only while its screen and game window are visible,
the window is not minimized, and the player is in the party phase. Closing,
minimizing, hiding, queuing or starting gameplay invalidates outstanding directory
requests. Reopening/restoring immediately refreshes with a new request generation;
periodic refresh remains fifteen seconds, with a two-second manual-refresh limit.

Replies must match a nonempty pending request ID and a currently visible browser.
Previously an unsolicited server-list message with no ID could match an empty
pending ID. Late replies from closed/reopened/minimized views and timed-out
requests now leave the cached list intact. Timed-out requests retain the existing
bounded retry schedule. Lobby-creation drafts remain intact during updates.

## Reproduction (CMD)

Set `GODOT_BIN` to the installed Godot 4.6.3 console executable, then from the
canonical repository root run:

```cmd
"%GODOT_BIN%" --headless --path game --script res://tests/browser_schedule.gd
"%GODOT_BIN%" --headless --path game --script res://tests/server_browser.gd
"%GODOT_BIN%" --headless --path game --script res://tests/master_control.gd
"%GODOT_BIN%" --headless --path game --script res://tests/network_policy.gd
node scripts/lobby-lifecycle-playtest.mjs
```

The headless fake-clock browser regression passes 22 checks covering immediate/periodic
refresh, manual rate limiting, outstanding-request suppression, screen/window
visibility, fresh generations, queue/gameplay suppression, cached-list retention,
timeouts and delayed/unsolicited replies. It tests actual scheduling and control
handlers with an isolated fake window/socket, not live provider connectivity.
Headless clients retain logical screen visibility because there is no native
window to show or minimize. The first native lifecycle attempt exposed this
distinction and timed out during directory discovery; the visibility gate was
corrected and a dedicated headless regression added before rerunning.

Godot editor import, existing browser layout/rules checks, master control (18
checks), network policy, host/client camera-resume and account UI checks pass.
The account UI fixture initially failed its obsolete menu-label assertion because
it omitted the already implemented Server Browser and Films entries. Updating
that expectation to the actual baseline navigation restored the account-panel
and service-card checks; no account/authentication implementation changed.

The corrected native lifecycle rerun passes all 28 checkpoints, including custom
lobbies, directory discovery, owner departure/rejoin, control-outage continuity,
reconnect without replacing gameplay transport, results/second matches, ranked
1v1, intact 2v2 parties, checkpoint recovery, host migration and the original
host rejoining. Report: `%TEMP%\nest-lifecycle-SEOI5p\summary.json`.
This uses real native clients and a loopback Miniflare coordinator with guest QA
identities; it is not separate-PC, live Discord or WAN/TURN certification.

No production service, Worker configuration, credentials, account schema or data
changes are required or performed. No releases or binaries are published.
The existing root-certificate warning, real Discord/credential acceptance and
separate-PC direct/TURN/ten-player tests remain separate validation gates.
