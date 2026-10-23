import { FeatureCard } from "@/components/FeatureCard";
import { combatStyles } from "@/data/story";
export function CombatStyles() {
  return <>
    <div className="two-grid">
      {combatStyles.map(style => <FeatureCard key={style.title} title={style.title} description={style.description} icon={style.icon} status="Game-type traits"/>)}
    </div>
    <p className="section-footnote">Combat styles are controlled by game-type traits. By default, Annu uses conventional weapons, armor, and health; Naki uses advanced energy technology and rechargeable shields. Annu receives advanced capabilities only when the selected game type explicitly grants them.</p>
  </>;
}
