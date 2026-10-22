import { SignJWT } from 'jose';

const audience = 'ancient-nest-matchmaking';
const encoder = new TextEncoder();
const hex = data => Array.from(new Uint8Array(data), b => b.toString(16).padStart(2, '0')).join('');

export function gameIdentity({ HttpError, json, body, bearer, authenticate, rateLimit }) {
  return async function handle(request, env, db, key) {
    const path = new URL(request.url).pathname;
    if (!['/api/game/assertion', '/api/game/verify'].includes(path)) throw new HttpError(404, 'not_found');
    if (request.method !== 'POST') throw new HttpError(405, 'method_not_allowed', { Allow: 'POST' });
    const value = await body(request);
    if (path === '/api/game/assertion') {
      const auth = await authenticate(bearer(request), db, key);
      await rateLimit(db, key, 'game-assertion', auth.user.id, 30);
      const pem = value.public_key;
      if (typeof pem !== 'string' || pem.length > 3000 || !pem.startsWith('-----BEGIN PUBLIC KEY-----') || !pem.includes('-----END PUBLIC KEY-----')) {
        throw new HttpError(400, 'valid_game_public_key_required');
      }
      try {
        const bytes = Uint8Array.from(atob(pem.replace(/-----BEGIN PUBLIC KEY-----|-----END PUBLIC KEY-----|\s/g, '')), c => c.charCodeAt(0));
        const imported = await crypto.subtle.importKey('spki', bytes, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
        if (imported.algorithm.modulusLength < 2048) throw new Error();
      } catch { throw new HttpError(400, 'valid_game_public_key_required'); }
      // Exact PEM bytes match the coordinator's hash of the subsequent hello public_key.
      const keyHash = hex(await crypto.subtle.digest('SHA-256', encoder.encode(pem)));
      const now = Math.floor(Date.now() / 1000);
      const expires = Math.min(now + 600, auth.expires);
      const assertion = await new SignJWT({ kind: 'game-assertion', key_hash: keyHash })
        .setProtectedHeader({ alg: 'HS256', typ: 'JWT' }).setIssuer('ancient-nest-accounts')
        .setAudience(audience).setSubject(auth.user.id).setJti(auth.sessionId)
        .setIssuedAt(now).setExpirationTime(expires).sign(key);
      return json({ assertion, account_id: auth.user.id, username: auth.user.username,
        key_hash: keyHash, expires_in: expires - now });
    }
    if (typeof value.key_hash !== 'string' || !/^[a-f0-9]{64}$/.test(value.key_hash)) throw new HttpError(400, 'valid_key_hash_required');
    await rateLimit(db, key, 'game-verify-ip', request.headers.get('CF-Connecting-IP') ?? 'local', 1200);
    try {
      const auth = await authenticate(value.assertion, db, key, audience);
      if (auth.claims.kind !== 'game-assertion' || auth.claims.key_hash !== value.key_hash) return json({ valid: false }, 401);
      return json({ valid: true, account_id: auth.user.id, username: auth.user.username, key_hash: value.key_hash });
    } catch (error) {
      if (error instanceof HttpError && error.status === 401) return json({ valid: false }, 401);
      throw error;
    }
  };
}
