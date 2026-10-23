import { PageIntro } from "@/components/PageIntro";
import { NewsCard } from "@/components/NewsCard";
import { getNewsPosts } from "@/lib/news";
import { pageMetadata } from "@/lib/metadata";
export const metadata = pageMetadata("News & Updates", "Development notes and future announcements from Perdoobie & Mishwad Studio, the creators of Ancient Nest.", "/news");
export default async function NewsPage() { const posts = await getNewsPosts(); return <><PageIntro eyebrow="Perdoobie & Mishwad Studio / News" title="Notes from the Nest.">Development, the world, and what comes next. A home for future updates from the studio.</PageIntro><section className="section section-first container"><div className="notice"><strong>Editorial preview</strong><p>These three entries are sample content for the website. They are not published announcements, feature confirmations, or release dates.</p></div><div className="news-grid">{posts.map(post => <NewsCard key={post.slug} post={post}/>)}</div></section></>; }
