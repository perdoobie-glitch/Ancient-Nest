import type { Metadata, Viewport } from "next";
import { Header } from "@/components/Header";
import { Footer } from "@/components/Footer";
import { config } from "@/lib/config";
import { site } from "@/data/site";
import "./globals.css";
export const metadata: Metadata = { metadataBase: new URL(config.siteUrl), title: { default: "Ancient Nest — Multiplayer FPS", template: "%s | Ancient Nest" }, description: site.description, alternates: { canonical: "/" }, robots: { index: true, follow: true }, openGraph: { type: "website", locale: "en_US", siteName: "Ancient Nest", title: "Ancient Nest — Multiplayer FPS", description: site.description, url: "/", images: [{ url: "/images/social-preview.jpg", alt: "Ancient Nest world and character concept artwork" }] }, twitter: { card: "summary_large_image", title: "Ancient Nest — Multiplayer FPS", description: site.description, images: ["/images/social-preview.jpg"] }, icons: { icon: "/icons/nest.svg", apple: "/icons/apple-touch-icon.png" } };
export const viewport: Viewport = { width: "device-width", initialScale: 1, themeColor: "#101412" };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) { return <html lang="en"><body><a href="#main-content" className="skip-link">Skip to content</a><Header/><main id="main-content" tabIndex={-1}>{children}</main><Footer/></body></html>; }
