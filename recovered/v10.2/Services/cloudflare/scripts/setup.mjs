import {readFile,writeFile} from "node:fs/promises";
import {createInterface} from "node:readline/promises";
const rl=createInterface({input:process.stdin,output:process.stdout});
const ask=async(q,d)=>((await rl.question(q+" ["+d+"]: ")).trim()||d);
try {
 const mode=process.argv.includes("--guest")?"guest":"production";
 console.log("Ancient Nest 10.2 master setup. Guest mode is private, unranked testing; production requires linked accounts.");
 if((await ask("Continue with "+mode+" configuration? Type YES","NO"))!=="YES")process.exit(1);
 const worker=await ask("Worker name","ancient-nest-matchmaking");
 if(!/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(worker))throw Error("Use a lowercase Cloudflare Worker name.");
 const account=await ask("Accounts website HTTPS origin","https://ancientnest.net");const url=new URL(account);
 if(url.protocol!=="https:"||url.pathname!=="/"||url.search||url.hash||url.username||url.password)throw Error("Use an HTTPS origin only.");
 // wrangler.jsonc contains comments/trailing commas; keep the supplied shape, only replace public settings.
 let config=await readFile("wrangler.jsonc","utf8");config=config.replace(/"name":\s*"[^"]+"/,JSON.stringify("name")+": "+JSON.stringify(worker));
 config=config.replace(/"ACCOUNT_API":\s*"[^"]+"/,"\"ACCOUNT_API\": "+JSON.stringify(url.origin));config=config.replace(/"ALLOW_GUESTS":\s*"(?:true|false)"/,"\"ALLOW_GUESTS\": "+JSON.stringify(mode==="guest"?"true":"false"));
 await writeFile("wrangler.jsonc",config);console.log("Public configuration saved. Secrets were not changed. Now run Deploy Master.cmd.");
} catch(error){console.error(error.message);process.exitCode=1;}finally{rl.close();}
