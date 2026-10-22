-- Additions to the exported schema; do not replace already-applied migrations 0001-0003.
ALTER TABLE sessions ADD COLUMN refresh_hash TEXT;
ALTER TABLE sessions ADD COLUMN previous_refresh_hash TEXT;
ALTER TABLE sessions ADD COLUMN previous_refresh_until INTEGER;
ALTER TABLE sessions ADD COLUMN auth_version INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN auth_version INTEGER NOT NULL DEFAULT 0;
CREATE UNIQUE INDEX sessions_refresh ON sessions(refresh_hash) WHERE refresh_hash IS NOT NULL;
CREATE INDEX sessions_previous_refresh ON sessions(previous_refresh_hash) WHERE previous_refresh_hash IS NOT NULL;
ALTER TABLE verification_codes ADD COLUMN attempts INTEGER NOT NULL DEFAULT 0;

CREATE TABLE rate_limits (
  key TEXT PRIMARY KEY,
  attempts INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
);
CREATE INDEX rate_limits_expiry ON rate_limits(expires_at);

CREATE TABLE oauth_states (
  state_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_id TEXT NOT NULL REFERENCES sessions(token_id) ON DELETE CASCADE,
  code_verifier TEXT NOT NULL,
  expires_at INTEGER NOT NULL
);
CREATE INDEX oauth_states_expiry ON oauth_states(expires_at);

CREATE TABLE voice_matches (
  id TEXT PRIMARY KEY,
  status TEXT NOT NULL CHECK(status IN ('creating', 'active', 'deleting')),
  expires_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE TABLE voice_rooms (
  id TEXT PRIMARY KEY,
  match_id TEXT NOT NULL REFERENCES voice_matches(id) ON DELETE CASCADE,
  team_id TEXT NOT NULL,
  lobby_id TEXT UNIQUE,
  roster TEXT NOT NULL,
  UNIQUE(match_id, team_id)
);
CREATE TABLE voice_members (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  room_id TEXT NOT NULL REFERENCES voice_rooms(id) ON DELETE CASCADE
);
CREATE INDEX voice_rooms_match ON voice_rooms(match_id);
CREATE INDEX voice_members_room ON voice_members(room_id);
CREATE INDEX voice_match_expiry ON voice_matches(expires_at);
