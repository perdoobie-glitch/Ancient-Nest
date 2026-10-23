function publicUrl(raw: string | undefined, fallback: string): string {
 try { const url = new URL(raw || fallback); if (!["https:", "http:"].includes(url.protocol)) return fallback; return url.toString().replace(/\/$/, ""); } catch { return fallback; }
}
export const config = {
 siteUrl: publicUrl(process.env.NEXT_PUBLIC_SITE_URL, "https://ancientnest.net"),
 apiBaseUrl: publicUrl(process.env.NEXT_PUBLIC_API_BASE_URL, process.env.NEXT_PUBLIC_SITE_URL || "https://ancientnest.net"),
 steamAppId: /^\d+$/.test(process.env.NEXT_PUBLIC_STEAM_APP_ID || "") ? process.env.NEXT_PUBLIC_STEAM_APP_ID : undefined,
};
