// node_modules/jose/dist/webapi/lib/buffer_utils.js
var encoder = new TextEncoder();
var decoder = new TextDecoder();
var strictDecoder = new TextDecoder("utf-8", { fatal: true });
var UINT32_RANGE = 2 ** 32;
function concat(...buffers) {
  const size = buffers.reduce((acc, { length }) => acc + length, 0), buf = new Uint8Array(size);
  let i = 0;
  for (const buffer of buffers)
    buf.set(buffer, i), i += buffer.length;
  return buf;
}
var NON_ASCII = /[^\x00-\x7f]/;
function encode(string) {
  if (typeof string == "string" && string.length >= 128) {
    if (NON_ASCII.test(string))
      throw new TypeError("non-ASCII string encountered in encode()");
    return encoder.encode(string);
  }
  const bytes2 = new Uint8Array(string.length);
  for (let i = 0; i < string.length; i++) {
    const code = string.charCodeAt(i);
    if (code > 127)
      throw new TypeError("non-ASCII string encountered in encode()");
    bytes2[i] = code;
  }
  return bytes2;
}
function encodeBase64(input, url = false) {
  if (Uint8Array.prototype.toBase64)
    return input.toBase64({ alphabet: url ? "base64url" : "base64", omitPadding: url });
  const CHUNK_SIZE = 32768, arr = [];
  for (let i = 0; i < input.length; i += CHUNK_SIZE)
    arr.push(String.fromCharCode.apply(null, input.subarray(i, i + CHUNK_SIZE)));
  const encoded = btoa(arr.join(""));
  return url ? encoded.replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_") : encoded;
}
function decodeBase64(encoded, url = false) {
  if (Uint8Array.fromBase64)
    return Uint8Array.fromBase64(encoded, { alphabet: url ? "base64url" : "base64" });
  if (url) {
    if (encoded.includes("+") || encoded.includes("/"))
      throw new TypeError("Invalid base64url");
    encoded = encoded.replace(/-/g, "+").replace(/_/g, "/");
  }
  const binary = atob(encoded), bytes2 = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++)
    bytes2[i] = binary.charCodeAt(i);
  return bytes2;
}

// node_modules/jose/dist/webapi/util/errors.js
var JOSEError = class extends Error {
  static code = "ERR_JOSE_GENERIC";
  code = "ERR_JOSE_GENERIC";
  constructor(message2, options) {
    super(message2, options), this.name = this.constructor.name, Error.captureStackTrace?.(this, this.constructor);
  }
};
var JWTClaimValidationFailed = class extends JOSEError {
  static code = "ERR_JWT_CLAIM_VALIDATION_FAILED";
  code = "ERR_JWT_CLAIM_VALIDATION_FAILED";
  claim;
  reason;
  payload;
  constructor(message2, payload, claim = "unspecified", reason = "unspecified") {
    super(message2, { cause: { claim, reason, payload } }), this.claim = claim, this.reason = reason, this.payload = payload;
  }
};
var JWTExpired = class extends JOSEError {
  static code = "ERR_JWT_EXPIRED";
  code = "ERR_JWT_EXPIRED";
  claim;
  reason;
  payload;
  constructor(message2, payload, claim = "unspecified", reason = "unspecified") {
    super(message2, { cause: { claim, reason, payload } }), this.claim = claim, this.reason = reason, this.payload = payload;
  }
};
var JOSEAlgNotAllowed = class extends JOSEError {
  static code = "ERR_JOSE_ALG_NOT_ALLOWED";
  code = "ERR_JOSE_ALG_NOT_ALLOWED";
};
var JOSENotSupported = class extends JOSEError {
  static code = "ERR_JOSE_NOT_SUPPORTED";
  code = "ERR_JOSE_NOT_SUPPORTED";
};
var JWSInvalid = class extends JOSEError {
  static code = "ERR_JWS_INVALID";
  code = "ERR_JWS_INVALID";
};
var JWTInvalid = class extends JOSEError {
  static code = "ERR_JWT_INVALID";
  code = "ERR_JWT_INVALID";
};
var JWSSignatureVerificationFailed = class extends JOSEError {
  static code = "ERR_JWS_SIGNATURE_VERIFICATION_FAILED";
  code = "ERR_JWS_SIGNATURE_VERIFICATION_FAILED";
  constructor(message2 = "signature verification failed", options) {
    super(message2, options);
  }
};

// node_modules/jose/dist/webapi/util/base64url.js
var invalid = "The input to be decoded is not correctly encoded.";
function decode(input) {
  try {
    return decodeBase64(typeof input == "string" ? input : decoder.decode(input), true);
  } catch (cause) {
    throw new TypeError(invalid, { cause });
  }
}
function encode2(input) {
  return encodeBase64(typeof input == "string" ? encoder.encode(input) : input, true);
}

// node_modules/jose/dist/webapi/lib/validate.js
function isObject(input) {
  if (typeof input != "object" || input === null || Object.prototype.toString.call(input) !== "[object Object]")
    return false;
  const prototype = Object.getPrototypeOf(input);
  return prototype === null || Object.getPrototypeOf(prototype) === null;
}
function isDisjoint(...headers) {
  const parameters = /* @__PURE__ */ new Set();
  for (const header of headers)
    if (header)
      for (const parameter of Object.keys(header)) {
        if (parameters.has(parameter))
          return false;
        parameters.add(parameter);
      }
  return true;
}
function assertNotSet(value, name) {
  if (value !== void 0)
    throw new TypeError(`${name} can only be called once`);
}
function decodeBase64url(value, label, ErrorClass) {
  try {
    return decode(value);
  } catch (cause) {
    throw new ErrorClass(`Failed to base64url decode the ${label}`, { cause });
  }
}
function encodeAsciiMember(value, label, ErrorClass) {
  try {
    return encode(value);
  } catch (cause) {
    throw new ErrorClass(`The ${label} is not a valid base64url string`, { cause });
  }
}
function parseJoseHeader(encodedProtectedHeader, ErrorClass, message2) {
  let parsed;
  try {
    parsed = JSON.parse(strictDecoder.decode(decode(encodedProtectedHeader)));
  } catch (cause) {
    throw new ErrorClass(message2, { cause });
  }
  if (!isObject(parsed))
    throw new ErrorClass(message2);
  return parsed;
}
var JWS_RECOGNIZED = { __proto__: null, b64: true };
function validateAlgorithms(option, algorithms) {
  if (algorithms !== void 0 && (!Array.isArray(algorithms) || algorithms.some((s) => typeof s != "string")))
    throw new TypeError(`"${option}" option must be an array of strings`);
  return algorithms === void 0 ? void 0 : new Set(algorithms);
}
function validateCritDuplicates(Err, protectedHeader) {
  const { crit } = protectedHeader ?? {};
  if (Array.isArray(crit) && new Set(crit).size !== crit.length)
    throw new Err('"crit" (Critical) Header Parameter MUST NOT contain duplicate values');
}
function validateCrit(Err, recognizedDefault, recognizedOption, protectedHeader, joseHeader) {
  if (joseHeader.crit !== void 0 && protectedHeader?.crit === void 0)
    throw new Err('"crit" (Critical) Header Parameter MUST be integrity protected');
  if (!protectedHeader || protectedHeader.crit === void 0)
    return [];
  if (!Array.isArray(protectedHeader.crit) || protectedHeader.crit.length === 0 || protectedHeader.crit.some((input) => typeof input != "string" || input.length === 0))
    throw new Err('"crit" (Critical) Header Parameter MUST be an array of non-empty strings when present');
  const recognized = recognizedOption === void 0 ? recognizedDefault : { __proto__: null, ...recognizedOption, ...recognizedDefault };
  for (const parameter of protectedHeader.crit) {
    if (!(parameter in recognized))
      throw new JOSENotSupported(`Extension Header Parameter "${parameter}" is not recognized`);
    if (!Object.hasOwn(joseHeader, parameter) || joseHeader[parameter] === void 0)
      throw new Err(`Extension Header Parameter "${parameter}" is missing`);
    if (recognized[parameter] && (!Object.hasOwn(protectedHeader, parameter) || protectedHeader[parameter] === void 0))
      throw new Err(`Extension Header Parameter "${parameter}" MUST be integrity protected`);
  }
  return protectedHeader.crit;
}
function validateB64(protectedHeader, extensions) {
  if (extensions.includes("b64")) {
    const b64 = protectedHeader.b64;
    if (typeof b64 != "boolean")
      throw new JWSInvalid('The "b64" (base64url-encode payload) Header Parameter must be a boolean');
    return b64;
  }
  return true;
}
function serializeJoseHeader(Err, header) {
  let serialized, parsed;
  try {
    serialized = JSON.stringify(header), parsed = JSON.parse(serialized);
  } catch (cause) {
    throw new Err("JOSE Header is not valid JSON", { cause });
  }
  if (!isObject(parsed))
    throw new Err("JOSE Header is not a JSON object");
  return [parsed, serialized];
}

