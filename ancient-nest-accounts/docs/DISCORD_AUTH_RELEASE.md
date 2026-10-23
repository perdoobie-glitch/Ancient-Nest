Ancient Nest 10.4 uses **Continue with Discord** instead of a separate game password/email/phone signup. Verified Discord identity maps to a stable game profile and editable game username. Approved device sessions restore on later launches; failed startup restoration requires Discord sign-in again. Initial Discord consent may require approval even when the desktop client is running.

**This download is the login/voice starter, not the finished 10.2 game.** The finished gameplay source is not in this repository. Existing maps, weapons and gameplay have not been replaced. The included integration adapter requires review against the actual current game source.

Download **Ancient-Nest-Windows.zip**, extract it and open **Ancient Nest.exe**. The owner must deploy the updated profile/voice bridge first, using the Cloudflare copy/paste instructions in the repository. Apply pending migration 0005 once: existing profiles/history are preserved, and old sessions are revoked so users prove Discord identity after the switch. Previously Discord-linked profiles retain their game IDs/usernames. Unlinked old profiles are not automatically merged by name.

The Worker/D1 remain for game profiles, revocable sessions and server-managed team voice. Resend/Twilio are no longer required. Server secrets must never go into the game or GitHub. Existing contact data and provider secrets are preserved; this update does not delete production resources.

Automated validation covers local D1/Discord test doubles, Godot startup/session behavior, native SDK loading, Windows OS credential storage, Windows export and executable startup. Real Discord authorization and two-person microphone/friends-call behavior still require live device tests. Authentication does not verify a game purchase.
