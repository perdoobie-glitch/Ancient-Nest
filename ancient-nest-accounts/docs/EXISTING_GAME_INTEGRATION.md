# Current identity update: 10.4 Discord

Discord is now the sign-in provider. Password/email/phone signup is disabled in the shipped configuration; see [current setup](../README.md). The existing Worker/D1 are retained as a game-profile/session/voice bridge. The adapter account panel supports changing the game username linked to the verified Discord identity. Initial consent can require approval.

The connected GitHub main branch contains the starter and adapter, not the finished 10.2 game. The complete source archive was located in Drive in earlier work, but its download host is blocked here. Only the 8.0 game and 9.0 coordinator references were downloaded. Nothing from another chat or a PC-local folder is automatically present here.

Do not mark the finished game integrated or deploy the old coordinator over 10.2. Inspect the actual game before connecting the adapter and team voice lifecycle hooks. Existing 8.0 reference audio errors are not proof of a defect in 10.2. The original startup and gameplay/assets must be preserved.

The Windows release is a clearly labeled login/voice starter. Automated tests do not prove real Discord consent or two-person microphone/friends-call behavior. Cloudflare live deployment has not been performed from this workspace because write credentials/network access are not configured.
