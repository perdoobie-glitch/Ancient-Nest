import Link from "next/link";
import type { ReactNode } from "react";
import { Icon } from "@/components/Icon";
export function Button({ href, children, variant = "primary", className = "", disabled = false, external = false, label, arrow = false }: { href?: string; children: ReactNode; variant?: "primary" | "outline" | "text"; className?: string; disabled?: boolean; external?: boolean; label?: string; arrow?: boolean }) {
 const style = `button button-${variant} ${className}`;
 const content = <>{children}{arrow && <Icon name={external ? "external" : "arrow"} />}</>;
 if (!href || disabled) return <button type="button" className={style} disabled aria-label={label}>{content}</button>;
 if (external) return <a href={href} className={style} aria-label={label} target="_blank" rel="noopener noreferrer">{content}</a>;
 return <Link href={href} className={style} aria-label={label}>{content}</Link>;
}