// node_modules/jose/dist/webapi/lib/key.js
var tag = (key) => key[Symbol.toStringTag];
var jwkMatchesOp = (entry, key, usage) => {
  const { alg } = entry;
  if (key.use !== void 0) {
    const expected = usage === "sign" || usage === "verify" ? "sig" : "enc";
    if (key.use !== expected)
      throw new TypeError(`Invalid key for this operation, its "use" must be "${expected}" when present`);
  }
  if (key.alg !== void 0 && key.alg !== alg)
    throw new TypeError(`Invalid key for this operation, its "alg" must be "${alg}" when present`);
  if (Array.isArray(key.key_ops)) {
    const expectedKeyOp = usage === "encrypt" || usage === "decrypt" ? entry.ops?.[usage === "encrypt" ? 0 : 1] : usage;
    if (expectedKeyOp && !key.key_ops.includes(expectedKeyOp))
      throw new TypeError(`Invalid key for this operation, its "key_ops" must include "${expectedKeyOp}" when present`);
  }
};
async function prepareKey(entry, key, usage) {
  const { alg, secret } = entry, requiresPrivateKey = usage === "decrypt" || usage === "sign";
  if (secret && key instanceof Uint8Array)
    return key;
  let normalized, keyObject;
  if (isObject(key)) {
    if (normalized = normalizeJwk(key), typeof normalized.kty != "string")
      throw invalidKeyType(alg, key, secret);
    if (!(secret ? normalized.kty === "oct" && typeof normalized.k == "string" : normalized.kty !== "oct" && (requiresPrivateKey ? normalized.kty === "AKP" && typeof normalized.priv == "string" || typeof normalized.d == "string" : normalized.d === void 0 && normalized.priv === void 0)))
      throw new TypeError(secret ? 'JSON Web Key for symmetric algorithms must have JWK "kty" (Key Type) equal to "oct" and the JWK "k" (Key Value) present' : `JSON Web Key for this operation must be a ${requiresPrivateKey ? "private" : "public"} JWK`);
    if (jwkMatchesOp(entry, normalized, usage), normalized.kty === "oct")
      return decode(normalized.k);
    if (!Object.isFrozen(key)) {
      const { key_ops } = key;
      Array.isArray(key_ops) && Object.freeze(key_ops), Object.freeze(key);
    }
  } else {
    if (!isKeyLike(key))
      throw invalidKeyType(alg, key, secret);
    const expectedType = secret ? "secret" : requiresPrivateKey ? "private" : "public";
    if (key.type !== expectedType && (secret || ["secret", "public", "private"].includes(key.type)))
      throw new TypeError(`${tag(key)} instances must be of type "${expectedType}" for the ${alg} algorithm`);
    if (isCryptoKey(key))
      return key;
    if (keyObject = key, keyObject.type === "secret")
      return keyObject.export();
  }
  cache ||= /* @__PURE__ */ new WeakMap();
  const cacheKey = key;
  let cached = cache.get(cacheKey);
  if (cached?.[alg])
    return cached[alg];
  if (cached || cache.set(cacheKey, cached = {}), keyObject && typeof keyObject.toCryptoKey == "function") {
    const isPublic = keyObject.type === "public", crv = nist[keyObject.asymmetricKeyDetails?.namedCurve], params = entry.resolve?.({ crv, asymmetricKeyType: keyObject.asymmetricKeyType }) ?? entry.subtle;
    return cached[alg] = keyObject.toCryptoKey(params, isPublic, entry.usages[isPublic ? 0 : 1]);
  }
  return normalized ??= keyObject.export({ format: "jwk" }), normalized.alg = alg, cached[alg] = await jwkToKey(entry, normalized);
}
var cache;
var nist = {
  __proto__: null,
  prime256v1: "P-256",
  secp384r1: "P-384",
  secp521r1: "P-521"
};
var isCryptoKey = (key) => {
  if (key?.[Symbol.toStringTag] === "CryptoKey")
    return true;
  try {
    return key instanceof CryptoKey;
  } catch {
    return false;
  }
};
var isKeyObject = (key) => key?.[Symbol.toStringTag] === "KeyObject";
var isKeyLike = (key) => isCryptoKey(key) || isKeyObject(key);
function message(msg, actual, ...types) {
  if (types.length > 2) {
    const last = types.pop();
    msg += `one of type ${types.join(", ")}, or ${last}.`;
  } else types.length === 2 ? msg += `one of type ${types[0]} or ${types[1]}.` : msg += `of type ${types[0]}.`;
  return actual == null ? msg += ` Received ${actual}` : typeof actual == "function" && actual.name ? msg += ` Received function ${actual.name}` : typeof actual == "object" && actual != null && actual.constructor?.name && (msg += ` Received an instance of ${actual.constructor.name}`), msg;
}
function invalidKeyType(alg, actual, secret) {
  const types = ["CryptoKey", "KeyObject", "JSON Web Key"];
  return secret && types.push("Uint8Array"), new TypeError(message(`Key for the ${alg} algorithm must be `, actual, ...types));
}
var unusable = (name, prop = "algorithm.name") => new TypeError(`CryptoKey does not support this operation, its ${prop} must be ${name}`);
function checkUsage(key, usage) {
  if (usage && !key.usages.includes(usage))
    throw new TypeError(`CryptoKey does not support this operation, its usages must include ${usage}.`);
}
function checkModulusLength(alg, key) {
  const { modulusLength } = key.algorithm;
  if (typeof modulusLength != "number" || modulusLength < 2048)
    throw new TypeError(`${alg} requires key modulusLength to be 2048 bits or larger`);
}
function checkCryptoKey(key, expected, usage) {
  const algorithm = key.algorithm;
  if (algorithm.name !== expected.name)
    throw unusable(expected.name);
  if (expected.hash && algorithm.hash?.name !== expected.hash)
    throw unusable(expected.hash, "algorithm.hash");
  if (expected.namedCurve && algorithm.namedCurve !== expected.namedCurve)
    throw unusable(expected.namedCurve, "algorithm.namedCurve");
  if (expected.length !== void 0 && algorithm.length !== expected.length)
    throw unusable(expected.length, "algorithm.length");
  checkUsage(key, usage);
}
function snapshotJwk(jwk) {
  return { __proto__: null, ...jwk };
}
function normalizeJwk(jwk) {
  const normalized = snapshotJwk(jwk);
  if (normalized.ext !== void 0 && typeof normalized.ext != "boolean")
    throw new TypeError('"ext" (Extractable) Parameter must be a boolean');
  if (normalized.key_ops !== void 0) {
    const value = normalized.key_ops, keyOps = Array.isArray(value) ? [...value] : void 0;
    if (!keyOps || keyOps.some((operation) => typeof operation != "string") || new Set(keyOps).size !== keyOps.length)
      throw new TypeError('"key_ops" (Key Operations) Parameter must be an array of unique strings');
    normalized.key_ops = keyOps;
  }
  return normalized;
}
async function jwkToKey(entry, jwk, extractable) {
  if (!entry.kty.includes(jwk.kty))
    throw new JOSENotSupported('Invalid or unsupported JWK "alg" (Algorithm) Parameter value');
  const algorithm = entry.resolve?.({ kty: jwk.kty, crv: jwk.crv }) ?? entry.subtle, isPrivate = !!(jwk.d || jwk.priv), keyData = { ...jwk, ext: extractable ?? jwk.ext };
  return keyData.kty !== "AKP" && delete keyData.alg, delete keyData.use, crypto.subtle.importKey("jwk", keyData, algorithm, keyData.ext ?? !isPrivate, jwk.key_ops ?? entry.usages[isPrivate ? 1 : 0]);
}
async function rawKey(key, expected, usage, extractable = false) {
  return key instanceof Uint8Array && (key = await crypto.subtle.importKey("raw", key, expected, extractable, [usage])), checkCryptoKey(key, expected, usage), key;
}

// node_modules/jose/dist/webapi/lib/key_descriptor.js
function table(entries) {
  const out = { __proto__: null };
  for (const alg in entries)
    out[alg] = { ...entries[alg], alg };
  return out;
}

// node_modules/jose/dist/webapi/lib/jws_algorithms.js
var sig = [["verify"], ["sign"]];
function hmac(bits) {
  const subtle = { name: "HMAC", hash: `SHA-${bits}` };
  return { kty: ["oct"], secret: true, subtle, signing: subtle, usages: sig };
}
function rsa(bits, saltLength) {
  const subtle = { name: saltLength ? "RSA-PSS" : "RSASSA-PKCS1-v1_5", hash: `SHA-${bits}` };
  return {
    kty: ["RSA"],
    subtle,
    signing: saltLength ? { ...subtle, saltLength } : subtle,
    usages: sig,
    minRsaBits: 2048
  };
}
function ecdsa(crv, bits) {
  return {
    kty: ["EC"],
    crv,
    subtle: { name: "ECDSA", namedCurve: crv },
    signing: { name: "ECDSA", hash: `SHA-${bits}` },
    usages: sig
  };
}
function eddsa() {
  const subtle = { name: "Ed25519" };
  return {
    kty: ["OKP"],
    crv: "Ed25519",
    subtle,
    signing: subtle,
    usages: sig
  };
}
function mldsa(parameterSet) {
  const subtle = { name: `ML-DSA-${parameterSet}` };
  return {
    kty: ["AKP"],
    subtle,
    signing: subtle,
    usages: sig
  };
}
var JWS = table({
  HS256: hmac(256),
  HS384: hmac(384),
  HS512: hmac(512),
  RS256: rsa(256),
  RS384: rsa(384),
  RS512: rsa(512),
  PS256: rsa(256, 32),
  PS384: rsa(384, 48),
  PS512: rsa(512, 64),
  ES256: ecdsa("P-256", 256),
  ES384: ecdsa("P-384", 384),
  ES512: ecdsa("P-521", 512),
  EdDSA: eddsa(),
  Ed25519: eddsa(),
  "ML-DSA-44": mldsa(44),
  "ML-DSA-65": mldsa(65),
  "ML-DSA-87": mldsa(87)
});
function jwsAlgorithm(alg) {
  const entry = typeof alg == "string" ? JWS[alg] : void 0;
  if (!entry)
    throw new JOSENotSupported(`alg ${alg} is not supported either by JOSE or your javascript runtime`);
  return entry;
}

// node_modules/jose/dist/webapi/lib/jws_verify.js
function prepareVerify(options) {
  return [options && validateAlgorithms("algorithms", options.algorithms), options?.crit];
}
function parseProtectedHeader(encodedProtectedHeader) {
  return encodedProtectedHeader === void 0 ? {} : parseJoseHeader(encodedProtectedHeader, JWSInvalid, "JWS Protected Header is invalid");
}
function encodeCompactUnencodedPayload(payload) {
  try {
    return encode(payload);
  } catch (cause) {
    throw new JWSInvalid("JWS Compact Serialization payload must use only ASCII characters", {
      cause
    });
  }
}
async function verifySignature(jws, shared, key, encodeUnencodedPayload, parsedProtected) {
  const { protected: encodedProtectedHeader, header, payload: inputPayload } = jws, protectedHeader = parsedProtected ?? parseProtectedHeader(encodedProtectedHeader);
  if (!isDisjoint(protectedHeader, header))
    throw new JWSInvalid("JWS Protected and JWS Unprotected Header Parameter names must be disjoint");
  const joseHeader = { ...protectedHeader, ...header }, b64 = validateB64(protectedHeader, validateCrit(JWSInvalid, JWS_RECOGNIZED, shared[1], protectedHeader, joseHeader)), { alg } = joseHeader;
  if (typeof alg != "string" || !alg)
    throw new JWSInvalid('JWS "alg" (Algorithm) Header Parameter missing or invalid');
  if (shared[0] && !shared[0].has(alg))
    throw new JOSEAlgNotAllowed('"alg" (Algorithm) Header Parameter value not allowed');
  if (b64) {
    if (typeof inputPayload != "string")
      throw new JWSInvalid("JWS Payload must be a string");
  } else if (typeof inputPayload != "string" && !(inputPayload instanceof Uint8Array))
    throw new JWSInvalid("JWS Payload must be a string or an Uint8Array instance");
  const signingPayload = b64 || typeof inputPayload != "string" ? inputPayload : encodeUnencodedPayload(inputPayload);
  let resolvedKey = false;
  typeof key == "function" && (key = await key(protectedHeader, jws), resolvedKey = true);
  const entry = jwsAlgorithm(alg), signingInput = concat(encodedProtectedHeader !== void 0 ? encode(encodedProtectedHeader) : new Uint8Array(), encode("."), typeof signingPayload == "string" ? shared[2] ??= encodeAsciiMember(signingPayload, "payload", JWSInvalid) : signingPayload), signature = decodeBase64url(jws.signature, "signature", JWSInvalid), verificationKey = await prepareKey(entry, key, "verify"), cryptoKey = await rawKey(verificationKey, entry.subtle, "verify");
  entry.minRsaBits && checkModulusLength(entry.alg, cryptoKey);
  let verified = false;
  try {
    verified = await crypto.subtle.verify(entry.signing, cryptoKey, signature, signingInput);
  } catch (cause) {
    throw new JWSSignatureVerificationFailed(void 0, { cause });
  }
  if (!verified)
    throw new JWSSignatureVerificationFailed();
  const result = { payload: typeof signingPayload == "string" ? decodeBase64url(signingPayload, "payload", JWSInvalid) : signingPayload };
  return encodedProtectedHeader !== void 0 && (result.protectedHeader = protectedHeader), header !== void 0 && (result.unprotectedHeader = header), resolvedKey ? [{ ...result, key: verificationKey }, b64] : [result, b64];
}
async function verifyCompact(jws, shared, key) {
  if (jws instanceof Uint8Array && (jws = decoder.decode(jws)), typeof jws != "string")
    throw new JWSInvalid("Compact JWS must be a string or Uint8Array");
  const { 0: protectedHeader, 1: payload, 2: signature, length } = jws.split(".");
  if (length !== 3)
    throw new JWSInvalid("Invalid Compact JWS");
  return verifySignature({ payload, protected: protectedHeader, signature }, shared, key, encodeCompactUnencodedPayload);
}

