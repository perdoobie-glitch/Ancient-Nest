import { PageIntro } from "@/components/PageIntro";
import { AccountPanel } from "@/components/AccountPanel";
import { pageMetadata } from "@/lib/metadata";
export const metadata={...pageMetadata("Account","Sign in through Steam and securely link your own Ancient Nest game installation.","/account"),robots:{index:false,follow:true}};
export default function AccountPage(){return <><PageIntro eyebrow="Player services / Account" title="One account. Your game.">Create your Ancient Nest account through Steam, choose a username, and approve the connection from your own game.</PageIntro><section className="section section-first container"><AccountPanel/></section></>;}
