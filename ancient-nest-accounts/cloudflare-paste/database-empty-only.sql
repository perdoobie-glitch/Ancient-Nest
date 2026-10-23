-- EMPTY DATABASE ONLY. If users already exists, STOP and use versioned migrations.
-- Uses your existing ancientnestaccounts database; never drop or reset it.

CREATE TABLE users (
  id              TEXT PRIMARY KEY,
  username        TEXT UNIQUE NOT NULL COLLATE NOCASE,
  password_hash   TEXT NOT NULL,
  password_salt   TEXT NOT NULL,
  email           TEXT UNIQUE NOT NULL,
  email_verified  INTEGER NOT NULL DEFAULT 0,
  phone           TEXT UNIQUE,
  phone_verified  INTEGER NOT NULL DEFAULT 0,
  discord_id      TEXT UNIQUE,
  discord_username TEXT,
  created_at      INTEGER NOT NULL DEFAULT (unixepoch()),
  last_login      INTEGER,
  banned          INTEGER NOT NULL DEFAULT 0,
  metadata        TEXT NOT NULL DEFAULT '{}'
, auth_version INTEGER NOT NULL DEFAULT 0, auth_provider TEXT NOT NULL DEFAULT 'legacy');

CREATE TABLE active_participants (
 account_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
 match_id TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE
);

