import { Icon } from "@/components/Icon";
export function FeatureCard({ title, description, status, icon = "layers" }: { title: string; description: string; status: string; icon?: "layers" | "shield" | "network" | "cross" | "spark" }) { return <article className="feature-card"><Icon name={icon}/><span className="eyebrow">{status}</span><h3>{title}</h3><p>{description}</p></article>; }
