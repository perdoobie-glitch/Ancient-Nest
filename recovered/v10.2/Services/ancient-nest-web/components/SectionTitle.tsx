import type { ReactNode } from "react";
export function SectionTitle({ eyebrow, title, children, light = false }: { eyebrow: string; title: string; children?: ReactNode; light?: boolean }) { return <div className={`section-title ${light ? "title-light" : ""}`}><span className="eyebrow">{eyebrow}</span><h2>{title}</h2>{children && <p>{children}</p>}</div>; }
