SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_cf_%';
PRAGMA table_info(users);
PRAGMA table_info(sessions);
PRAGMA table_info(verification_codes);
