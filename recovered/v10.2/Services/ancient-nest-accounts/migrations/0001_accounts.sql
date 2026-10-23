PRAGMA foreign_keys = ON;
CREATE TABLE accounts (
 id TEXT PRIMARY KEY,
 steam_id TEXT NOT NULL UNIQUE,
 username TEXT NOT NULL,
 username_key TEXT NOT NULL UNIQUE,
 created_at INTEGER NOT NULL,
 disabled INTEGER NOT NULL DEFAULT 0 CHECK(disabled IN(0,1))
);
CREATE TABLE web_sessions (
 token_hash TEXT PRIMARY KEY,
 account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
 csrf_hash TEXT NOT NULL,
 expires_at INTEGER NOT NULL,
 created_at INTEGER NOT NULL
);
CREATE INDEX web_session_expiry ON web_sessions(expires_at);
CREATE TABLE auth_attempts (
 state_hash TEXT PRIMARY KEY,
 browser_hash TEXT NOT NULL,
 return_to TEXT NOT NULL,
 expires_at INTEGER NOT NULL,
 consumed INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE provider_nonces (nonce_hash TEXT PRIMARY KEY, expires_at INTEGER NOT NULL);
CREATE TABLE game_links (
 id TEXT PRIMARY KEY,
 public_key TEXT NOT NULL,
 key_hash TEXT NOT NULL,
 secret_hash TEXT NOT NULL UNIQUE,
 code_hash TEXT NOT NULL UNIQUE,
 challenge TEXT NOT NULL,
 expires_at INTEGER NOT NULL,
 approved_by TEXT REFERENCES accounts(id),
 consumed INTEGER NOT NULL DEFAULT 0,
 created_at INTEGER NOT NULL
);
CREATE INDEX link_expiry ON game_links(expires_at);
CREATE TABLE game_devices (
 id TEXT PRIMARY KEY,
 account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
 public_key TEXT NOT NULL,
 key_hash TEXT NOT NULL UNIQUE,
 refresh_hash TEXT NOT NULL UNIQUE,
 created_at INTEGER NOT NULL,
 expires_at INTEGER NOT NULL,
 revoked INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX device_owner ON game_devices(account_id);
CREATE TABLE request_nonces (nonce_key TEXT PRIMARY KEY, expires_at INTEGER NOT NULL);
CREATE TABLE rate_limits (bucket TEXT PRIMARY KEY, hits INTEGER NOT NULL, expires_at INTEGER NOT NULL);
