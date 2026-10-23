export interface Faction { id: string; name: string; role: string; description: string; traits: string[]; image: string; accent: "red" | "green"; }
export const factions: Faction[] = [
 { id: "annu", name: "Annu", role: "Hold what remains", description: "Defenders of the Ancient Nest. Annu possesses its gold but has not learned to harness it for advanced energy technology.", traits: ["Conventional weapons, armor & health", "Nu & the Annu-exclusive Brutus Link", "Advanced traits only when granted by the game type"], image: "/images/annu.webp", accent: "red" },
 { id: "naki", name: "Naki", role: "Rewrite the balance", description: "An invading force that understands how refined gold regulates its advanced energy systems. Control of the Nest’s reserves sustains Naki’s technological advantage.", traits: ["Rechargeable shields", "Plasma-based technology", "Advanced sensors"], image: "/images/naki.webp", accent: "green" },
];
