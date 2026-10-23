import { Button } from "@/components/Button";
import { steamStoreUrl } from "@/lib/steam";
export function SteamButton({ compact = false }: { compact?: boolean }) {
 const url = steamStoreUrl();
 return <Button href={url || "/play#steam"} external={!!url} label={url ? "Play on Steam (opens a new tab)" : undefined} className={compact ? "button-small" : ""}><span>Play on Steam{!url && <> <small>Coming soon</small></>}</span>{!compact && <span aria-hidden="true">↗</span>}</Button>;
}