// node_modules/jose/dist/webapi/lib/jwt_claims_set.js
var epoch = (date) => Math.floor(date.getTime() / 1e3);
var multipliers = {
  s: 1,
  m: 60,
  h: 3600,
  d: 86400,
  w: 604800,
  y: 31557600
};
var REGEX = /^(\+|\-)? ?(\d+|\d+\.\d+) ?(seconds?|secs?|s|minutes?|mins?|m|hours?|hrs?|h|days?|d|weeks?|w|years?|yrs?|y)(?: (ago|from now))?$/i;
var checkFailed = "check_failed";
function invalidDuration() {
  throw new TypeError("Invalid time period format");
}
function secs(str) {
  typeof str != "string" && invalidDuration();
  const matched = REGEX.exec(str);
  (!matched || matched[4] && matched[1]) && invalidDuration();
  const value = parseFloat(matched[2]), durationSeconds = Math.round(value * multipliers[matched[3][0].toLowerCase()]);
  return Number.isFinite(durationSeconds) || invalidDuration(), matched[1] === "-" || matched[4] === "ago" ? -durationSeconds : durationSeconds;
}
function validateInput(label, input) {
  if (!Number.isFinite(input))
    throw new TypeError(`Invalid ${label} input`);
  return input;
}
function validateStringClaim(claim, value) {
  if (typeof value != "string")
    throw new TypeError(`"${claim}" claim must be a string`);
}
function validateAudienceClaim(value) {
  if (typeof value != "string" && (!Array.isArray(value) || Array.from(value).some((member) => typeof member != "string")))
    throw new TypeError('"aud" claim must be a string or an array of strings');
}
function numericDate(value, label) {
  return typeof value == "number" ? validateInput(label, value) : value instanceof Date ? validateInput(label, epoch(value)) : epoch(/* @__PURE__ */ new Date()) + secs(value);
}
var normalizeTyp = (value) => {
  const normalized = value.toLowerCase();
  return value.includes("/") ? normalized : `application/${normalized}`;
};
var checkAudiencePresence = (audPayload, audOption) => typeof audPayload == "string" ? audOption.includes(audPayload) : Array.isArray(audPayload) ? audOption.some((aud) => audPayload.includes(aud)) : false;
function validateNumericDate(claimsSet, claim, required = false) {
  const value = claimsSet[claim];
  if (!(value === void 0 && !required)) {
    if (typeof value != "number")
      throw new JWTClaimValidationFailed(`"${claim}" claim must be a number`, claimsSet, claim, "invalid");
    return value;
  }
}
function unexpectedClaim(claimsSet, claim) {
  throw new JWTClaimValidationFailed(`unexpected "${claim}" claim value`, claimsSet, claim, checkFailed);
}
function validateClaimsSet(protectedHeader, claimsSetBytes, options = {}) {
  let claimsSet;
  try {
    claimsSet = JSON.parse(strictDecoder.decode(claimsSetBytes));
  } catch (cause) {
    throw new JWTInvalid("JWT Claims Set must be a top-level JSON object", { cause });
  }
  if (!isObject(claimsSet))
    throw new JWTInvalid("JWT Claims Set must be a top-level JSON object");
  const { typ } = options;
  if (typ !== void 0 && (typeof protectedHeader.typ != "string" || normalizeTyp(protectedHeader.typ) !== normalizeTyp(typ)))
    throw new JWTClaimValidationFailed('unexpected "typ" JWT header value', claimsSet, "typ", checkFailed);
  const { requiredClaims = [], issuer, subject, audience: audience2, maxTokenAge } = options, presenceCheck = [...requiredClaims];
  maxTokenAge !== void 0 && presenceCheck.push("iat"), audience2 !== void 0 && presenceCheck.push("aud"), subject !== void 0 && presenceCheck.push("sub"), issuer !== void 0 && presenceCheck.push("iss");
  for (const claim of new Set(presenceCheck.reverse()))
    if (!Object.hasOwn(claimsSet, claim))
      throw new JWTClaimValidationFailed(`missing required "${claim}" claim`, claimsSet, claim, "missing");
  issuer !== void 0 && !(Array.isArray(issuer) ? issuer : [issuer]).includes(claimsSet.iss) && unexpectedClaim(claimsSet, "iss"), subject !== void 0 && claimsSet.sub !== subject && unexpectedClaim(claimsSet, "sub"), audience2 !== void 0 && !checkAudiencePresence(claimsSet.aud, typeof audience2 == "string" ? [audience2] : audience2) && unexpectedClaim(claimsSet, "aud");
  const { clockTolerance } = options;
  let tolerance = 0;
  if (typeof clockTolerance == "string")
    tolerance = secs(clockTolerance);
  else if (clockTolerance !== void 0) {
    if (typeof clockTolerance != "number")
      throw new TypeError("Invalid clockTolerance option type");
    tolerance = clockTolerance;
  }
  validateInput("clockTolerance option", tolerance);
  const { currentDate } = options, now2 = validateInput("currentDate option", epoch(currentDate === void 0 ? /* @__PURE__ */ new Date() : currentDate)), iat = validateNumericDate(claimsSet, "iat", maxTokenAge !== void 0), nbf = validateNumericDate(claimsSet, "nbf");
  if (nbf !== void 0 && nbf > now2 + tolerance)
    throw new JWTClaimValidationFailed('"nbf" claim timestamp check failed', claimsSet, "nbf", checkFailed);
  const exp = validateNumericDate(claimsSet, "exp");
  if (exp !== void 0 && exp <= now2 - tolerance)
    throw new JWTExpired('"exp" claim timestamp check failed', claimsSet, "exp", checkFailed);
  if (maxTokenAge !== void 0) {
    const age = now2 - iat, max = validateInput("maxTokenAge option", typeof maxTokenAge == "number" ? maxTokenAge : secs(maxTokenAge));
    if (age - tolerance > max)
      throw new JWTExpired('"iat" claim timestamp check failed (too far in the past)', claimsSet, "iat", checkFailed);
    if (age < -tolerance)
      throw new JWTClaimValidationFailed('"iat" claim timestamp check failed (it should be in the past)', claimsSet, "iat", checkFailed);
  }
  return claimsSet;
}
var producerClaimsSets;
function producerClaimsSet(producer) {
  return producerClaimsSets.get(producer);
}
function jwtClaimsSetBytes(producer) {
  const claimsSet = producerClaimsSet(producer);
  for (const claim of ["iat", "nbf", "exp"]) {
    const value = claimsSet[claim];
    if (typeof value == "number" && !Number.isFinite(value))
      throw new TypeError(`"${claim}" claim must be a finite number`);
  }
  return encoder.encode(JSON.stringify(claimsSet));
}
var JWTClaimsBuilder = class {
  constructor(claimsSet = {}) {
    if (!isObject(claimsSet))
      throw new TypeError("JWT Claims Set MUST be an object");
    (producerClaimsSets ||= /* @__PURE__ */ new WeakMap()).set(this, structuredClone(claimsSet));
  }
  setIssuer(value) {
    return validateStringClaim("iss", value), producerClaimsSet(this).iss = value, this;
  }
  setSubject(value) {
    return validateStringClaim("sub", value), producerClaimsSet(this).sub = value, this;
  }
  setAudience(value) {
    return validateAudienceClaim(value), producerClaimsSet(this).aud = value, this;
  }
  setJti(value) {
    return validateStringClaim("jti", value), producerClaimsSet(this).jti = value, this;
  }
  setNotBefore(value) {
    return producerClaimsSet(this).nbf = numericDate(value, "setNotBefore"), this;
  }
  setExpirationTime(value) {
    return producerClaimsSet(this).exp = numericDate(value, "setExpirationTime"), this;
  }
  setIssuedAt(value) {
    const claimsSet = producerClaimsSet(this);
    return value === void 0 ? claimsSet.iat = epoch(/* @__PURE__ */ new Date()) : typeof value == "string" ? claimsSet.iat = validateInput("setIssuedAt", epoch(/* @__PURE__ */ new Date()) + secs(value)) : claimsSet.iat = numericDate(value, "setIssuedAt"), this;
  }
};

// node_modules/jose/dist/webapi/jwt/verify.js
async function jwtVerify(jwt, key, options) {
  const [verified, b64] = await verifyCompact(jwt, prepareVerify(options), key);
  if (!b64)
    throw new JWTInvalid("JWTs MUST NOT use unencoded payload");
  const payload = validateClaimsSet(verified.protectedHeader, verified.payload, options);
  return { ...verified, payload };
}

// node_modules/jose/dist/webapi/lib/jws_sign.js
async function createSignature(input, key, rejectUnencoded) {
  let [payload, protectedHeader, unprotectedHeader, crit] = input, encodedProtectedHeader = "";
  if (protectedHeader !== void 0) {
    const normalized = serializeJoseHeader(JWSInvalid, protectedHeader);
    protectedHeader = normalized[0], encodedProtectedHeader = encode2(normalized[1]);
  }
  if (unprotectedHeader !== void 0 && (unprotectedHeader = serializeJoseHeader(JWSInvalid, unprotectedHeader)[0]), !protectedHeader && !unprotectedHeader)
    throw new JWSInvalid("either setProtectedHeader or setUnprotectedHeader must be called before #sign()");
  if (!isDisjoint(protectedHeader, unprotectedHeader))
    throw new JWSInvalid("JWS Protected and JWS Unprotected Header Parameter names must be disjoint");
  const joseHeader = { ...protectedHeader, ...unprotectedHeader };
  validateCritDuplicates(JWSInvalid, protectedHeader);
  const b64 = validateB64(protectedHeader, validateCrit(JWSInvalid, JWS_RECOGNIZED, crit, protectedHeader, joseHeader));
  b64 || rejectUnencoded?.();
  const { alg } = joseHeader;
  if (typeof alg != "string" || !alg)
    throw new JWSInvalid('JWS "alg" (Algorithm) Header Parameter missing or invalid');
  const entry = jwsAlgorithm(alg);
  let encodedPayload = "", signingPayload = payload, signingInput;
  if (b64) {
    const encodedPayloadCache = input[4];
    encodedPayloadCache ? (encodedPayload = encodedPayloadCache[0] ??= encode2(payload), signingPayload = encodedPayloadCache[1] ??= encode(encodedPayload)) : (encodedPayload = encode2(payload), signingInput = encoder.encode(`${encodedProtectedHeader}.${encodedPayload}`));
  }
  signingInput ??= concat(encode(encodedProtectedHeader), encode("."), signingPayload);
  const signingKey = await rawKey(await prepareKey(entry, key, "sign"), entry.subtle, "sign");
  entry.minRsaBits && checkModulusLength(entry.alg, signingKey);
  const jws = {
    signature: encode2(new Uint8Array(await crypto.subtle.sign(entry.signing, signingKey, signingInput))),
    payload: encodedPayload
  };
  return protectedHeader && (jws.protected = encodedProtectedHeader), unprotectedHeader && (jws.header = unprotectedHeader), [jws, b64];
}
async function createCompactSignature(payload, protectedHeader, crit, key, rejectUnencoded) {
  const [jws] = await createSignature([payload, protectedHeader, void 0, crit], key, rejectUnencoded);
  return `${jws.protected}.${jws.payload}.${jws.signature}`;
}

// node_modules/jose/dist/webapi/jwt/sign.js
var SignJWT_base = JWTClaimsBuilder;
var SignJWT = class extends SignJWT_base {
  #protectedHeader;
  setProtectedHeader(protectedHeader) {
    return assertNotSet(this.#protectedHeader, "setProtectedHeader"), this.#protectedHeader = protectedHeader, this;
  }
  async sign(key, options) {
    return createCompactSignature(jwtClaimsSetBytes(this), this.#protectedHeader, options?.crit, key, () => {
      throw new JWTInvalid("JWTs MUST NOT use unencoded payload");
    });
  }
};