CREATE TABLE login_attempts (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  username     TEXT,
  ip           TEXT,
  success      INTEGER NOT NULL,
  attempted_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE match_results (
 match_id TEXT PRIMARY KEY REFERENCES matches(id) ON DELETE CASCADE,
 result_hash TEXT NOT NULL, committed_at INTEGER NOT NULL,
 epoch INTEGER NOT NULL, authority_id TEXT NOT NULL
);

CREATE TABLE match_reviews (
 match_id TEXT PRIMARY KEY REFERENCES matches(id) ON DELETE CASCADE,
 reason TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending',
 evidence TEXT NOT NULL, created_at INTEGER NOT NULL
);

CREATE TABLE match_roster (
 match_id TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
 account_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 team INTEGER NOT NULL, starting_rp INTEGER NOT NULL,
 PRIMARY KEY(match_id,account_id)
);

CREATE TABLE matches (
 id TEXT PRIMARY KEY, registration_hash TEXT NOT NULL,
 game_type TEXT NOT NULL, hosting TEXT NOT NULL, map_id TEXT NOT NULL,
 status TEXT NOT NULL DEFAULT 'active' CHECK(status IN('active','finalized','void')),
 epoch INTEGER NOT NULL DEFAULT 1, authority_id TEXT NOT NULL,
 created_at INTEGER NOT NULL, expires_at INTEGER NOT NULL,
 result_hash TEXT, finalized_at INTEGER
, playlist_id TEXT CHECK(playlist_id IS NULL OR playlist_id IN ('duel_1v1','doubles_2v2','tactical_3v3','arena_4v4','bomb_defuse_5v5')));

CREATE TABLE oauth_states (
  state_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_id TEXT NOT NULL REFERENCES sessions(token_id) ON DELETE CASCADE,
  code_verifier TEXT NOT NULL,
  expires_at INTEGER NOT NULL
);

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

CREATE TABLE player_stats (
 account_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
 rp INTEGER NOT NULL DEFAULT 0 CHECK(rp BETWEEN 0 AND 3200),
 matches INTEGER NOT NULL DEFAULT 0, wins INTEGER NOT NULL DEFAULT 0,
 kills INTEGER NOT NULL DEFAULT 0, deaths INTEGER NOT NULL DEFAULT 0,
 assists INTEGER NOT NULL DEFAULT 0, flags_captured INTEGER NOT NULL DEFAULT 0,
 flags_stopped INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE rate_limits (
  key TEXT PRIMARY KEY,
  attempts INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
);

CREATE TABLE rating_floor_audit (
 match_id TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
 account_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 raw_delta INTEGER NOT NULL, applied_delta INTEGER NOT NULL, floor_credit INTEGER NOT NULL,
 PRIMARY KEY(match_id,account_id)
);

CREATE TABLE sessions (
  token_id   TEXT PRIMARY KEY,
  user_id    TEXT NOT NULL,
  issued_at  INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  revoked    INTEGER NOT NULL DEFAULT 0, refresh_hash TEXT, previous_refresh_hash TEXT, previous_refresh_until INTEGER, auth_version INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE verification_codes (
  id          TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL,
  type        TEXT NOT NULL,
  code        TEXT NOT NULL,
  destination TEXT NOT NULL,
  expires_at  INTEGER NOT NULL,
  used        INTEGER NOT NULL DEFAULT 0,
  created_at  INTEGER NOT NULL DEFAULT (unixepoch()), attempts INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE voice_matches (
  id TEXT PRIMARY KEY,
  status TEXT NOT NULL CHECK(status IN ('creating', 'active', 'deleting')),
  expires_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE TABLE voice_members (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  room_id TEXT NOT NULL REFERENCES voice_rooms(id) ON DELETE CASCADE
);

CREATE TABLE voice_rooms (
  id TEXT PRIMARY KEY,
  match_id TEXT NOT NULL REFERENCES voice_matches(id) ON DELETE CASCADE,
  team_id TEXT NOT NULL,
  lobby_id TEXT UNIQUE,
  roster TEXT NOT NULL,
  UNIQUE(match_id, team_id)
);

CREATE INDEX idx_attempts_ip_time ON login_attempts(ip, attempted_at);

CREATE INDEX idx_codes_expires ON verification_codes(expires_at);

CREATE INDEX idx_codes_user_type ON verification_codes(user_id, type, used);

CREATE INDEX idx_sessions_expires ON sessions(expires_at);

CREATE INDEX idx_sessions_user ON sessions(user_id);

CREATE INDEX idx_users_discord ON users(discord_id);

CREATE INDEX idx_users_email ON users(email);

CREATE INDEX idx_users_username ON users(username);

CREATE INDEX matches_playlist ON matches(playlist_id,id);

CREATE INDEX oauth_states_expiry ON oauth_states(expires_at);

CREATE INDEX player_recent_matches ON player_match_results(account_id,committed_at DESC,match_id);

CREATE INDEX rate_limits_expiry ON rate_limits(expires_at);

CREATE INDEX reviews_pending ON match_reviews(status,created_at);

CREATE INDEX sessions_previous_refresh ON sessions(previous_refresh_hash) WHERE previous_refresh_hash IS NOT NULL;

CREATE UNIQUE INDEX sessions_refresh ON sessions(refresh_hash) WHERE refresh_hash IS NOT NULL;

CREATE INDEX voice_match_expiry ON voice_matches(expires_at);

CREATE INDEX voice_members_room ON voice_members(room_id);

CREATE INDEX voice_rooms_match ON voice_rooms(match_id);

CREATE TRIGGER result_authority_guard BEFORE INSERT ON match_results
WHEN NOT EXISTS(SELECT 1 FROM matches WHERE id=NEW.match_id AND status='active' AND epoch=NEW.epoch AND authority_id=NEW.authority_id AND expires_at>=unixepoch())
BEGIN SELECT RAISE(ABORT, 'stale_or_inactive_match'); END;

CREATE TABLE d1_migrations (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE, applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL);
INSERT INTO d1_migrations (name) VALUES ('0001_create_users.sql');
INSERT INTO d1_migrations (name) VALUES ('0002_create_verification_codes.sql');
INSERT INTO d1_migrations (name) VALUES ('0003_create_sessions_login_attempts.sql');
INSERT INTO d1_migrations (name) VALUES ('0004_persistent_sessions_and_voice.sql');
INSERT INTO d1_migrations (name) VALUES ('0005_discord_sign_in.sql');
INSERT INTO d1_migrations (name) VALUES ('0006_matchmaking_rankings.sql');
