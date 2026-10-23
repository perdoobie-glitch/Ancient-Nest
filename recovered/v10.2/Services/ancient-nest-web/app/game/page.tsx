import { PageIntro } from "@/components/PageIntro";
import { SectionTitle } from "@/components/SectionTitle";
import { FactionCard } from "@/components/FactionCard";
import { FeatureCard } from "@/components/FeatureCard";
import { Button } from "@/components/Button";
import { CommunityCTA } from "@/components/CommunityCTA";
import { DevelopmentStory } from "@/components/DevelopmentStory";
import { CombatStyles } from "@/components/CombatStyles";
import { factions } from "@/data/factions";
import { site } from "@/data/site";
import { pageMetadata } from "@/lib/metadata";

export const metadata = pageMetadata("The Game", "Explore Ancient Nest’s development story, Annu and Naki, gold-based technology, Brutus Link, combat traits and game types.", "/game");
export default function GamePage() {
  return <>
    <PageIntro eyebrow="Field guide / The game" title="Ancient world. New warfare.">An independent multiplayer FPS from {site.studio}. Precise gunplay, distinct factions, and different ways to fight for the Nest.</PageIntro>
    <nav className="section-nav container" aria-label="Game overview sections">
      {["Overview", "Factions", "Combat", "Movement", "Weapons", "Maps", "Game types", "Our story"].map(name => <a key={name} href={`#${name.toLowerCase().replaceAll(" ", "-")}`}>{name}</a>)}
    </nav>
    <section id="overview" className="section container about-grid">
      <SectionTitle eyebrow="Overview" title="Read the ground. Own the moment."/>
      <div className="about-copy"><p className="lead">Two forces. Different knowledge. A shared battlefield.</p><p>Ancient Nest combines deliberate team play with responsive combat in spaces shaped by ruins and military technology. Choose longer shield-based firefights or a more grounded armor-and-health experience through configurable game-type traits.</p><p className="muted">The game is in development. Features, balance, maps, and availability may change.</p></div>
    </section>
    <section id="factions" className="section section-inset"><div className="container"><SectionTitle eyebrow="Factions" title="Choose what you stand for."/><div className="faction-grid">{factions.map(faction => <FactionCard key={faction.id} faction={faction}/>)}</div></div></section>
    <section id="combat" className="section container"><SectionTitle eyebrow="Combat / Configurable traits" title="Find your kind of firefight."/><CombatStyles/></section>
    <div className="container section"><div className="game-systems">
      <section id="movement"><SectionTitle eyebrow="Movement" title="Know your way through."/><p>Use connected routes, elevation, cover, and opportunities for skilled jumps to create an advantage. Map knowledge and coordinated movement make familiar ground worth learning.</p></section>
      <section id="weapons"><SectionTitle eyebrow="Weapons" title="Steel meets plasma."/><p>Annu’s default arsenal uses conventional military weapons. Naki understands how refined gold components regulate its plasma and shield systems. Game-type overrides can explicitly grant advanced capabilities to Annu; those settings do not change its place in the story.</p></section>
      <section id="maps"><SectionTitle eyebrow="Maps" title="A future inside the ruins."/><p>Ancient stone, monumental architecture, cover, and vertical passages define the battlefield. Map development focuses on readable encounters, connected spaces, and opportunities for creative movement.</p><Button href="/community#maps" variant="text" arrow>Community maps</Button></section>
      <section id="reconnaissance"><SectionTitle eyebrow="Annu reconnaissance" title="Nu sees. Brutus Link shares."/><p>Nu’s conventional sensor and radio harness sends confirmed sightings to Annu’s tactical map through the Annu-exclusive Brutus Link. Last-known positions remain for ten seconds after enemies leave view, updating when they are seen again.</p><p>Brutus Link uses conventional reconnaissance technology. Naki’s radar provides a separate approach to battlefield awareness.</p></section>
    </div></div>
    <section id="game-types" className="section section-inset"><div className="container"><SectionTitle eyebrow="Game types" title="One world. Different objectives."/><div className="three-grid"><FeatureCard title="Free-For-All" status="Core mode" icon="cross" description="Every player for themselves. Test awareness, positioning, and individual combat."/><FeatureCard title="Team Deathmatch" status="Core mode" icon="shield" description="Coordinate eliminations and work together. Team-based formats support 1v1 through 5v5."/><FeatureCard title="Bomb Defuse" status="Core mode" icon="spark" description="Attack, plant, defend, or defuse. Team-based formats support 1v1 through 5v5."/></div><div className="button-group section-actions"><Button href="/play" arrow>Explore playlists</Button></div></div></section>
    <DevelopmentStory/>
    <CommunityCTA/>
  </>;
}