// src/game-identity.js
var audience = "ancient-nest-matchmaking";
var encoder2 = new TextEncoder();
var hex = (data) => Array.from(new Uint8Array(data), (b) => b.toString(16).padStart(2, "0")).join("");
function gameIdentity({ HttpError: HttpError2, json: json2, body: body2, bearer: bearer2, authenticate: authenticate2, rateLimit: rateLimit2 }) {
  return async function handle(request2, env, db, key) {
    const path = new URL(request2.url).pathname;
    if (!["/api/game/assertion", "/api/game/verify"].includes(path)) throw new HttpError2(404, "not_found");
    if (request2.method !== "POST") throw new HttpError2(405, "method_not_allowed", { Allow: "POST" });
    const value = await body2(request2);
    if (path === "/api/game/assertion") {
      const auth = await authenticate2(bearer2(request2), db, key);
      await rateLimit2(db, key, "game-assertion", auth.user.id, 30);
      const pem = value.public_key;
      if (typeof pem !== "string" || pem.length > 3e3 || !pem.startsWith("-----BEGIN PUBLIC KEY-----") || !pem.includes("-----END PUBLIC KEY-----")) {
        throw new HttpError2(400, "valid_game_public_key_required");
      }
      try {
        const bytes2 = Uint8Array.from(atob(pem.replace(/-----BEGIN PUBLIC KEY-----|-----END PUBLIC KEY-----|\s/g, "")), (c) => c.charCodeAt(0));
        const imported = await crypto.subtle.importKey("spki", bytes2, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
        if (imported.algorithm.modulusLength < 2048) throw new Error();
      } catch {
        throw new HttpError2(400, "valid_game_public_key_required");
      }
      const keyHash = hex(await crypto.subtle.digest("SHA-256", encoder2.encode(pem)));
      const now2 = Math.floor(Date.now() / 1e3);
      const expires = Math.min(now2 + 600, auth.expires);
      const assertion = await new SignJWT({ kind: "game-assertion", key_hash: keyHash }).setProtectedHeader({ alg: "HS256", typ: "JWT" }).setIssuer("ancient-nest-accounts").setAudience(audience).setSubject(auth.user.id).setJti(auth.sessionId).setIssuedAt(now2).setExpirationTime(expires).sign(key);
      return json2({
        assertion,
        account_id: auth.user.id,
        username: auth.user.username,
        key_hash: keyHash,
        expires_in: expires - now2
      });
    }
    if (typeof value.key_hash !== "string" || !/^[a-f0-9]{64}$/.test(value.key_hash)) throw new HttpError2(400, "valid_key_hash_required");
    await rateLimit2(db, key, "game-verify-ip", request2.headers.get("CF-Connecting-IP") ?? "local", 1200);
    try {
      const auth = await authenticate2(value.assertion, db, key, audience);
      if (auth.claims.kind !== "game-assertion" || auth.claims.key_hash !== value.key_hash) return json2({ valid: false }, 401);
      return json2({ valid: true, account_id: auth.user.id, username: auth.user.username, key_hash: value.key_hash });
    } catch (error) {
      if (error instanceof HttpError2 && error.status === 401) return json2({ valid: false }, 401);
      throw error;
    }
  };
}

// src/live-test-page.js
var testPage = `<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Ancient Nest service test</title>
<link rel="stylesheet" href="/setup-test.css">
<main><h1>Ancient Nest service test</h1>
<p>Use your own email and phone to test real delivery. Creating an account sends verification messages and may incur provider charges. Tokens stay in this page's memory. Sign out when finished.</p>
<button id="health">Check configuration</button><pre id="health-status" aria-live="polite"></pre>
<h2>Account</h2><form id="account-form">
<label>Username<input id="username" autocomplete="username" minlength="3" maxlength="24" required></label>
<label>Password<input id="password" type="password" autocomplete="current-password" minlength="8" maxlength="128" required></label>
<label>Email (required for new accounts)<input id="email" type="email" autocomplete="email" maxlength="254"></label>
<label>Phone with country code (required for new accounts)<input id="phone" type="tel" autocomplete="tel" placeholder="+12345678900" maxlength="32"></label>
<div><button type="submit" id="register">Create account / send codes</button><button type="submit" id="login">Sign in</button></div></form>
<p id="status" role="status"></p><pre id="account-status"></pre>
<h2>Verify real delivery</h2><p>Enter the codes you actually received. A successful send request alone does not prove delivery.</p>
<label>Email code<input id="email-code" inputmode="numeric" maxlength="6" autocomplete="one-time-code"></label>
<button data-verify="email">Verify email</button> <button data-resend="email">Resend email</button>
<label>SMS code<input id="phone-code" inputmode="numeric" maxlength="6" autocomplete="one-time-code"></label>
<button data-verify="phone">Verify phone</button> <button data-resend="phone">Resend SMS</button>
<h2>Session and Discord identity</h2><button id="refresh">Test saved-session refresh</button>
<button id="profile">Refresh account status</button><button id="discord">Get Discord linking URL</button>
<a id="discord-link" hidden target="_blank" rel="noopener noreferrer">Authorize Discord</a>
<button id="logout">Sign out this test session</button>
<p>This page tests accounts, delivery and Discord linking. Windows credential storage and two-player audio require the Windows client. Team assignment must come from the trusted coordinator.</p>
</main><script src="/setup-test.js" defer><\/script></html>`;
var testCss = `:root{color-scheme:dark;font:16px system-ui}body{margin:0;background:#111c29;color:#edf3f8}main{max-width:760px;margin:auto;padding:24px}label{display:block;margin:12px 0}input{display:block;box-sizing:border-box;width:100%;padding:10px;margin-top:5px}button,a{display:inline-block;margin:5px 8px 5px 0;padding:10px;cursor:pointer}button:disabled{opacity:.5}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#1b2b3d;padding:12px;border-radius:6px}p{line-height:1.5}#status{min-height:24px}`;
var testScript = `"use strict";
let session = null;
let busy = false;
const el = id => document.getElementById(id);
async function api(path, method = 'GET', data, authorized = true) {
  const headers = {};
  if (data !== undefined) headers['Content-Type'] = 'application/json';
  if (authorized && session) headers.Authorization = 'Bearer ' + session.token;
  const response = await fetch(path, { method, headers, cache: 'no-store', redirect: 'error',
    body: data === undefined ? undefined : JSON.stringify(data), signal: AbortSignal.timeout(15000) });
  const value = await response.json();
  if (!response.ok) throw new Error(value.error || ('HTTP ' + response.status));
  return value;
}
async function action(callback) {
  if (busy) return;
  busy = true;
  document.querySelectorAll('button').forEach(button => { button.disabled = true; });
  el('status').textContent = 'Working\u2026';
  try { await callback(); }
  catch (error) { el('status').textContent = 'Test stopped: ' + error.message; }
  finally {
    busy = false;
    document.querySelectorAll('button').forEach(button => { button.disabled = false; });
  }
}
function requireSession() { if (!session) throw new Error('Sign in or create an account first.'); }
async function profile() {
  requireSession();
  const value = await api('/account');
  el('account-status').textContent = JSON.stringify(value, null, 2);
}
el('account-form').addEventListener('submit', event => {
  event.preventDefault();
  const register = event.submitter?.id !== 'login';
  action(async () => {
    if (session) throw new Error('Sign out the current test session before signing into another account.');
    const data = { username: el('username').value.trim(), password: el('password').value };
    if (register) { data.email = el('email').value.trim(); data.phone = el('phone').value.trim(); }
    try { session = await api(register ? '/register' : '/login', 'POST', data, false); }
    finally { el('password').value = ''; }
    await profile();
    el('status').textContent = session.send_errors?.length
      ? 'Account created, but sending failed: ' + JSON.stringify(session.send_errors)
      : (register ? 'Account created. Check your email and phone, then verify the received codes.' : 'Signed in.');
  });
});
document.querySelectorAll('[data-verify]').forEach(button => button.addEventListener('click', () => action(async () => {
  requireSession();
  const type = button.dataset.verify;
  const code = el(type + '-code').value.trim();
  if (!/^\\d{6}$/.test(code)) throw new Error('Enter the six-digit code you received.');
  await api('/verify/' + type, 'POST', { code });
  el(type + '-code').value = '';
  await profile();
  el('status').textContent = type + ' delivery and verification passed.';
})));
document.querySelectorAll('[data-resend]').forEach(button => button.addEventListener('click', () => action(async () => {
  requireSession();
  await api('/verify/' + button.dataset.resend + '/resend', 'POST', {});
  el('status').textContent = 'Provider accepted the send request. Verify the new code when it arrives.';
})));
el('health').addEventListener('click', () => action(async () => {
  const checks = {};
  for (const path of ['/ready', '/discord/ready']) {
    const response = await fetch(path, { cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(15000) });
    checks[path] = { http_status: response.status, ...await response.json() };
  }
  el('health-status').textContent = JSON.stringify(checks, null, 2);
  el('status').textContent = 'Configuration checked. Delivery and audio must be tested separately.';
}));
el('profile').addEventListener('click', () => action(async () => { await profile(); el('status').textContent = 'Account status updated.'; }));
el('refresh').addEventListener('click', () => action(async () => {
  requireSession();
  session = await api('/refresh', 'POST', { refresh_token: session.refresh_token }, false);
  await profile();
  el('status').textContent = 'Session refresh passed. Windows saved sign-in is tested in the client.';
}));
el('discord').addEventListener('click', () => action(async () => {
  requireSession();
  const value = await api('/auth/discord');
  const url = new URL(value.url);
  if (url.origin !== 'https://discord.com' || url.pathname !== '/oauth2/authorize') throw new Error('Unexpected authorization URL.');
  el('discord-link').href = url.href;
  el('discord-link').hidden = false;
  el('status').textContent = 'Use Authorize Discord, then refresh account status after returning.';
}));
el('logout').addEventListener('click', () => action(async () => {
  requireSession();
  await api('/logout', 'POST', { refresh_token: session.refresh_token }, false);
  session = null;
  el('account-status').textContent = '';
  el('discord-link').hidden = true;
  el('discord-link').removeAttribute('href');
  el('status').textContent = 'Test session revoked and removed from this page.';
}));`;
function liveTestRoute(path) {
  const files = {
    "/setup-test": [testPage, "text/html; charset=utf-8"],
    "/setup-test.js": [testScript, "text/javascript; charset=utf-8"],
    "/setup-test.css": [testCss, "text/css; charset=utf-8"]
  };
  if (!files[path]) return null;
  const [content, type] = files[path];
  return new Response(content, { headers: {
    "Content-Type": type,
    "Cache-Control": "no-store",
    "Content-Security-Policy": "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'",
    "Referrer-Policy": "no-referrer"
  } });
}

// src/passwords.js
var encoder3 = new TextEncoder();
var ITERATIONS = 6e5;
var hex2 = (bytes2) => Array.from(new Uint8Array(bytes2), (b) => b.toString(16).padStart(2, "0")).join("");
var bytes = (value) => Uint8Array.from(value.match(/../g), (x) => parseInt(x, 16));
async function derive(password, salt, iterations) {
  const key = await crypto.subtle.importKey("raw", encoder3.encode(password), "PBKDF2", false, ["deriveBits"]);
  return crypto.subtle.deriveBits({ name: "PBKDF2", salt, iterations, hash: "SHA-256" }, key, 256);
}
async function hashPassword(password) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const hash = await derive(password, salt, ITERATIONS);
  return `pbkdf2-sha256$${ITERATIONS}$${hex2(salt)}$${hex2(hash)}`;
}
var DUMMY_HASH = `pbkdf2-sha256$${ITERATIONS}$${"00".repeat(16)}$${"00".repeat(32)}`;
async function passwordRecord(password) {
  const hash = await hashPassword(password);
  const salt = bytes(hash.split("$")[2]);
  return { hash, salt: btoa(String.fromCharCode(...salt)) };
}
async function verifyPassword(password, encoded, storedSalt) {
  if (!encoded.startsWith("pbkdf2-sha256$") && storedSalt) {
    const salt = Uint8Array.from(atob(storedSalt), (c) => c.charCodeAt(0));
    const expected2 = Uint8Array.from(atob(encoded), (c) => c.charCodeAt(0));
    const actual2 = new Uint8Array(await derive(password, salt, 1e5));
    let difference2 = expected2.length ^ actual2.length;
    for (let i = 0; i < actual2.length; i++) difference2 |= actual2[i] ^ (expected2[i] ?? 0);
    return difference2 === 0;
  }
  const parts = /^pbkdf2-sha256\$(\d+)\$([a-f0-9]{32})\$([a-f0-9]{64})$/.exec(encoded);
  if (!parts || Number(parts[1]) !== ITERATIONS) throw new Error("Unsupported password hash");
  const actual = new Uint8Array(await derive(password, bytes(parts[2]), Number(parts[1])));
  const expected = bytes(parts[3]);
  let difference = 0;
  for (let i = 0; i < expected.length; i++) difference |= actual[i] ^ expected[i];
  return difference === 0;
}

