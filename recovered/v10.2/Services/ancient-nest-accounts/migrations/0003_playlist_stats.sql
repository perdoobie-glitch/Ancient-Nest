-- Preserve global legacy records and historical ledgers; new records are scoped.
ALTER TABLE matches ADD COLUMN playlist_id TEXT CHECK(playlist_id IS NULL OR playlist_id IN ('duel_1v1','doubles_2v2','tactical_3v3','arena_4v4','bomb_defuse_5v5'));
CREATE TABLE player_playlist_stats (
 account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
 playlist_id TEXT NOT NULL CHECK(playlist_id IN ('duel_1v1','doubles_2v2','tactical_3v3','arena_4v4','bomb_defuse_5v5')),
 rp INTEGER NOT NULL DEFAULT 1 CHECK(rp>=1),
 matches INTEGER NOT NULL DEFAULT 0, wins INTEGER NOT NULL DEFAULT 0,
 losses INTEGER NOT NULL DEFAULT 0, draws INTEGER NOT NULL DEFAULT 0,
 kills INTEGER NOT NULL DEFAULT 0, deaths INTEGER NOT NULL DEFAULT 0,
 assists INTEGER NOT NULL DEFAULT 0, flags_captured INTEGER NOT NULL DEFAULT 0,
 flags_stopped INTEGER NOT NULL DEFAULT 0,
 PRIMARY KEY(account_id,playlist_id)
);
CREATE INDEX matches_playlist ON matches(playlist_id,id);
