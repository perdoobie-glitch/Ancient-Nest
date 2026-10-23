-- Add rated-match data to the existing Discord profiles. Preserve all existing tables.
CREATE TABLE player_stats (
 account_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
 rp INTEGER NOT NULL DEFAULT 0 CHECK(rp BETWEEN 0 AND 3200),
 matches INTEGER NOT NULL DEFAULT 0, wins INTEGER NOT NULL DEFAULT 0,
 kills INTEGER NOT NULL DEFAULT 0, deaths INTEGER NOT NULL DEFAULT 0,
 assists INTEGER NOT NULL DEFAULT 0, flags_captured INTEGER NOT NULL DEFAULT 0,
 flags_stopped INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE matches (
 id TEXT PRIMARY KEY, registration_hash TEXT NOT NULL,
 game_type TEXT NOT NULL, hosting TEXT NOT NULL, map_id TEXT NOT NULL,
 status TEXT NOT NULL DEFAULT 'active' CHECK(status IN('active','finalized','void')),
 epoch INTEGER NOT NULL DEFAULT 1, authority_id TEXT NOT NULL,
 created_at INTEGER NOT NULL, expires_at INTEGER NOT NULL,
 result_hash TEXT, finalized_at INTEGER
);
CREATE TABLE match_roster (
 match_id TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
 account_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 team INTEGER NOT NULL, starting_rp INTEGER NOT NULL,
 PRIMARY KEY(match_id,account_id)
);
-- One rated match at a time per human. This also serializes per-player RP commits.
CREATE TABLE active_participants (
 account_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
 match_id TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE
);
CREATE TABLE match_results (
 match_id TEXT PRIMARY KEY REFERENCES matches(id) ON DELETE CASCADE,
 result_hash TEXT NOT NULL, committed_at INTEGER NOT NULL,
 epoch INTEGER NOT NULL, authority_id TEXT NOT NULL
);
CREATE TRIGGER result_authority_guard BEFORE INSERT ON match_results
WHEN NOT EXISTS(SELECT 1 FROM matches WHERE id=NEW.match_id AND status='active' AND epoch=NEW.epoch AND authority_id=NEW.authority_id AND expires_at>=unixepoch())
BEGIN SELECT RAISE(ABORT, 'stale_or_inactive_match'); END;
CREATE TABLE player_match_results (
 match_id TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
 account_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 kills INTEGER NOT NULL, deaths INTEGER NOT NULL, assists INTEGER NOT NULL,
 flags_captured INTEGER NOT NULL, flags_stopped INTEGER NOT NULL,
 score_units INTEGER NOT NULL, performance REAL NOT NULL,
 outcome REAL NOT NULL, rp_before INTEGER NOT NULL, rp_after INTEGER NOT NULL,
 committed_at INTEGER NOT NULL,
 PRIMARY KEY(match_id,account_id)
);
CREATE INDEX player_recent_matches ON player_match_results(account_id,committed_at DESC,match_id);

-- Preserve global legacy records and historical ledgers; new records are scoped.
ALTER TABLE matches ADD COLUMN playlist_id TEXT CHECK(playlist_id IS NULL OR playlist_id IN ('duel_1v1','doubles_2v2','tactical_3v3','arena_4v4','bomb_defuse_5v5'));
CREATE TABLE player_playlist_stats (
 account_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
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

-- Append-only rank integrity evidence; preserve every existing account and result.
CREATE TABLE match_reviews (
 match_id TEXT PRIMARY KEY REFERENCES matches(id) ON DELETE CASCADE,
 reason TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending',
 evidence TEXT NOT NULL, created_at INTEGER NOT NULL
);
CREATE TABLE rating_floor_audit (
 match_id TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
 account_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 raw_delta INTEGER NOT NULL, applied_delta INTEGER NOT NULL, floor_credit INTEGER NOT NULL,
 PRIMARY KEY(match_id,account_id)
);
CREATE INDEX reviews_pending ON match_reviews(status,created_at);
