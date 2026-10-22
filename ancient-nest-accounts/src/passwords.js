const encoder = new TextEncoder();
const ITERATIONS = 600_000;
const hex = (bytes) => Array.from(new Uint8Array(bytes), b => b.toString(16).padStart(2, '0')).join('');
const bytes = (value) => Uint8Array.from(value.match(/../g), x => parseInt(x, 16));

async function derive(password, salt, iterations) {
  const key = await crypto.subtle.importKey('raw', encoder.encode(password), 'PBKDF2', false, ['deriveBits']);
  return crypto.subtle.deriveBits({ name: 'PBKDF2', salt, iterations, hash: 'SHA-256' }, key, 256);
}

export async function hashPassword(password) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const hash = await derive(password, salt, ITERATIONS);
  return `pbkdf2-sha256$${ITERATIONS}$${hex(salt)}$${hex(hash)}`;
}

// A missing account still performs the same password derivation as a real account.
export const DUMMY_HASH = `pbkdf2-sha256$${ITERATIONS}$${'00'.repeat(16)}$${'00'.repeat(32)}`;

export async function passwordRecord(password) {
  const hash = await hashPassword(password);
  const salt = bytes(hash.split('$')[2]);
  return { hash, salt: btoa(String.fromCharCode(...salt)) };
}

export async function verifyPassword(password, encoded, storedSalt) {
  // Preserve accounts created by the exported 10.2 service (base64 hash + separate salt).
  if (!encoded.startsWith('pbkdf2-sha256$') && storedSalt) {
    const salt = Uint8Array.from(atob(storedSalt), c => c.charCodeAt(0));
    const expected = Uint8Array.from(atob(encoded), c => c.charCodeAt(0));
    const actual = new Uint8Array(await derive(password, salt, 100000));
    let difference = expected.length ^ actual.length;
    for (let i = 0; i < actual.length; i++) difference |= actual[i] ^ (expected[i] ?? 0);
    return difference === 0;
  }
  const parts = /^pbkdf2-sha256\$(\d+)\$([a-f0-9]{32})\$([a-f0-9]{64})$/.exec(encoded);
  if (!parts || Number(parts[1]) !== ITERATIONS) throw new Error('Unsupported password hash');
  const actual = new Uint8Array(await derive(password, bytes(parts[2]), Number(parts[1])));
  const expected = bytes(parts[3]);
  let difference = 0;
  for (let i = 0; i < expected.length; i++) difference |= actual[i] ^ expected[i];
  return difference === 0;
}
