import {readFile,writeFile} from "node:fs/promises";import {createInterface} from "node:readline/promises";
const rl=createInterface({input:process.stdin,output:process.stdout});const ask=async(q,d)=>((await rl.question(q+" ["+d+"]: ")).trim()||d);
try{
 console.log("Ancient Nest 10.1 accounts. A chosen existing Worker will be updated with the bundled website; back up newer live work first.");
 const worker=await ask("Worker name (use broken-wave-9d1e ONLY if intentionally updating that website)","ancient-nest-accounts");if(!/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(worker))throw Error("Invalid Worker name");
 const site=new URL(await ask("Canonical HTTPS website origin","https://ancientnest.net"));if(site.protocol!=="https:"||site.pathname!=="/"||site.search||site.hash||site.username||site.password)throw Error("Invalid HTTPS origin");
 const database=await ask("D1 database ID returned by wrangler d1 create","REQUIRED");if(!/^[a-f0-9-]{36}$/.test(database))throw Error("Paste the actual D1 UUID; do not type it as a command");
 let s=await readFile("wrangler.jsonc","utf8");s=s.replace(/"name":\s*"[^"]+"/,"\"name\": "+JSON.stringify(worker)).replace(/"SITE_ORIGIN":\s*"[^"]+"/,"\"SITE_ORIGIN\": "+JSON.stringify(site.origin)).replace(/"database_id":\s*"[^"]+"/,"\"database_id\": "+JSON.stringify(database));await writeFile("wrangler.jsonc",s);console.log("Public account configuration saved; existing secrets unchanged.");
}catch(e){console.error(e.message);process.exitCode=1;}finally{rl.close();}
