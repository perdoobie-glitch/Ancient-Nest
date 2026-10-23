import { site } from "@/data/site";

export const developmentStory = [
  {
    id: "why", label: "01 / What & why", title: "A shared ambition.",
    paragraphs: [
      `Ancient Nest is an independent multiplayer FPS from ${site.studio}, combining ancient-world environments, futuristic warfare, and precise gunplay.`,
      "We’re building a game with room for different kinds of competition: longer shield-based firefights, grounded armor-and-health combat, and customizable rules. Duels, team deathmatch, bomb defuse, and creative tools give players different ways to make the Nest their own.",
    ],
  },
  {
    id: "feedback", label: "02 / Your part in development", title: "Be part of the change.",
    paragraphs: [
      "We’re developing Ancient Nest with community feedback in mind. Tell us when a weapon feels satisfying, a route creates a memorable fight, or an encounter feels unfair. Specific reports help us make better decisions about balance, performance, maps, and usability.",
      "Through playtesting, custom games, and Nest Forge, players can help shape the game as it grows. The studio remains responsible for its direction, with player experience helping guide each revision. Public playtest dates and feedback channels will be announced when ready.",
    ],
  },
  {
    id: "faction-story", label: "03 / Naki & Annu", title: "One resource. Unequal knowledge.",
    paragraphs: [
      "The Ancient Nest holds a resource whose true value its defenders have yet to understand: gold. Annu possesses it but has not discovered how to harness it for advanced energy technology. They defend their home with conventional weapons, armor, and reconnaissance.",
      "Naki possesses the knowledge Annu lacks. Compact energy cells provide power, while refined gold components help regulate the systems controlling its plasma weapons, rechargeable shields, and advanced equipment. To Naki, the Nest’s reserves represent the means to sustain its war effort.",
      "Annu’s falcon, Nu, carries a conventional sensor and radio harness. Its observations feed the Annu-exclusive Brutus Link tactical map. Confirmed sightings update the map; once an enemy leaves view, their last-known position remains for ten seconds. This reconnaissance does not rely on Annu understanding gold-powered technology.",
      "Annu fights to protect its home. Naki fights to control the resource behind its technological advantage. Faction defaults preserve those differences; a game type can explicitly grant Annu advanced traits without changing the story.",
    ],
  },
  {
    id: "invitation", label: "04 / Enter the Nest", title: "Help shape what comes next.",
    paragraphs: [
      "Learn its routes. Master your weapons. Find your team—or create a new way to play.",
      "Ancient Nest is growing through independent development and community feedback. Follow its progress, share what you discover during playtests, and help build a competitive community from the beginning. Your next match could help shape the next update.",
    ],
  },
] as const;

export const combatStyles = [
  { title: "Shield-based firefights", description: "Longer science-fiction engagements reward sustained accuracy, coordinated pressure, and timely retreats. Rechargeable-shield traits create opportunities to recover, reposition, and challenge an opponent again.", icon: "shield" as const },
  { title: "Armor & health combat", description: "A more grounded tactical pace puts greater weight on exposure, positioning, and decisive shooting. Conventional weapons, armor, and health define Annu’s default combat identity.", icon: "cross" as const },
] as const;
