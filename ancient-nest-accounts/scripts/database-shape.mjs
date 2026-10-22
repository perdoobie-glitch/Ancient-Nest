// Read-only compatibility check before Wrangler applies versioned migrations.
export const baseColumns = {
  users: ['id', 'username', 'password_hash', 'password_salt', 'email', 'email_verified', 'phone', 'phone_verified', 'discord_id', 'discord_username', 'created_at', 'last_login', 'banned', 'metadata'],
  sessions: ['token_id', 'user_id', 'issued_at', 'expires_at', 'revoked'],
  verification_codes: ['id', 'user_id', 'type', 'code', 'destination', 'expires_at', 'used', 'created_at'],
  login_attempts: ['id', 'username', 'ip', 'success', 'attempted_at'],
};
export const inspectionSql = Object.keys(baseColumns).map(table =>
  `SELECT '${table}' AS table_name, name FROM pragma_table_info('${table}')`).join(' UNION ALL ');
export function assertCompatible(rows) {
  for (const [table, required] of Object.entries(baseColumns)) {
    const columns = rows.filter(row => row.table_name === table).map(row => row.name);
    if (!columns.length) continue; // Fresh database or migration not applied yet.
    const missing = required.filter(column => !columns.includes(column));
    if (missing.length) throw new Error(`Incompatible ${table} table (missing ${missing.join(', ')}). No migrations applied. Back up and review the existing schema before continuing; do not drop production tables.`);
  }
}
