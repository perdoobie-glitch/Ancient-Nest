// Public game identity never includes Discord identifiers or provider names.
export function needsGameUsername(user) {
  if (user.auth_provider !== 'discord') return false;
  let metadata = {};
  try { metadata = JSON.parse(user.metadata || '{}'); } catch {}
  if (metadata?.game_username_chosen === true) return false;
  if (metadata?.game_username_chosen === false) return true;
  // Preserve previously edited names; prompt only for historical generated defaults.
  return /^Player_[a-f0-9]{16}$/.test(user.username) ||
    (typeof user.discord_id === 'string' && String(user.username).endsWith('_' + user.discord_id));
}

export function publicGameUser(user) {
  return { id: user.id, username: user.username, created_at: user.created_at,
    ...(user.auth_provider === 'discord' ? { needs_username: needsGameUsername(user) } : {}) };
}
