# Ancient Nest Master Monitor 10.2

Read-only desktop monitor for authenticated /api/monitor snapshots. Shows all five playlists, six map names, players, searches, live matches and reported scores. Unavailable/stale states remain explicit. It does not host the game or adjudicate ranks.

Enter the matchmaking Worker HTTPS origin and existing private MONITOR_TOKEN at runtime. The token is not bundled. This version uses a new application settings folder; re-enter the URL/key if they are blank after installing. Keep the token private.

Open project.godot in Godot 4.6.3 to edit/export. Update the matchmaking Worker and game to 10.2 together. Account APIs remain 10.1-compatible.
