import type { ReactNode } from "react";
export function PageIntro({ eyebrow, title, children }: { eyebrow: string; title: string; children: ReactNode }) { return <section className="page-intro container"><div className="eyebrow"><span className="tiny-diamond"/>{eyebrow}</div><h1>{title}</h1><p>{children}</p><div className="intro-line" /></section>; }
