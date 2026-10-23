import type { Playlist } from "@/types/playlist";
export const playlists: Playlist[] = [
 { id: "duel_1v1", name: "1v1 Duel", gameType: "free_for_all", teamSize: 1, maxPlayers: 2, hosting: "player_hosted", status: "in_development", description: "Pure head-to-head combat. One opponent. Every decision matters." },
 { id: "doubles_2v2", name: "2v2 Doubles", gameType: "team_deathmatch", teamSize: 2, maxPlayers: 4, hosting: "player_hosted", status: "in_development", description: "Small-team competitive combat. Trade together. Control the fight." },
 { id: "tactical_3v3", name: "3v3 Tactical", gameType: "bomb_defuse", teamSize: 3, maxPlayers: 6, hosting: "player_hosted", status: "in_development", description: "Small-team objective competition. Three players. One coordinated plan." },
 { id: "arena_4v4", name: "4v4 Arena", gameType: "team_deathmatch", teamSize: 4, maxPlayers: 8, hosting: "player_hosted", status: "in_development", description: "Classic team combat. Hold your ground and break their formation." },
 { id: "bomb_defuse_5v5", name: "5v5 Bomb Defuse", gameType: "bomb_defuse", teamSize: 5, maxPlayers: 10, hosting: "player_hosted", status: "in_development", description: "Ancient Nest’s primary large-team tactical playlist. Plant, defend, or defuse." },
];
