import type { MetadataRoute } from "next";
import { config } from "@/lib/config";
// Demo/account/sample articles are deliberately omitted from the indexed sitemap.
export const dynamic = "force-static";
export default function sitemap(): MetadataRoute.Sitemap { return ["", "/game", "/play", "/community", "/news", "/status"].map(path => ({ url: `${config.siteUrl}${path}`, changeFrequency: "monthly", priority: path === "" ? 1 : 0.7 })); }
