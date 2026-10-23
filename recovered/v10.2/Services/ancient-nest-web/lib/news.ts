import { news } from "@/data/news";
import type { NewsPost } from "@/types/news";
// Replace this repository boundary with a CMS, Markdown loader, API or database.
export async function getNewsPosts(): Promise<NewsPost[]> { return news; }
export async function getNewsPost(slug: string): Promise<NewsPost | undefined> { return news.find(post => post.slug === slug); }
