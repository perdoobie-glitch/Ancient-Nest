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
, auth_version INTEGER NOT NULL DEFAULT 0);

CREATE TABLE login_attempts (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  username     TEXT,
  ip           TEXT,
  success      INTEGER NOT NULL,
  attempted_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE oauth_states (
  state_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_id TEXT NOT NULL REFERENCES sessions(token_id) ON DELETE CASCADE,
  code_verifier TEXT NOT NULL,
  expires_at INTEGER NOT NULL
);

CREATE TABLE rate_limits (
  key TEXT PRIMARY KEY,
  attempts INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
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

CREATE INDEX oauth_states_expiry ON oauth_states(expires_at);

CREATE INDEX rate_limits_expiry ON rate_limits(expires_at);

CREATE INDEX sessions_previous_refresh ON sessions(previous_refresh_hash) WHERE previous_refresh_hash IS NOT NULL;

CREATE UNIQUE INDEX sessions_refresh ON sessions(refresh_hash) WHERE refresh_hash IS NOT NULL;

CREATE INDEX voice_match_expiry ON voice_matches(expires_at);

CREATE INDEX voice_members_room ON voice_members(room_id);

CREATE INDEX voice_rooms_match ON voice_rooms(match_id);

CREATE TABLE d1_migrations (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE, applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL);
INSERT INTO d1_migrations (name) VALUES ('0001_create_users.sql');
INSERT INTO d1_migrations (name) VALUES ('0002_create_verification_codes.sql');
INSERT INTO d1_migrations (name) VALUES ('0003_create_sessions_login_attempts.sql');
INSERT INTO d1_migrations (name) VALUES ('0004_persistent_sessions_and_voice.sql');
