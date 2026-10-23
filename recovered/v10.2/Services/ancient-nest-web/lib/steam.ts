import { config } from "@/lib/config";
// Public store ID only. Never put Steam Web API keys or session secrets here.
export function steamStoreUrl(): string | null { return config.steamAppId ? `https://store.steampowered.com/app/${config.steamAppId}/` : null; }
// Backend performs verification and creates the HttpOnly session. No browser-side identity assertion.
export async function beginSteamLogin(): Promise<void> { if (typeof window === "undefined") throw new Error("Begin Steam login from the browser."); window.location.assign("/api/auth/steam"); }
