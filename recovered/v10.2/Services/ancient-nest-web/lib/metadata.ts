import type { Metadata } from "next";
export function pageMetadata(title: string, description: string, path: string): Metadata {
 const fullTitle = `${title} — Ancient Nest`;
 return { title, description, alternates: { canonical: path },
  openGraph: { type: "website", siteName: "Ancient Nest", locale: "en_US", title: fullTitle, description, url: path, images: [{ url: "/images/social-preview.jpg", alt: "Ancient Nest world and character concept artwork" }] },
  twitter: { card: "summary_large_image", title: fullTitle, description, images: ["/images/social-preview.jpg"] },
 };
}