// src/discord.js
var API = "https://discord.com/api/v10";
function desktopRedirect(value) {
  if (typeof value !== "string" || value.length > 128) return false;
  try {
    const url = new URL(value);
    return url.protocol === "http:" && url.hostname === "127.0.0.1" && url.pathname === "/callback" && !url.username && !url.password && !url.search && !url.hash;
  } catch {
    return false;
  }
}
var snowflake = (value) => typeof value === "string" && /^[0-9]{17,20}$/.test(value);
var identifier = (value) => typeof value === "string" && /^[a-zA-Z0-9_-]{1,64}$/.test(value);
function discordRoutes({ HttpError: HttpError2, json: json2, body: body2, authenticate: authenticate2, bearer: bearer2, rateLimit: rateLimit2, coordinator: coordinator2 }) {
  function configured2(env, bot = false) {
    if (!snowflake(env.DISCORD_CLIENT_ID) || typeof env.DISCORD_CLIENT_SECRET !== "string" || env.DISCORD_CLIENT_SECRET.length < 16 || bot && (!env.DISCORD_BOT_TOKEN || env.DISCORD_BOT_TOKEN.length < 16)) {
      throw new HttpError2(503, "discord_not_configured");
    }
  }
  async function remote(env, path, options, { oauth: oauth2 = false, missingOk = false } = {}) {
    let response;
    try {
      const request2 = new Request(API + path, { ...options, redirect: "manual", signal: AbortSignal.timeout(1e4) });
      response = env.DISCORD_HTTP ? await env.DISCORD_HTTP.fetch(request2) : await fetch(request2);
    } catch {
      throw new HttpError2(503, "discord_unavailable");
    }
    if (missingOk && response.status === 404) return null;
    if (response.status === 429) {
      const seconds = Math.min(3600, Math.max(1, Number(response.headers.get("Retry-After")) || 5));
      throw new HttpError2(503, "discord_rate_limited", { "Retry-After": String(Math.ceil(seconds)) });
    }
    if (!response.ok) {
      throw new HttpError2(
        oauth2 && [400, 401].includes(response.status) ? 401 : 503,
        oauth2 && [400, 401].includes(response.status) ? "discord_authorization_expired" : "discord_unavailable"
      );
    }
    if (response.status === 204) return null;
    try {
      return await response.json();
    } catch {
      throw new HttpError2(503, "discord_invalid_response");
    }
  }
  function botOptions(env, method, data) {
    return {
      method,
      headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, "Content-Type": "application/json" },
      ...data ? { body: JSON.stringify(data) } : {}
    };
  }
  async function oauth(env, grant) {
    const form = new URLSearchParams({ client_id: env.DISCORD_CLIENT_ID, client_secret: env.DISCORD_CLIENT_SECRET, ...grant });
    const tokens = await remote(env, "/oauth2/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: form.toString()
    }, { oauth: true });
    if (typeof tokens.access_token !== "string" || typeof tokens.refresh_token !== "string" || tokens.token_type?.toLowerCase() !== "bearer" || !Number.isFinite(tokens.expires_in) || tokens.expires_in <= 0) {
      throw new HttpError2(503, "discord_invalid_response");
    }
    if (!(tokens.scope ?? "").split(/\s+/).includes("sdk.social_layer")) throw new HttpError2(403, "discord_voice_scope_required");
    const user = await remote(env, "/users/@me", { headers: { Authorization: `Bearer ${tokens.access_token}` } }, { oauth: true });
    if (!snowflake(user.id)) throw new HttpError2(503, "discord_invalid_response");
    return { tokens, discordId: user.id, discordUser: user };
  }
  async function linkUser(db, userId, user) {
    if (!snowflake(user?.id)) throw new HttpError2(503, "discord_invalid_response");
    let updated;
    try {
      updated = await db.prepare(`UPDATE users SET discord_id = ?, discord_username = ? WHERE id = ?
        AND banned = 0 AND (discord_id IS NULL OR discord_id = ?) RETURNING discord_id`).bind(user.id, String(user.username || user.global_name || user.id).slice(0, 80), userId, user.id).first();
    } catch (error) {
      if (/UNIQUE constraint failed/.test(String(error))) throw new HttpError2(409, "discord_account_already_linked");
      throw error;
    }
    if (!updated) throw new HttpError2(409, "different_discord_account_linked");
  }
  async function endMatch(env, db, matchId) {
    await db.prepare("UPDATE voice_matches SET status = 'deleting' WHERE id = ?").bind(matchId).run();
    const { results } = await db.prepare("SELECT lobby_id FROM voice_rooms WHERE match_id = ? AND lobby_id IS NOT NULL").bind(matchId).all();
    const removed = await Promise.allSettled(results.map((room) => remote(env, `/lobbies/${room.lobby_id}`, botOptions(env, "DELETE"), { missingOk: true })));
    if (removed.some((result) => result.status === "rejected")) throw new HttpError2(503, "discord_cleanup_pending");
    await db.prepare("DELETE FROM voice_matches WHERE id = ?").bind(matchId).run();
  }
  async function matchResult(db, matchId) {
    const { results } = await db.prepare("SELECT team_id, lobby_id FROM voice_rooms WHERE match_id = ? ORDER BY team_id").bind(matchId).all();
    return { match_id: matchId, teams: results };
  }
  async function createMatch(env, db, value) {
    const now2 = Math.floor(Date.now() / 1e3);
    if (!identifier(value.match_id) || !Number.isSafeInteger(value.expires_at) || value.expires_at <= now2 || value.expires_at > now2 + 21600 || !Array.isArray(value.teams) || value.teams.length < 1 || value.teams.length > 8) throw new HttpError2(400, "invalid_voice_match");
    const teams = value.teams.map((team) => {
      if (!team || !identifier(team.team_id) || !Array.isArray(team.player_ids) || team.player_ids.length < 1 || team.player_ids.length > 25 || team.player_ids.some((id) => typeof id !== "string" || id.length > 64 || !id.length)) {
        throw new HttpError2(400, "invalid_voice_team");
      }
      return { team_id: team.team_id, player_ids: [...team.player_ids].sort() };
    }).sort((a, b) => a.team_id.localeCompare(b.team_id));
    const players = teams.flatMap((team) => team.player_ids);
    if (players.length > 100 || new Set(players).size !== players.length || new Set(teams.map((t) => t.team_id)).size !== teams.length) {
      throw new HttpError2(400, "duplicate_or_excess_voice_players");
    }
    const previous = await db.prepare("SELECT * FROM voice_matches WHERE id = ?").bind(value.match_id).first();
    if (previous) {
      const rooms2 = await db.prepare("SELECT team_id, roster FROM voice_rooms WHERE match_id = ? ORDER BY team_id").bind(value.match_id).all();
      const sameRoster = JSON.stringify(rooms2.results.map((r) => ({ team_id: r.team_id, player_ids: JSON.parse(r.roster) }))) === JSON.stringify(teams);
      if (previous.status === "active" && previous.expires_at > now2 && previous.expires_at === value.expires_at && sameRoster) {
        return json2(await matchResult(db, value.match_id));
      }
      throw new HttpError2(409, "voice_match_conflict", { "Retry-After": "3" });
    }
    const users = await db.prepare(`SELECT id, username, discord_id FROM users
      WHERE discord_id IS NOT NULL AND banned = 0 AND id IN (${players.map(() => "?").join(",")})`).bind(...players).all();
    if (users.results.length !== players.length) throw new HttpError2(409, "players_must_link_discord");
    const byId = new Map(users.results.map((user) => [user.id, user]));
    const statements = [db.prepare("INSERT INTO voice_matches (id, status, expires_at, created_at) VALUES (?, 'creating', ?, ?)").bind(value.match_id, value.expires_at, now2)];
    const rooms = teams.map((team) => ({ ...team, id: crypto.randomUUID() }));
    for (const room of rooms) {
      statements.push(db.prepare("INSERT INTO voice_rooms (id, match_id, team_id, roster) VALUES (?, ?, ?, ?)").bind(room.id, value.match_id, room.team_id, JSON.stringify(room.player_ids)));
      for (const userId of room.player_ids) statements.push(db.prepare(`INSERT INTO voice_members (user_id, room_id)
        SELECT ?, ? WHERE EXISTS (SELECT 1 FROM users WHERE id = ? AND discord_id = ? AND banned = 0)`).bind(userId, room.id, userId, byId.get(userId).discord_id));
    }
    try {
      await db.batch(statements);
    } catch (error) {
      if (/UNIQUE constraint failed/.test(String(error))) throw new HttpError2(409, "players_already_in_voice_match");
      if (/FOREIGN KEY constraint failed/.test(String(error))) throw new HttpError2(409, "players_must_link_discord");
      throw error;
    }
    const createdLobbies = [];
    try {
      const assigned = await db.prepare(`SELECT COUNT(*) AS n FROM voice_members v JOIN voice_rooms r ON r.id = v.room_id
        WHERE r.match_id = ?`).bind(value.match_id).first();
      if (assigned.n !== players.length) throw new HttpError2(409, "players_must_link_discord");
      for (const room of rooms) {
        const lobby = await remote(env, "/lobbies", botOptions(env, "POST", {
          metadata: { match_id: value.match_id, team_id: room.team_id },
          idle_timeout_seconds: Math.max(5, value.expires_at - now2),
          members: room.player_ids.map((id) => ({ id: byId.get(id).discord_id, additional_name: byId.get(id).username }))
        }));
        if (!snowflake(lobby.id)) throw new HttpError2(503, "discord_invalid_response");
        createdLobbies.push(lobby.id);
        const saved = await db.prepare("UPDATE voice_rooms SET lobby_id = ? WHERE id = ?").bind(lobby.id, room.id).run();
        if (saved.meta.changes !== 1) throw new HttpError2(409, "voice_match_cancelled");
      }
      const activated = await db.prepare("UPDATE voice_matches SET status = 'active' WHERE id = ? AND status = 'creating'").bind(value.match_id).run();
      if (activated.meta.changes !== 1) throw new HttpError2(409, "voice_match_cancelled");
    } catch (error) {
      await Promise.allSettled(createdLobbies.map((id) => remote(env, `/lobbies/${id}`, botOptions(env, "DELETE"), { missingOk: true })));
      try {
        await endMatch(env, db, value.match_id);
      } catch {
      }
      throw error;
    }
    return json2(await matchResult(db, value.match_id), 201);
  }
  return {
    link: linkUser,
    async handle(request2, env, db, key) {
      const path = new URL(request2.url).pathname;
      const method = request2.method;
      const routes = {
        "/discord/config": "GET",
        "/discord/ready": "GET",
        "/discord/status": "GET",
        "/discord/exchange": "POST",
        "/discord/refresh": "POST",
        "/discord/unlink": "POST",
        "/voice/session": "GET",
        "/internal/voice/matches": "POST"
      };
      const deletion = /^\/internal\/voice\/matches\/([a-zA-Z0-9_-]{1,64})$/.exec(path);
      const expectedMethod = deletion ? "DELETE" : routes[path];
      if (!expectedMethod) throw new HttpError2(404, "not_found");
      if (method !== expectedMethod) throw new HttpError2(405, "method_not_allowed", { Allow: expectedMethod });
      if (path === "/discord/config" || path === "/discord/ready") {
        const checks = {
          application: snowflake(env.DISCORD_CLIENT_ID),
          client_secret: Boolean(env.DISCORD_CLIENT_SECRET?.length >= 16),
          bot_token: Boolean(env.DISCORD_BOT_TOKEN?.length >= 16),
          database: false
        };
        try {
          await db.batch([
            db.prepare("SELECT id, discord_id, discord_username FROM users LIMIT 0"),
            db.prepare("SELECT id, status, expires_at FROM voice_matches LIMIT 0"),
            db.prepare("SELECT id, match_id, team_id, lobby_id, roster FROM voice_rooms LIMIT 0"),
            db.prepare("SELECT user_id, room_id FROM voice_members LIMIT 0")
          ]);
          checks.database = true;
        } catch {
        }
        const ready = Object.values(checks).every(Boolean);
        if (path === "/discord/ready") return json2({ ready, checks }, ready ? 200 : 503);
        return json2({ enabled: ready, application_id: checks.application ? env.DISCORD_CLIENT_ID : null });
      }
      configured2(env, path.startsWith("/internal/voice/"));
      if (path.startsWith("/internal/voice/")) {
        await coordinator2(request2, env, key);
        if (deletion) {
          await endMatch(env, db, deletion[1]);
          return json2({ success: true });
        }
        return createMatch(env, db, await body2(request2));
      }
      const auth = await authenticate2(bearer2(request2), db, key);
      if (path === "/voice/session") {
        const row = await db.prepare(`SELECT r.lobby_id, r.team_id, m.id AS match_id, m.expires_at FROM voice_members v
          JOIN voice_rooms r ON r.id = v.room_id JOIN voice_matches m ON m.id = r.match_id
          JOIN users d ON d.id = v.user_id AND d.discord_id IS NOT NULL AND d.banned = 0
          WHERE v.user_id = ? AND m.status = 'active' AND m.expires_at > ?`).bind(auth.user.id, Math.floor(Date.now() / 1e3)).first();
        return json2(row ? { assigned: true, ...row } : { assigned: false });
      }
      const link = await db.prepare("SELECT discord_id FROM users WHERE id = ? AND discord_id IS NOT NULL").bind(auth.user.id).first();
      if (path === "/discord/status") return json2({ linked: Boolean(link), discord_id: link?.discord_id ?? null });
      await rateLimit2(db, key, "discord-account", auth.user.id, 20);
      if (path === "/discord/unlink") {
        const removed = await db.prepare(`UPDATE users SET discord_id = NULL, discord_username = NULL WHERE id = ?
          AND NOT EXISTS (SELECT 1 FROM voice_members WHERE user_id = ?) RETURNING id`).bind(auth.user.id, auth.user.id).first();
        if (link && !removed) throw new HttpError2(409, "leave_match_before_unlinking");
        return json2({ success: true });
      }
      const value = await body2(request2);
      let grant;
      if (path === "/discord/exchange") {
        if (typeof value.code !== "string" || !value.code.length || value.code.length > 2048 || typeof value.code_verifier !== "string" || !/^[A-Za-z0-9._~-]{43,128}$/.test(value.code_verifier) || !desktopRedirect(value.redirect_uri)) {
          throw new HttpError2(400, "invalid_discord_authorization");
        }
        grant = { grant_type: "authorization_code", code: value.code, code_verifier: value.code_verifier, redirect_uri: value.redirect_uri };
      } else {
        if (!link) throw new HttpError2(409, "discord_link_required");
        if (typeof value.refresh_token !== "string" || !value.refresh_token.length || value.refresh_token.length > 2048) {
          throw new HttpError2(400, "invalid_discord_refresh_token");
        }
        grant = { grant_type: "refresh_token", refresh_token: value.refresh_token };
      }
      const { tokens, discordId, discordUser } = await oauth(env, grant);
      if (link && link.discord_id !== discordId) throw new HttpError2(409, "different_discord_account_linked");
      await linkUser(db, auth.user.id, discordUser);
      const saved = await db.prepare("SELECT discord_id FROM users WHERE id = ?").bind(auth.user.id).first();
      if (saved?.discord_id !== discordId) throw new HttpError2(409, "different_discord_account_linked");
      return json2({
        discord_id: discordId,
        access_token: tokens.access_token,
        refresh_token: tokens.refresh_token,
        expires_in: tokens.expires_in,
        token_type: "Bearer"
      });
    },
    async cleanup(env) {
      if (!env.DISCORD_BOT_TOKEN) return;
      const now2 = Math.floor(Date.now() / 1e3);
      const db = env.DB.withSession("first-primary");
      const expired = await db.prepare(`SELECT id FROM voice_matches WHERE expires_at <= ? OR status = 'deleting'
        OR (status = 'creating' AND created_at < ?) ORDER BY created_at LIMIT 10`).bind(now2, now2 - 180).all();
      const results = await Promise.allSettled(expired.results.map((row) => endMatch(env, db, row.id)));
      if (results.some((result) => result.status === "rejected")) console.error("Discord voice cleanup pending; will retry");
    }
  };
}

