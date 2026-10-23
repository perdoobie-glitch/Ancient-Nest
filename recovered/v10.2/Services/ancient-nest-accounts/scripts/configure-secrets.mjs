import {spawnSync} from 'node:child_process';
import {existsSync,readFileSync} from 'node:fs';
const npx=process.platform==='win32'?'npx.cmd':'npx';
const names=['ACCOUNT_SIGNING_KEY','CODE_PEPPER','COORDINATOR_API_KEY'];
const paths=['.secrets/account-signing-private.pem','.secrets/code-pepper.txt','.secrets/coordinator-api-key.txt'];
function run(command,args,options={}){const r=spawnSync(command,args,{encoding:'utf8',shell:process.platform==='win32',...options});if(r.error)throw r.error;return r;}
try{
 const result=run(npx,['wrangler','secret','list']);
 if(result.status!==0)throw Error('Could not inspect existing Worker secret names. Log in/deploy the selected account Worker first. Nothing was generated or changed.');
 let existing;try{existing=JSON.parse(result.stdout);}catch{throw Error('Could not read Wrangler secret-list response. Nothing was generated or changed.');}
 if(!Array.isArray(existing))throw Error('Unexpected secret-list response. Nothing changed.');
 const count=names.filter(name=>existing.some(item=>item.name===name)).length;
 if(count===3){console.log('All account signing/stats secrets already exist in Cloudflare. Preserved them; no new keys generated. A new PC does not require resetting them.');process.exit(0);}
 if(count>0)throw Error('Some account secrets already exist. Stop and restore the original missing values; do not regenerate production keys.');
 const local=paths.filter(path=>existsSync(path)).length;
 if(local>0&&local<3)throw Error('Local secret backup is incomplete. Restore the original complete backup before continuing.');
 if(local===0){const generated=run(process.execPath,['scripts/generate-keys.mjs'],{stdio:'inherit'});if(generated.status!==0)throw Error('Local key generation did not complete. Check .secrets and restore any existing backup.');}
 for(let i=0;i<names.length;i++){
  const upload=run(npx,['wrangler','secret','put',names[i]],{input:readFileSync(paths[i],'utf8')});
  if(upload.status!==0)throw Error(`Uploading ${names[i]} failed. Local secret files were preserved. Restore missing remote values using these SAME files; do not generate replacements.`);
  console.log(`Installed ${names[i]} (value not printed).`);
 }
 console.log('Account secrets installed. Back up .secrets privately. Never include it in the game ZIP.');
}catch(error){console.error('Setup stopped: '+error.message);process.exitCode=1;}
