-- Append-only rank integrity evidence; preserve every existing account and result.
CREATE TABLE match_reviews (
 match_id TEXT PRIMARY KEY REFERENCES matches(id) ON DELETE CASCADE,
 reason TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending',
 evidence TEXT NOT NULL, created_at INTEGER NOT NULL
);
CREATE TABLE rating_floor_audit (
 match_id TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
 account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
 raw_delta INTEGER NOT NULL, applied_delta INTEGER NOT NULL, floor_credit INTEGER NOT NULL,
 PRIMARY KEY(match_id,account_id)
);
CREATE INDEX reviews_pending ON match_reviews(status,created_at);
