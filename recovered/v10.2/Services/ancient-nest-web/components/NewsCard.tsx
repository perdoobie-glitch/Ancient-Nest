import Link from "next/link";
import Image from "next/image";
import type { NewsPost } from "@/types/news";
import { Icon } from "@/components/Icon";
export function NewsCard({ post }: { post: NewsPost }) { return <article className="news-card"><Link href={`/news/${post.slug}`} className="news-image" tabIndex={-1} aria-hidden="true"><Image src={post.image} alt="" fill sizes="(max-width: 767px) 100vw, 33vw"/></Link><div className="news-body"><div className="news-meta"><span>{post.category}</span><span>{post.isPlaceholder ? "Sample entry" : `${post.readMinutes} min read`}</span></div><h2><Link href={`/news/${post.slug}`}>{post.title}</Link></h2><p>{post.summary}</p><Link href={`/news/${post.slug}`} className="text-link" aria-label={`Read update: ${post.title}`}>Read update <Icon/></Link></div></article>; }