// src/providers.js
var API2 = "https://discord.com/api/v10";
async function request(env, url, options) {
  let response;
  try {
    const req = new Request(url, { ...options, redirect: "manual", signal: AbortSignal.timeout(1e4) });
    response = env.PROVIDER_HTTP ? await env.PROVIDER_HTTP.fetch(req) : await fetch(req);
  } catch {
    throw new Error("provider_unavailable");
  }
  if (!response.ok) throw new Error(response.status === 429 ? "provider_rate_limited" : "provider_request_failed");
  return response;
}
function buildDiscordAuthorizeUrl(env, redirectUri, state, challenge) {
  const params = new URLSearchParams({
    client_id: env.DISCORD_CLIENT_ID,
    redirect_uri: redirectUri,
    response_type: "code",
    scope: "identify sdk.social_layer",
    state,
    code_challenge: challenge,
    code_challenge_method: "S256"
  });
  return `https://discord.com/oauth2/authorize?${params}`;
}
async function exchangeDiscordCode(env, code, redirectUri, verifier) {
  const response = await request(env, `${API2}/oauth2/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: env.DISCORD_CLIENT_ID,
      client_secret: env.DISCORD_CLIENT_SECRET,
      grant_type: "authorization_code",
      code,
      redirect_uri: redirectUri,
      code_verifier: verifier
    }).toString()
  });
  return response.json();
}
async function getDiscordUser(accessToken2, env) {
  return (await request(env, `${API2}/users/@me`, { headers: { Authorization: `Bearer ${accessToken2}` } })).json();
}
async function sendVerificationEmail(env, to, code) {
  if (!env.RESEND_API_KEY) throw new Error("email_not_configured");
  await request(env, "https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      from: env.EMAIL_FROM || "noreply@ancientnest.net",
      to,
      subject: "Ancient Nest \u2014 Verify your email",
      html: `<p>Your Ancient Nest verification code is <strong>${code}</strong>.</p><p>It expires in 10 minutes.</p>`
    })
  });
  return true;
}
async function sendVerificationSMS(env, to, code) {
  if (!env.TWILIO_ACCOUNT_SID || !env.TWILIO_AUTH_TOKEN || !env.TWILIO_FROM) throw new Error("sms_not_configured");
  if (!/^AC[0-9a-f]{32}$/i.test(env.TWILIO_ACCOUNT_SID)) throw new Error("sms_not_configured");
  const auth = btoa(`${env.TWILIO_ACCOUNT_SID}:${env.TWILIO_AUTH_TOKEN}`);
  await request(env, `https://api.twilio.com/2010-04-01/Accounts/${env.TWILIO_ACCOUNT_SID}/Messages.json`, {
    method: "POST",
    headers: { Authorization: `Basic ${auth}`, "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      From: env.TWILIO_FROM,
      To: to,
      Body: `Ancient Nest: your verification code is ${code}. It expires in 10 minutes.`
    }).toString()
  });
  return true;
}

