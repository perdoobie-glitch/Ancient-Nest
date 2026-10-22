-- Migration 0002: Verification codes (email + phone)

CREATE TABLE IF NOT EXISTS verification_codes (
  id          TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL,
  type        TEXT NOT NULL,
  code        TEXT NOT NULL,
  destination TEXT NOT NULL,
  expires_at  INTEGER NOT NULL,
  used        INTEGER NOT NULL DEFAULT 0,
  created_at  INTEGER NOT NULL DEFAULT (unixepoch()),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_codes_user_type ON verification_codes(user_id, type, used);
CREATE INDEX IF NOT EXISTS idx_codes_expires ON verification_codes(expires_at);
