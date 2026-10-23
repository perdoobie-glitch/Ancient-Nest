import { PageIntro } from "@/components/PageIntro";
import { AccountPanel } from "@/components/AccountPanel";
import { pageMetadata } from "@/lib/metadata";
export const metadata={...pageMetadata("Your Player Profile","Your verified Ancient Nest identity and linked game installations.","/profile"),robots:{index:false,follow:true}};
export default function ProfilePage(){return <><PageIntro eyebrow="Player services / Your profile" title="Your identity in the Nest.">Your verified identity and your recorded matchmaking results. New accounts begin at rank 1; Player Rating appears after five eligible matches.</PageIntro><section className="section section-first container"><AccountPanel profile/></section></>;}
