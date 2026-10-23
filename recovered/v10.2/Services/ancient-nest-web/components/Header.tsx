"use client";
import Link from "next/link";
import Image from "next/image";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { navigation } from "@/data/site";
import { SteamButton } from "@/components/SteamButton";
import { Icon } from "@/components/Icon";
export function Header() {
 const pathname = usePathname(); const [open, setOpen] = useState(false); const toggle = useRef<HTMLButtonElement>(null);
 useEffect(() => { const close = (e: KeyboardEvent) => { if (e.key === "Escape" && open) { setOpen(false); toggle.current?.focus(); } }; const wide = window.matchMedia("(min-width: 1024px)"); const resize = () => { if (wide.matches) setOpen(false); }; document.addEventListener("keydown", close); wide.addEventListener("change", resize); return () => { document.removeEventListener("keydown", close); wide.removeEventListener("change", resize); }; }, [open]);
 return <header className="site-header"><div className="header-inner"><Link className="brand" href="/" onClick={() => setOpen(false)} aria-label="Ancient Nest home"><Image src="/icons/nest.svg" alt="" width={35} height={35} /><span>Ancient Nest</span></Link><nav className="desktop-nav" aria-label="Main navigation">{navigation.map(item => <Link key={item.href} href={item.href} aria-current={pathname === item.href ? "page" : undefined}>{item.label}</Link>)}</nav><div className="header-actions"><Link href="/account" className="signin">Sign in</Link><SteamButton compact /></div><button ref={toggle} className="menu-toggle" type="button" aria-label={open ? "Close navigation" : "Open navigation"} aria-expanded={open} aria-controls="mobile-navigation" onClick={() => setOpen(!open)}><Icon name={open ? "close" : "menu"} /></button></div><nav id="mobile-navigation" className={`mobile-nav ${open ? "is-open" : ""}`} aria-label="Mobile navigation" hidden={!open}>{navigation.map(item => <Link key={item.href} href={item.href} onClick={() => setOpen(false)} aria-current={pathname === item.href ? "page" : undefined}>{item.label}<span aria-hidden="true">↗</span></Link>)}<Link href="/account" onClick={() => setOpen(false)}>Sign in <span>Coming soon</span></Link><Link href="/play#steam" onClick={() => setOpen(false)}>Steam <span>Coming soon</span></Link></nav></header>;
}
