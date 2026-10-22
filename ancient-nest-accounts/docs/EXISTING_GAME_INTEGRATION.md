# Existing Ancient Nest game integration

The user's existing game was located in connected Drive. The current archive is
**Ancient Nest 10.2 – Complete Source.zip**, file ID
`1AqvpA4VTPnkLuEn7LxnHpt7zmh9DEDJJ` (61,177,174 bytes). The runtime's network policy
currently blocks its authenticated download host. Do not substitute a fabricated
arena or ship an older version as the current game.

The smaller 8.0 clean source and 9.0 coordinator ZIP were available for interface
inspection. They are local references, not replacement releases and are not added
to this public repository. Their account protocol uses RSA installation identity
plus an account assertion; a plain login JWT is insufficient for the handshake.

## Adapter and installer

`Connect Existing Game.cmd` runs the Node installer against the owner's extracted
Godot game. It verifies the known `NestAccountLink` and `account_assertion` interfaces
before editing; an unrecognized layout stops with no changes. The full source
package must include the native addons (or install them before integration).

It backs up the original project settings, account bridge and any addon folders
under `.account-integration-backup/`, installs the secure-storage/voice autoloads,
and records the original intro scene in `ancient_nest/original_main_scene`. Successful
sign-in enters that original scene. Revocation returns to the login gate. Maps,
physics, weapons, rank files and gameplay scripts are not rewritten.

The account adapter requests a ten-minute RSA-key-bound assertion with a game bearer
token. The account refresh secret remains in the OS credential store, and access
and assertion tokens remain in memory. It does not reuse the old plaintext
`user://account_link.json` refresh token; an existing player must sign in to the new
service to obtain its device session. This is not migration of old website accounts,
Steam purchases, ownership or rankings.

## Identity API

- `POST /api/game/assertion`: authenticated JSON `{ public_key }`, valid RSA SPKI PEM
  of at least 2048 bits; returns `{ assertion, account_id, username, key_hash, expires_in }`.
- `POST /api/game/verify`: JSON `{ assertion, key_hash }`; returns the account identity
  only for the exact game key, a live session and an unbanned account. Game assertions
  have a separate audience and cannot authenticate account routes. Logging out or
  changing the password revokes these assertions too.

The 9.0 coordinator proof contract matches these response fields. Its `ACCOUNT_API`
origin also receives profile/results requests, which this service does not implement.
Do not repoint that whole bridge blindly or lose the existing authoritative stats
backend. Inspect the actual current coordinator and keep identity and stats routing
explicit when integrating. Do not deploy the old 9.0 coordinator over 10.2.

## Remaining current-game checks

Download and inspect the latest source, verify the account interface, then run the
installer and the game's existing tests. Wire server-authoritative match start/end
to the supplied team-voice helper, using account IDs and actual team rosters. Do not
let clients declare their own teammate list. Test login → original intro → existing
menu → existing gameplay, restored login after restart, logout/revocation during
play, and two clients in a real match. Test live Windows credential storage and
microphone/friends-call behavior on the machines being shipped.

An older source can validate the adapter's parser and scene preservation; it cannot
establish compatibility with the uninspected current release.

The local 8.0 smoke check reached its existing menu/account panel and returned to
the login scene on revocation. That older release also emitted weapon-audio
`profile.sounds` errors while initializing its own menu; the unmodified-account
baseline exhibits the same errors. No audio/gameplay code was rewritten to hide
them. This is a limited adapter check, not a clean end-to-end game certification.
