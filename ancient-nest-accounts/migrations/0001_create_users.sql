-- Migration 0001: Users table
-- Email + phone verification, Discord linking, password auth

CREATE TABLE IF NOT EXISTS users (
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
);

CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_discord ON users(discord_id);
