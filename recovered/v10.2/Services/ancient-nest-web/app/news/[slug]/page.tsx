import { notFound } from "next/navigation";
import Image from "next/image";
import { getNewsPost, getNewsPosts } from "@/lib/news";
import { pageMetadata } from "@/lib/metadata";
import { Button } from "@/components/Button";
export const dynamicParams = false;
export async function generateStaticParams() { return (await getNewsPosts()).map(post => ({ slug: post.slug })); }
export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) { const { slug } = await params; const post = await getNewsPost(slug); if (!post) return { title: "Update not found" }; return { ...pageMetadata(post.title, post.summary, `/news/${slug}`), robots: { index: !post.isPlaceholder, follow: true } }; }
export default async function ArticlePage({ params }: { params: Promise<{ slug: string }> }) { const { slug } = await params; const post = await getNewsPost(slug); if (!post) notFound(); return <article className="container article-page"><Button href="/news" variant="text">← All updates</Button><div className="eyebrow">{post.category} / Sample entry</div><h1>{post.title}</h1><p className="lead">{post.summary}</p><p className="notice">Editorial placeholder · Not a published announcement</p><div className="article-image"><Image src={post.image} alt={post.imageAlt} fill sizes="(max-width: 900px) 100vw, 900px"/></div><div className="article-copy">{post.paragraphs.map(paragraph => <p key={paragraph}>{paragraph}</p>)}</div></article>; }
