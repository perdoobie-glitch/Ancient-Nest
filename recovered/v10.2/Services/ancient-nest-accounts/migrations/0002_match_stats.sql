CREATE TABLE player_stats (
 account_id TEXT PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
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
 account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
 team INTEGER NOT NULL, starting_rp INTEGER NOT NULL,
 PRIMARY KEY(match_id,account_id)
);
-- One rated match at a time per human. This also serializes per-player RP commits.
CREATE TABLE active_participants (
 account_id TEXT PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
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
 account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
 kills INTEGER NOT NULL, deaths INTEGER NOT NULL, assists INTEGER NOT NULL,
 flags_captured INTEGER NOT NULL, flags_stopped INTEGER NOT NULL,
 score_units INTEGER NOT NULL, performance REAL NOT NULL,
 outcome REAL NOT NULL, rp_before INTEGER NOT NULL, rp_after INTEGER NOT NULL,
 committed_at INTEGER NOT NULL,
 PRIMARY KEY(match_id,account_id)
);
CREATE INDEX player_recent_matches ON player_match_results(account_id,committed_at DESC,match_id);
