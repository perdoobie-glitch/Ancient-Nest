# Ancient Nest game/account contract — version 1

Use one HTTPS account origin, supplied in the shipped public config. Default intended
origin: `https://ancientnest.net`. It must actually serve this Worker before enabling
linking. The existing workers.dev hostname is an alternative only when SITE_ORIGIN,
frontend build URL, game config, and hub config ALL use that hostname consistently.
No production deployment was performed by Codex.

All POST bodies are JSON, at most 16 KiB. Responses are no-store JSON. Errors use
`{"error":"machine_readable_code"}` and a non-2xx status. Never treat errors, redirects,
missing fields, timeouts, or `not_configured` as a verified license.

## Installation and first launch

The installer places only game files and public HTTPS configuration. No account
password, coordinator secret, store publisher key, or signing key goes in it.
On first launch offer “Link Ancient Nest account” and “Continue offline” where
supported. Linking opens the real website in the OS browser with explicit user
interaction. Do not open a login flow as an installer administrator action.

Generate and retain an RSA 2048–4096-bit installation key pair. Godot's Crypto API
supports the required PKCS#1 v1.5 SHA-256 signatures. A PKCS#1 RSA PUBLIC KEY or SPKI
PUBLIC KEY PEM is accepted. Persist the EXACT public PEM string: key_hash is lowercase
SHA-256 of its UTF-8 bytes, including line endings/trailing newline. Do not hash DER.
Use the OS credential store if available for the private key and refresh credential.
At minimum use private per-user files; never distribute the same identity in exports.
A copied local identity is not hardware-bound or DRM.

1. POST `/api/game/link/start` with `{"public_key":"<PEM>"}`.
   Returns `device_secret`, `user_code` (8 uppercase characters), `challenge`,
   `verification_uri`, `expires_in:600`, `interval:3`, `key_fingerprint` (12 hex).
2. Show the code AND fingerprint. Open the returned verification_uri with `?code=CODE`
   only after validating it matches the configured trusted origin and `/account/`.
3. Browser signs in via Steam's real site, chooses username, checks fingerprint and
   approves. The game never receives browser cookies or a Steam password.
4. Every 3 seconds while the linking screen is active, POST `/api/game/link/poll`:
   `{"device_secret":"...","signature":"<base64 signature>"}`.
   Signature = RSA PKCS#1 v1.5 SHA-256 over the UTF-8 challenge EXACTLY, no extra newline.
   Godot Crypto.sign takes a SHA-256 digest; do not accidentally hash that digest twice.
   Pending response: `{"status":"pending"}`. Stop at 10 minutes/cancel/unlink.
5. Approval returns `status:"linked", account_id, username, device_id, refresh_token,
   assertion, expires_in:900`. Persist only refresh token/installation key/IDs. Keep the
   assertion in memory. Code consumption is one-use: do not loop another claim request.
6. Show confirmed account username/ID; never make a new account just because the game
   was reinstalled. Relinking to the same verified Steam identity restores its record.

## Refresh

POST `/api/game/session` with `refresh_token`, integer Unix `issued_at`, a fresh
cryptographically random `nonce` (32–128 URL-safe characters), and `signature`.
Sign the UTF-8 bytes of exactly these four lines, with NO trailing newline:

    ancient-nest-session-v1
    REFRESH_TOKEN
    ISSUED_AT
    NONCE

Return fields: account_id, username, device_id, assertion, expires_in:900.
Refresh credential lasts 30 days from linking; refresh does not extend that period.
Replay/stale proof is rejected. Time tolerance is ±120 seconds. Explain clock errors;
never disable verification. Keep one in-flight request, refresh about 30 seconds
before expiry using monotonic timers, and apply bounded retries/backoff. Do not
refresh every frame or from physics, input, firing, or animation handlers.
401/revoked/expired: stop account matchmaking and offer linking again. 429: wait;
5xx/network failure: show temporary outage and retry later. Do not erase local saves.
Website sign-out and game unlink are separate actions. Website unlink revokes future
sessions/introspection; it does not forcibly end an already-running match.

## Hub identity and license check

Game sends its short-lived `account_assertion` with the existing HELLO handshake.
Preserve the hub's fresh nonce/private-key proof. The hub computes key_hash from
that proved public PEM and POSTs `/api/game/verify`:
`{"assertion":"<JWT>","key_hash":"<64 hex>"}`.
Never trust client-claimed account UUID, username, ownership, team, RP or damage.

Successful verification returns valid:true, account_id, username, device_id,
key_hash, expires_at, ownership_required:boolean, and ownership:
`{provider:"steam",status,has_access,checked_at,permanent?,message}`.
Possible ownership statuses: not_configured, verified, not_owned, unavailable.
If REQUIRE_OWNERSHIP=true, missing/unverified license returns 403 game_license_required.
Default false is EXPLICIT pre-release account testing, not evidence of a purchase.

The hub uses stable identity `account:<account_id>`, not username or installation ID.
Reject duplicate active account slots. Refresh assertions while connected; revalidate
before queue admission/match formation and new sessions. Reconnection must restore the
same roster slot. Do not send any private refresh credential to other players/hub.

RS256 assertions expire in 15 minutes and include iss, aud=ancient-nest-matchmaking,
sub=account UUID, username, device_id, key_hash, iat, exp, jti. Public signing key:
GET `/api/account/public-key`. Validating a signature alone cannot check revocation
or current ownership: use online verify for rated admission. Local decoding is not
verification. Host migration does not mint accounts or reset stats.

## Profile display

POST `/api/game/profile` with the same `{assertion,key_hash}`. This is authenticated
READ-ONLY profile access; it does not verify a fresh store license or grant admission.
Returns scope=matchmaking, rp, rank {number,name,tier}, matches, wins, kills, deaths,
assists, flags_captured, flags_stopped, player_rating (null until 5 eligible matches),
placement_matches (0–5), kd (null if zero deaths), and recent_matches (latest 20).
Call from menus/post-match, not every render frame. Display backend rank as canonical.
Offline/local practice values must stay visibly separate and never be uploaded as rank.
Website GET `/api/profile` reads the same record using its HttpOnly session cookie.
Do not invent XP/level/leaderboards; they are not implemented by this API.

## Ownership and other stores

Steam sign-in works without a game App ID. License checking requires YOUR future App ID
and publisher API key, both configured server-side. No Spacewar/480 or made-up IDs.
The current adapter calls Steam CheckAppOwnership v4 with a publisher-owned key. An
active Steam license may be borrowed/temporary; permanent is reported separately.
It verifies a license, not proof of a cash payment. No direct checkout currently exists.

For future direct sales, payment happens on a hosted checkout. The backend verifies
the provider's signed payment webhook, binds the order to an authenticated account,
and writes an idempotent entitlement. Refunds/chargebacks revoke it. Other storefronts
need corresponding trusted verification. No client `paid:true`, installer receipt,
local file, Steam login, or public profile can grant access. The installer and this
contract remain store-neutral; account ID/stats do not depend on where the copy was sold.
Non-Steam sign-in/account linking and checkout adapters are future backend work, not
currently working features. Do not create game passwords as a workaround.
