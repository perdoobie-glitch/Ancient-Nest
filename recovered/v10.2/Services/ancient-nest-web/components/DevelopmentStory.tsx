import { SectionTitle } from "@/components/SectionTitle";
import { Button } from "@/components/Button";
import { developmentStory } from "@/data/story";
export function DevelopmentStory() {
  return <section id="our-story" className="section section-inset">
    <div className="container">
      <SectionTitle eyebrow="Independent development / Our story" title="A world we build together." />
      <div className="game-systems">
        {developmentStory.map(section => <article key={section.id}>
          <span className="eyebrow">{section.label}</span>
          <h3 className="text-2xl mt-3 mb-4">{section.title}</h3>
          {section.paragraphs.map(paragraph => <p key={paragraph}>{paragraph}</p>)}
        </article>)}
      </div>
      <div className="button-group section-actions">
        <Button href="/community#feedback" arrow>Help shape the game</Button>
        <Button href="/play" variant="outline">Explore ways to play</Button>
      </div>
    </div>
  </section>;
}
