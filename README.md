# Ancient Nest

Ancient Nest's cinematic main-menu preview, based on the reference artwork supplied for the project.

![Ancient Nest main-menu preview](docs/menu-preview.webp)

## Current status

The repository includes the browser menu preview plus the [Discord sign-in and team voice client](ancient-nest-accounts/README.md). Version 10.4 uses **Continue with Discord**, a persistent device session and a game username linked to verified Discord identity. Password/email/phone signup is disabled.

The finished 10.2 gameplay source is not present in this repository. The Windows artifact is the login/voice starter until that source is connected. The guarded adapter preserves existing gameplay and refuses unsupported interfaces.

For Cloudflare setup, [copy this prompt](ancient-nest-accounts/cloudflare-paste/PASTE-INTO-CLOUDFLARE-ASSISTANT.txt). The existing Worker and D1 hold game profiles, sessions and server-managed team voice. Do not delete the existing database or matchmaking service.
