export type GameType = "free_for_all" | "team_deathmatch" | "bomb_defuse";
export interface Playlist { id: string; name: string; gameType: GameType; teamSize: number; maxPlayers: number; hosting: "player_hosted" | "dedicated_server"; description: string; status: "in_development"; }
export const gameTypeLabels: Record<GameType, string> = { free_for_all: "Free-For-All", team_deathmatch: "Team Deathmatch", bomb_defuse: "Bomb Defuse" };