// src/account-extras.js
var enc = new TextEncoder();
var now = () => Math.floor(Date.now() / 1e3);
var hex3 = (bytes2) => Array.from(new Uint8Array(bytes2), (b) => b.toString(16).padStart(2, "0")).join("");
var random = () => crypto.getRandomValues(new Uint8Array(32));
var base64url = (bytes2) => btoa(String.fromCharCode(...bytes2)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
function verificationStatus(user) {
  const email = Boolean(user.email_verified);
  const phone = Boolean(user.phone_verified);
  const discord2 = Boolean(user.discord_id);
  return { email, phone, discord: discord2, fully_verified: email && phone && discord2 };
}
function accountExtras({
  HttpError: HttpError2,
  json: json2,
  body: body2,
  authenticate: authenticate2,
  bearer: bearer2,
  rateLimit: rateLimit2,
  passwordRecord: passwordRecord2,
  verifyPassword: verifyPassword2,
  tokenHash: tokenHash2,
  discord: discord2
}) {
  async function digest(key, text) {
    const imported = await crypto.subtle.importKey("raw", key, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
    return hex3(await crypto.subtle.sign("HMAC", imported, enc.encode(text)));
  }
  function registration(value) {
    const email = typeof value.email === "string" ? value.email.trim().toLowerCase() : "";
    if (!email || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new HttpError2(400, "valid_email_required");
    let phone = typeof value.phone === "string" ? value.phone.replace(/[\s()-]/g, "") : "";
    if (!phone.startsWith("+")) phone = "+" + phone;
    if (!/^\+[1-9]\d{6,14}$/.test(phone)) throw new HttpError2(400, "valid_phone_required");
    return { email, phone };
  }
  async function sendCode(env, db, key, user, type, ip) {
    await rateLimit2(db, key, "verification-send-ip", ip, 10);
    await rateLimit2(db, key, `verification-send-${type}`, user.id, 3);
    const destination = type === "email" ? user.email : user.phone;
    if (!destination) throw new HttpError2(400, "verification_destination_missing");
    let code = "";
    while (code.length < 6) for (const value of crypto.getRandomValues(new Uint8Array(12))) {
      if (value < 250 && code.length < 6) code += String(value % 10);
    }
    const id = crypto.randomUUID();
    const codeHash = "hmac:" + await digest(key, `code:${user.id}:${type}:${id}:${code}`);
    await db.batch([
      db.prepare("UPDATE verification_codes SET used = 1 WHERE user_id = ? AND type = ? AND used = 0").bind(user.id, type),
      db.prepare(`INSERT INTO verification_codes (id, user_id, type, code, destination, expires_at)
        VALUES (?, ?, ?, ?, ?, ?)`).bind(id, user.id, type, codeHash, destination, now() + 600)
    ]);
    try {
      if (type === "email") await sendVerificationEmail(env, destination, code);
      else await sendVerificationSMS(env, destination, code);
    } catch (error) {
      throw new HttpError2(503, error.message);
    }
    return { success: true, type, destination: type === "phone" ? destination.slice(0, -4) + "****" : destination };
  }
  async function account(db, id) {
    const user = await db.prepare("SELECT * FROM users WHERE id = ?").bind(id).first();
    if (!user) throw new HttpError2(404, "account_not_found");
    return {
      id: user.id,
      username: user.username,
      email: user.email,
      email_verified: Boolean(user.email_verified),
      phone: user.phone ? user.phone.slice(0, -4) + "****" : null,
      phone_verified: Boolean(user.phone_verified),
      discord_id: user.discord_id,
      discord_username: user.discord_username,
      discord_linked: Boolean(user.discord_id),
      created_at: user.created_at,
      last_login: user.last_login,
      verification: verificationStatus(user)
    };
  }
  function callbackUri(env) {
    try {
      const url = new URL(env.PUBLIC_URL);
      if (url.protocol !== "https:" || url.username || url.password || url.search || url.hash || url.pathname !== "/") throw new Error();
      return new URL("/auth/discord/callback", url).href;
    } catch {
      throw new HttpError2(503, "public_url_not_configured");
    }
  }
  return {
    registration,
    account,
    async afterRegister(env, db, key, user, ip) {
      const errors = [];
      for (const type of ["email", "phone"]) {
        try {
          await sendCode(env, db, key, user, type, ip);
        } catch (error) {
          errors.push({ [type]: error instanceof HttpError2 ? error.message : "provider_unavailable" });
        }
      }
      return errors;
    },
    async audit(db, key, username, ip, success) {
      await db.prepare("INSERT INTO login_attempts (username, ip, success) VALUES (?, ?, ?)").bind(username, await digest(key, `audit-ip:${ip}`), success ? 1 : 0).run();
    },
    async handle(request2, env, db, key) {
      const url = new URL(request2.url);
      const path = url.pathname;
      const methods = {
        "/verify/email": "POST",
        "/verify/phone": "POST",
        "/verify/email/resend": "POST",
        "/verify/phone/resend": "POST",
        "/account/password": "POST",
        "/auth/discord": "GET",
        "/auth/discord/callback": "GET"
      };
      if (!methods[path]) throw new HttpError2(404, "not_found");
      if (request2.method !== methods[path]) throw new HttpError2(405, "method_not_allowed", { Allow: methods[path] });
      if (path === "/auth/discord/callback") {
        const state = url.searchParams.get("state") ?? "";
        const code = url.searchParams.get("code") ?? "";
        if (!/^[a-f0-9]{64}$/.test(state) || !code || code.length > 2048) throw new HttpError2(400, "invalid_discord_callback");
        const saved = await db.prepare(`DELETE FROM oauth_states WHERE state_hash = ? AND expires_at > ?
          AND EXISTS (SELECT 1 FROM sessions s JOIN users u ON u.id = s.user_id
            WHERE s.token_id = oauth_states.token_id AND s.user_id = oauth_states.user_id
            AND s.revoked = 0 AND s.expires_at > ? AND u.banned = 0 AND s.auth_version = u.auth_version)
          RETURNING user_id, code_verifier`).bind(await tokenHash2(state), now(), now()).first();
        if (!saved) throw new HttpError2(400, "invalid_or_expired_oauth_state");
        let user2;
        try {
          const tokens = await exchangeDiscordCode(env, code, callbackUri(env), saved.code_verifier);
          if (!(tokens.scope ?? "").split(/\s+/).includes("sdk.social_layer")) throw new HttpError2(403, "discord_voice_scope_required");
          user2 = await getDiscordUser(tokens.access_token, env);
        } catch (error) {
          if (error instanceof HttpError2) throw error;
          throw new HttpError2(503, "discord_linking_failed");
        }
        await discord2.link(db, saved.user_id, user2);
        return new Response(
          '<!doctype html><meta charset="utf-8"><title>Ancient Nest</title><p>Discord linked successfully. You can close this window and return to the game.</p>',
          { headers: { "Content-Type": "text/html; charset=utf-8", "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'" } }
        );
      }
      const auth = await authenticate2(bearer2(request2), db, key);
      if (path === "/auth/discord") {
        if (!env.DISCORD_CLIENT_ID || !env.DISCORD_CLIENT_SECRET) throw new HttpError2(503, "discord_not_configured");
        await rateLimit2(db, key, "discord-account", auth.user.id, 20);
        const redirect = callbackUri(env);
        const state = hex3(random());
        const verifier = base64url(random());
        const challenge = base64url(new Uint8Array(await crypto.subtle.digest("SHA-256", enc.encode(verifier))));
        await db.prepare(`INSERT INTO oauth_states (state_hash, user_id, token_id, code_verifier, expires_at)
          VALUES (?, ?, ?, ?, ?)`).bind(await tokenHash2(state), auth.user.id, auth.sessionId, verifier, now() + 600).run();
        return json2({ url: buildDiscordAuthorizeUrl(env, redirect, state, challenge), redirect_uri: redirect });
      }
      if (path === "/account/password") {
        await rateLimit2(db, key, "password-change", auth.user.id, 5);
        const value2 = await body2(request2);
        if (typeof value2.current_password !== "string" || value2.current_password.length > 128 || typeof value2.new_password !== "string" || value2.new_password.length < 8 || value2.new_password.length > 128) {
          throw new HttpError2(400, "password_must_be_8_to_128_characters");
        }
        const user2 = await db.prepare("SELECT * FROM users WHERE id = ?").bind(auth.user.id).first();
        if (!await verifyPassword2(value2.current_password, user2.password_hash, user2.password_salt)) throw new HttpError2(401, "invalid_credentials");
        const updated = await passwordRecord2(value2.new_password);
        const results2 = await db.batch([
          db.prepare(`UPDATE users SET password_hash = ?, password_salt = ?, auth_version = auth_version + 1
            WHERE id = ? AND auth_version = ?`).bind(updated.hash, updated.salt, user2.id, user2.auth_version),
          db.prepare("UPDATE sessions SET revoked = 1 WHERE user_id = ? AND auth_version <= ?").bind(user2.id, user2.auth_version)
        ]);
        if (results2[0].meta.changes !== 1) throw new HttpError2(409, "account_changed_retry");
        return json2({ success: true });
      }
      const type = path.includes("/email") ? "email" : "phone";
      const user = await db.prepare("SELECT * FROM users WHERE id = ?").bind(auth.user.id).first();
      if (user[`${type}_verified`]) throw new HttpError2(400, `${type}_already_verified`);
      if (path.endsWith("/resend")) {
        return json2(await sendCode(env, db, key, user, type, request2.headers.get("CF-Connecting-IP") ?? "local"));
      }
      await rateLimit2(db, key, `verify-${type}`, user.id, 20);
      const value = await body2(request2);
      if (typeof value.code !== "string" || !/^\d{6}$/.test(value.code)) throw new HttpError2(400, "six_digit_code_required");
      const record = await db.prepare(`SELECT id FROM verification_codes WHERE user_id = ? AND type = ?
        AND used = 0 AND expires_at > ? ORDER BY created_at DESC, rowid DESC LIMIT 1`).bind(user.id, type, now()).first();
      if (!record) throw new HttpError2(400, "invalid_or_expired_code");
      const attempted = await db.prepare(`UPDATE verification_codes SET attempts = attempts + 1
        WHERE id = ? AND used = 0 AND expires_at > ? AND attempts < 5 RETURNING code, destination`).bind(record.id, now()).first();
      if (!attempted) throw new HttpError2(429, "verification_attempts_exhausted");
      const expected = attempted.code.startsWith("hmac:") ? "hmac:" + await digest(key, `code:${user.id}:${type}:${record.id}:${value.code}`) : value.code;
      if (expected !== attempted.code) throw new HttpError2(400, "invalid_or_expired_code");
      const results = await db.batch([
        // type is a fixed email/phone enum, never user-supplied SQL.
        db.prepare(`UPDATE users SET ${type}_verified = 1 WHERE id = ? AND ${type} = ?
          AND EXISTS (SELECT 1 FROM verification_codes WHERE id = ? AND used = 0 AND expires_at > ?)`).bind(user.id, attempted.destination, record.id, now()),
        db.prepare("UPDATE verification_codes SET used = 1 WHERE id = ? AND used = 0").bind(record.id)
      ]);
      if (results[0].meta.changes !== 1 || results[1].meta.changes !== 1) throw new HttpError2(400, "invalid_or_expired_code");
      const verified = await db.prepare("SELECT * FROM users WHERE id = ?").bind(user.id).first();
      return json2({ success: true, verification: verificationStatus(verified) });
    }
  };
}

// src/index.js
var VERSION = "10.3-accounts";
var ISSUER = "ancient-nest-accounts";
var AUDIENCE = "ancient-nest";
var WINDOW = 900;
var DEVICE_TTL = 90 * 86400;
var REFRESH_RETRY_GRACE = 60;
var encoder4 = new TextEncoder();
var HttpError = class extends Error {
  constructor(status, code, headers = {}) {
    super(code);
    this.status = status;
    this.headers = headers;
  }
};
function json(value, status = 200, headers = {}) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", ...headers }
  });
}
function configured(value) {
  return typeof value === "string" && encoder4.encode(value).length >= 32 && !value.startsWith("replace-with");
}
function settings(env) {
  const ttl = Number(env.TOKEN_TTL_SECONDS ?? 3600);
  if (!configured(env.JWT_SECRET) || !configured(env.COORDINATOR_API_KEY) || !Number.isSafeInteger(ttl) || ttl < 300 || ttl > 86400 || !env.DB) {
    throw new HttpError(503, "service_not_configured");
  }
  return { key: encoder4.encode(env.JWT_SECRET), ttl };
}
async function body(request2) {
  if (!/^application\/json(?:\s*;|$)/i.test(request2.headers.get("Content-Type") ?? "")) {
    throw new HttpError(415, "json_required");
  }
  if (Number(request2.headers.get("Content-Length")) > 4096) throw new HttpError(413, "body_too_large");
  const reader = request2.body?.getReader();
  if (!reader) throw new HttpError(400, "invalid_json");
  const chunks = [];
  let length = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > 4096) {
        await reader.cancel();
        throw new HttpError(413, "body_too_large");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  try {
    const buffer = new Uint8Array(length);
    let offset = 0;
    for (const chunk of chunks) {
      buffer.set(chunk, offset);
      offset += chunk.length;
    }
    const value = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(buffer));
    if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error();
    return value;
  } catch {
    throw new HttpError(400, "invalid_json");
  }
}
function credentials(value) {
  if (typeof value.username !== "string" || !/^[a-zA-Z0-9_-]{3,24}$/.test(value.username)) {
    throw new HttpError(400, "username_must_be_3_to_24_ascii_letters_digits_or_underscores");
  }
  if (typeof value.password !== "string" || value.password.length < 8 || value.password.length > 128 || encoder4.encode(value.password).length > 512) {
    throw new HttpError(400, "password_must_be_8_to_128_characters");
  }
  return { username: value.username, usernameKey: value.username.toLowerCase(), password: value.password };
}
async function macKey(key) {
  return crypto.subtle.importKey("raw", key, { name: "HMAC", hash: "SHA-256" }, false, ["sign", "verify"]);
}
async function coordinator(request2, env, key) {
  const provided = request2.headers.get("X-Coordinator-Key") ?? "";
  const signingKey = await macKey(key);
  const expected = await crypto.subtle.sign("HMAC", signingKey, encoder4.encode(env.COORDINATOR_API_KEY));
  if (!await crypto.subtle.verify("HMAC", signingKey, expected, encoder4.encode(provided))) {
    throw new HttpError(401, "invalid_coordinator_key");
  }
}
async function rateLimit(db, key, scope, identity2, limit) {
  const now2 = Math.floor(Date.now() / 1e3);
  const bucket = Math.floor(now2 / WINDOW);
  const digest = new Uint8Array(await crypto.subtle.sign(
    "HMAC",
    await macKey(key),
    encoder4.encode(`rate:${scope}:${identity2}:${bucket}`)
  ));
  const id = Array.from(digest, (b) => b.toString(16).padStart(2, "0")).join("");
  const expires = (bucket + 1) * WINDOW;
  const row = await db.prepare(`INSERT INTO rate_limits (key, attempts, expires_at) VALUES (?, 1, ?)
    ON CONFLICT(key) DO UPDATE SET attempts = MIN(attempts + 1, 1000000) RETURNING attempts`).bind(id, expires).first();
  if (row.attempts > limit) throw new HttpError(429, "rate_limited", { "Retry-After": String(expires - now2) });
}
function publicUser(user) {
  return { id: user.id, username: user.username, created_at: user.created_at };
}
async function accessToken(user, key, ttl, id, sessionExpires) {
  const now2 = Math.floor(Date.now() / 1e3);
  const expires = Math.min(now2 + ttl, sessionExpires);
  const token = await new SignJWT({ username: user.username }).setProtectedHeader({ alg: "HS256", typ: "JWT" }).setIssuer(ISSUER).setAudience(AUDIENCE).setSubject(user.id).setJti(id).setIssuedAt(now2).setExpirationTime(expires).sign(key);
  return { expires, token };
}
function hex4(buffer) {
  return Array.from(new Uint8Array(buffer), (b) => b.toString(16).padStart(2, "0")).join("");
}
async function tokenHash(token) {
  return hex4(await crypto.subtle.digest("SHA-256", encoder4.encode(token)));
}
async function nextRefreshToken(token, key) {
  return hex4(await crypto.subtle.sign("HMAC", await macKey(key), encoder4.encode(`refresh:${token}`)));
}
function refreshToken(value) {
  if (typeof value !== "string" || !/^[a-f0-9]{64}$/.test(value)) {
    throw new HttpError(401, "invalid_refresh_token");
  }
  return value;
}
async function newSession(user, key, ttl) {
  const now2 = Math.floor(Date.now() / 1e3);
  const id = crypto.randomUUID();
  const sessionExpires = now2 + DEVICE_TTL;
  const refresh = hex4(crypto.getRandomValues(new Uint8Array(32)));
  const refreshHash = await tokenHash(refresh);
  return {
    id,
    now: now2,
    sessionExpires,
    refresh,
    refreshHash,
    ...await accessToken(user, key, ttl, id, sessionExpires)
  };
}
function sessionResponse(user, session) {
  return {
    success: true,
    user: publicUser(user),
    token: session.token,
    expires_at: session.expires,
    verification: verificationStatus(user),
    refresh_token: session.refresh,
    refresh_expires_at: session.sessionExpires
  };
}
function sessionInsert(db, user, session) {
  return db.prepare(`INSERT INTO sessions (token_id, user_id, expires_at, issued_at, refresh_hash, auth_version)
    SELECT ?, ?, ?, ?, ?, ? WHERE EXISTS (SELECT 1 FROM users WHERE id = ? AND auth_version = ? AND banned = 0)`).bind(
    session.id,
    user.id,
    session.sessionExpires,
    session.now,
    session.refreshHash,
    user.auth_version ?? 0,
    user.id,
    user.auth_version ?? 0
  );
}
async function findDevice(db, hash, now2) {
  return db.prepare(`SELECT s.token_id AS session_id, s.expires_at AS session_expires,
    s.refresh_hash, s.previous_refresh_hash, s.previous_refresh_until, u.*
    FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.expires_at > ? AND s.revoked = 0
    AND u.banned = 0 AND s.auth_version = u.auth_version AND
    (s.refresh_hash = ? OR (s.previous_refresh_hash = ? AND s.previous_refresh_until >= ?))`).bind(now2, hash, hash, now2).first();
}
async function refreshSession(db, key, ttl, refresh) {
  const now2 = Math.floor(Date.now() / 1e3);
  const hash = await tokenHash(refresh);
  const device = await findDevice(db, hash, now2);
  if (!device) throw new HttpError(401, "invalid_refresh_token");
  const next = await nextRefreshToken(refresh, key);
  const nextHash = await tokenHash(next);
  if (device.refresh_hash === hash) {
    const sessionExpires = now2 + DEVICE_TTL;
    const access = await accessToken(device, key, ttl, device.session_id, sessionExpires);
    const updated = await db.prepare(`UPDATE sessions SET refresh_hash = ?, previous_refresh_hash = ?,
      previous_refresh_until = ?, expires_at = ? WHERE token_id = ? AND refresh_hash = ? AND expires_at > ? AND revoked = 0
      RETURNING token_id`).bind(
      nextHash,
      hash,
      now2 + REFRESH_RETRY_GRACE,
      sessionExpires,
      device.session_id,
      hash,
      now2
    ).first();
    if (updated) return sessionResponse(device, { ...access, refresh: next, sessionExpires });
  }
  const current = await findDevice(db, hash, now2);
  if (!current || current.previous_refresh_hash !== hash || current.refresh_hash !== nextHash) {
    throw new HttpError(401, "invalid_refresh_token");
  }
  return sessionResponse(current, {
    ...await accessToken(current, key, ttl, current.session_id, current.session_expires),
    refresh: next,
    sessionExpires: current.session_expires
  });
}
function bearer(request2) {
  const match = /^Bearer ([A-Za-z0-9_.-]+)$/i.exec(request2.headers.get("Authorization") ?? "");
  if (!match || match[1].length > 2048) throw new HttpError(401, "invalid_token");
  return match[1];
}
async function authenticate(token, db, key, expectedAudience = AUDIENCE) {
  let payload;
  try {
    if (typeof token !== "string" || token.length > 2048) throw new Error();
    ({ payload } = await jwtVerify(token, key, {
      algorithms: ["HS256"],
      typ: "JWT",
      requiredClaims: ["sub", "jti", "iat", "exp"],
      maxTokenAge: "24h"
    }));
    if (typeof payload.sub !== "string" || typeof payload.jti !== "string" || !Number.isSafeInteger(payload.iat) || !Number.isSafeInteger(payload.exp) || payload.exp <= payload.iat || payload.exp - payload.iat > 86400) throw new Error();
    if (expectedAudience !== AUDIENCE && (payload.iss !== ISSUER || payload.aud !== expectedAudience)) throw new Error();
    if ((payload.iss !== void 0 || payload.aud !== void 0) && (payload.iss !== ISSUER || payload.aud !== expectedAudience)) throw new Error();
  } catch {
    throw new HttpError(401, "invalid_token");
  }
  const user = await db.prepare(`SELECT u.* FROM sessions s
    JOIN users u ON u.id = s.user_id
    WHERE s.token_id = ? AND s.user_id = ? AND s.expires_at > ? AND s.expires_at >= ?
    AND s.revoked = 0 AND u.banned = 0 AND s.auth_version = u.auth_version`).bind(payload.jti, payload.sub, Math.floor(Date.now() / 1e3), payload.exp).first();
  if (!user) throw new HttpError(401, "invalid_token");
  return { claims: payload, user: publicUser(user), record: user, sessionId: payload.jti, expires: payload.exp };
}
async function route(request2, env) {
  const path = new URL(request2.url).pathname;
  const method = request2.method;
  const liveTest = liveTestRoute(path);
  if (liveTest) {
    if (method !== "GET") throw new HttpError(405, "method_not_allowed", { Allow: "GET" });
    return liveTest;
  }
  if (path === "/signup/config" && method === "GET") return json({ email_required: true, phone_required: true });
  if (path === "/api/game/assertion" || path === "/api/game/verify") {
    const { key: key2 } = settings(env);
    return identity(request2, env, env.DB.withSession("first-primary"), key2);
  }
  if (path.startsWith("/discord/") || path === "/voice/session" || path.startsWith("/internal/voice/")) {
    const { key: key2 } = settings(env);
    return discord.handle(request2, env, env.DB.withSession("first-primary"), key2);
  }
  if (path === "/health" && method === "GET") return json({ status: "ok", version: VERSION });
  if (path.startsWith("/verify/") || path === "/account/password" || path.startsWith("/auth/discord")) {
    const { key: key2 } = settings(env);
    return extras.handle(request2, env, env.DB.withSession("first-primary"), key2);
  }
  if (path === "/ready" && method === "GET") {
    const checks = { secrets: false, database: false };
    try {
      settings(env);
      checks.secrets = true;
    } catch {
    }
    try {
      const db2 = env.DB.withSession("first-primary");
      await db2.batch([
        db2.prepare("SELECT id, username, password_hash, password_salt, email, phone, auth_version FROM users LIMIT 0"),
        db2.prepare(`SELECT token_id, user_id, expires_at, issued_at, refresh_hash, revoked, auth_version,
          previous_refresh_hash, previous_refresh_until FROM sessions LIMIT 0`),
        db2.prepare("SELECT id, attempts, code FROM verification_codes LIMIT 0"),
        db2.prepare("SELECT state_hash, user_id, token_id, code_verifier, expires_at FROM oauth_states LIMIT 0"),
        db2.prepare("SELECT key, attempts, expires_at FROM rate_limits LIMIT 0")
      ]);
      checks.database = true;
    } catch {
    }
    const ready = Object.values(checks).every(Boolean);
    return json({ ready, version: VERSION, checks: {
      ...checks,
      jwt_secret: configured(env.JWT_SECRET),
      resend: Boolean(env.RESEND_API_KEY),
      twilio: Boolean(env.TWILIO_ACCOUNT_SID && env.TWILIO_AUTH_TOKEN && env.TWILIO_FROM),
      discord: Boolean(env.DISCORD_CLIENT_ID && env.DISCORD_CLIENT_SECRET && env.DISCORD_BOT_TOKEN)
    } }, ready ? 200 : 503);
  }
  const routes = {
    "/register": "POST",
    "/login": "POST",
    "/verify": "GET",
    "/account": "GET",
    "/logout": "POST",
    "/refresh": "POST",
    "/internal/verify": "POST"
  };
  if (!routes[path]) throw new HttpError(404, "not_found");
  if (routes[path] !== method) throw new HttpError(405, "method_not_allowed", { Allow: routes[path] });
  const { key, ttl } = settings(env);
  const db = env.DB.withSession("first-primary");
  if (path === "/register" || path === "/login") {
    await rateLimit(db, key, "auth-ip", request2.headers.get("CF-Connecting-IP") ?? "local", 30);
    const data = await body(request2);
    const { username, usernameKey, password } = credentials(data);
    await rateLimit(db, key, "auth-username", usernameKey, 10);
    if (path === "/register") {
      const registration = extras.registration(data);
      const user2 = { id: crypto.randomUUID(), username, created_at: Math.floor(Date.now() / 1e3), ...registration };
      const { hash: passwordHash, salt } = await passwordRecord(password);
      const existing = await db.prepare(`SELECT id FROM users WHERE username = ? OR email = ? COLLATE NOCASE
        OR phone IN (?, ?)`).bind(username, user2.email, user2.phone, user2.phone.slice(1)).first();
      if (existing) throw new HttpError(409, "account_already_registered");
      const session2 = await newSession(user2, key, ttl);
      try {
        await db.batch([
          db.prepare(`INSERT INTO users (id, username, password_hash, password_salt, email, phone, created_at, last_login)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)`).bind(user2.id, username, passwordHash, salt, user2.email, user2.phone, user2.created_at, user2.created_at),
          sessionInsert(db, user2, session2)
        ]);
      } catch (error) {
        if (/UNIQUE constraint failed: users\./.test(String(error))) {
          throw new HttpError(409, "account_already_registered");
        }
        throw error;
      }
      const sendErrors = await extras.afterRegister(env, db, key, user2, request2.headers.get("CF-Connecting-IP") ?? "local");
      return json({
        ...sessionResponse(user2, session2),
        needs: ["email", "phone", "discord"],
        ...sendErrors.length ? { send_errors: sendErrors } : {}
      }, 201);
    }
    const user = await db.prepare("SELECT * FROM users WHERE username = ?").bind(username).first();
    const valid = await verifyPassword(password, user?.password_hash ?? DUMMY_HASH, user?.password_salt);
    await extras.audit(db, key, username, request2.headers.get("CF-Connecting-IP") ?? "local", Boolean(user && valid && !user.banned));
    if (!user || !valid || user.banned) throw new HttpError(401, "invalid_credentials");
    if (!user.password_hash.startsWith("pbkdf2-sha256$")) {
      const upgraded = await passwordRecord(password);
      await db.prepare(`UPDATE users SET password_hash = ?, password_salt = ? WHERE id = ?
        AND password_hash = ? AND auth_version = ?`).bind(upgraded.hash, upgraded.salt, user.id, user.password_hash, user.auth_version).run();
    }
    const session = await newSession(user, key, ttl);
    const issued = await db.batch([
      sessionInsert(db, user, session),
      db.prepare("UPDATE users SET last_login = ? WHERE id = ? AND auth_version = ?").bind(session.now, user.id, user.auth_version)
    ]);
    if (issued[0].meta.changes !== 1) throw new HttpError(401, "invalid_credentials");
    return json(sessionResponse(user, session));
  }
  if (path === "/refresh" || path === "/logout" && !request2.headers.has("Authorization")) {
    await rateLimit(db, key, "device-ip", request2.headers.get("CF-Connecting-IP") ?? "local", 120);
    const refresh = refreshToken((await body(request2)).refresh_token);
    if (path === "/refresh") return json(await refreshSession(db, key, ttl, refresh));
    const device = await findDevice(db, await tokenHash(refresh), Math.floor(Date.now() / 1e3));
    if (!device) throw new HttpError(401, "invalid_refresh_token");
    await db.prepare("UPDATE sessions SET revoked = 1 WHERE token_id = ?").bind(device.session_id).run();
    return json({ success: true });
  }
  if (path === "/internal/verify") {
    await coordinator(request2, env, key);
    const { token } = await body(request2);
    const auth2 = await authenticate(token, db, key);
    const status = verificationStatus(auth2.record);
    return json({ valid: true, user: {
      ...auth2.user,
      email_verified: status.email,
      phone_verified: status.phone,
      discord_linked: status.discord,
      fully_verified: status.fully_verified
    }, expires_at: auth2.expires });
  }
  const auth = await authenticate(bearer(request2), db, key);
  if (path === "/logout") {
    await db.prepare("UPDATE sessions SET revoked = 1 WHERE token_id = ?").bind(auth.sessionId).run();
    return json({ success: true });
  }
  if (path === "/account") return json(await extras.account(db, auth.user.id));
  const verification = verificationStatus(auth.record);
  return json({ valid: true, user: {
    ...auth.user,
    email_verified: verification.email,
    phone_verified: verification.phone,
    discord_linked: verification.discord,
    fully_verified: verification.fully_verified
  }, expires_at: auth.expires });
}
var discord = discordRoutes({ HttpError, json, body, authenticate, bearer, rateLimit, coordinator });
var identity = gameIdentity({ HttpError, json, body, bearer, authenticate, rateLimit });
var extras = accountExtras({ HttpError, json, body, authenticate, bearer, rateLimit, passwordRecord, verifyPassword, tokenHash, discord });
var index_default = {
  async fetch(request2, env) {
    const origin = request2.headers.get("Origin");
    const sameOrigin = origin === new URL(request2.url).origin;
    const allowed = (env.CORS_ORIGIN ?? env.ALLOWED_ORIGINS ?? "").split(",").map((value) => value.trim()).filter(Boolean);
    const headers = {
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
      Vary: "Origin",
      ...origin && (sameOrigin || allowed.includes(origin)) ? { "Access-Control-Allow-Origin": origin } : {}
    };
    let response;
    try {
      if (origin && !sameOrigin && !allowed.includes(origin)) throw new HttpError(403, "origin_not_allowed");
      if (request2.method === "OPTIONS") {
        const methods = ["GET", "POST"];
        const requestedHeaders = (request2.headers.get("Access-Control-Request-Headers") ?? "").toLowerCase().split(",").map((value) => value.trim()).filter(Boolean);
        if (!origin || !methods.includes(request2.headers.get("Access-Control-Request-Method")) || requestedHeaders.some((value) => !["content-type", "authorization", "x-coordinator-key"].includes(value))) {
          throw new HttpError(403, "preflight_not_allowed");
        }
        response = new Response(null, { status: 204, headers: {
          "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Coordinator-Key",
          "Access-Control-Max-Age": "600"
        } });
      } else {
        response = await route(request2, env);
      }
    } catch (error) {
      if (error instanceof HttpError) {
        response = json({ error: error.message }, error.status, {
          ...error.status === 401 ? { "WWW-Authenticate": "Bearer" } : {},
          ...error.headers
        });
      } else {
        console.error("Accounts request failed");
        response = json({ error: "internal_error" }, 500);
      }
    }
    for (const [name, value] of Object.entries(headers)) response.headers.set(name, value);
    return response;
  },
  async scheduled(_event, env, ctx) {
    const now2 = Math.floor(Date.now() / 1e3);
    ctx.waitUntil(env.DB.batch([
      env.DB.prepare("DELETE FROM sessions WHERE expires_at <= ?").bind(now2),
      env.DB.prepare("DELETE FROM rate_limits WHERE expires_at <= ?").bind(now2),
      env.DB.prepare("DELETE FROM verification_codes WHERE expires_at <= ?").bind(now2),
      env.DB.prepare("DELETE FROM oauth_states WHERE expires_at <= ?").bind(now2),
      env.DB.prepare("DELETE FROM login_attempts WHERE attempted_at <= ?").bind(now2 - 7 * 86400)
    ]));
    ctx.waitUntil(discord.cleanup(env));
  }
};
export {
  index_default as default
};
