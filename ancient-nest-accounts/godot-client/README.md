# Ancient Nest Discord client starter

Open `Ancient Nest.exe` in the Windows artifact. Click **Continue with Discord**. The SDK uses the running desktop client when available; initial consent may require approval. A supported browser fallback is provided by Discord. No game password, email, or phone signup is required.

Save a game username on the signed-in screen. Device login uses the OS credential store. Next launch restores automatically; a failed startup restore requires Discord sign-in again. Voice authorization is reused from initial sign-in. Team mute/deafen and V push-to-talk affect the game's call.

This is a starter, not the finished 10.2 game. Use the guarded integration tool with the actual game source. Configure `ancient_nest/account_api` to the deployed profile/voice bridge. Never embed client secrets, JWT signing keys, coordinator keys or bot tokens in the client.

Native dependencies are installed by `npm run discord:install`; export with Godot 4.6.3 using `npm run build:windows`. Live consent/audio behavior requires testing on Windows with real Discord accounts.
