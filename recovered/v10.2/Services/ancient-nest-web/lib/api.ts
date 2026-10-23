import { config } from "@/lib/config";
// Integration boundary only. None of these requests run automatically in this starter.
export class ApiError extends Error { constructor(public status: number) { super(`API request failed (${status})`); this.name = "ApiError"; } }
export async function apiGet<T>(path: string, decode: (value: unknown) => T, signal?: AbortSignal): Promise<T> {
 if (!path.startsWith("/api/") || path.includes("..") || path.includes("\\")) throw new Error("Use an /api/ resource path.");
 const response = await fetch(`${config.apiBaseUrl}${path}`, { headers: { Accept: "application/json" }, credentials: "omit", cache: "no-store", signal: signal ?? AbortSignal.timeout(10000) });
 if (!response.ok) throw new ApiError(response.status);
 return decode(await response.json()); // Runtime decoder must validate real backend data.
}
export const futureEndpoints = { player: "/api/player/:id", leaderboards: "/api/leaderboards", news: "/api/news", status: "/api/status", steamLogin: "/api/auth/steam", matchResult: "/api/match/result" } as const;
// Auth and match-result POSTs require trusted backend services; no browser submission shim.
