-- Keep existing IDs, usernames and history. No account data is deleted.
ALTER TABLE users ADD COLUMN auth_provider TEXT NOT NULL DEFAULT 'legacy';
-- Require Discord authorization after switching identity providers.
UPDATE sessions SET revoked = 1;
