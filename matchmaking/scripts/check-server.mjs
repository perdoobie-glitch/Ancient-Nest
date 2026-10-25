import {generateKeyPairSync,sign} from 'node:crypto';
import {createInterface} from 'node:readline/promises';
import {writeFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
export const EXPECTED='10.5-discord2';
export function masterOrigin(value){
 const normalized=value.trim().replace(/^wss:/,'https:').replace(/^ws:/,'http:');const u=new URL(normalized);
 if(u.username||u.password||u.search||u.hash)throw Error('Use the master origin only, without credentials or query parameters.');
 if(u.protocol!=='https:'&&!(u.protocol==='http:'&&['localhost','127.0.0.1'].includes(u.hostname)))throw Error('An HTTPS master URL is required.');
 if(!['/','/health','/ready','/v1/matchmaking'].includes(u.pathname))throw Error('Use your matchmaking Worker URL, not a website page.');
 return u.origin;
}
export async function checkServer(value,{output=console.log}={}){
 const origin=masterOrigin(value),report={origin,checked_at:new Date().toISOString(),checks:[],passed:false};
 const record=(status,message)=>{report.checks.push({status,message});output(`${status}  ${message}`);};
 const get=async(path)=>{const r=await fetch(origin+path,{redirect:'error',signal:AbortSignal.timeout(10000)});if(!r.ok)throw Error(`${path}: HTTP ${r.status}`);try{return await r.json();}catch{throw Error(`${path}: expected a JSON service response. Use the matchmaking Worker URL, not the website.`);}};
 try{
  const health=await get('/health');if(health.service!=='ancient-nest-matchmaking')throw Error('This URL is not the Ancient Nest matchmaking Worker.');
  if(health.version!==EXPECTED||health.release!=='10.5-dev')throw Error(`Version mismatch: deploy the 10.5-dev master. Reported version: ${health.version||'unknown'}`);
  record('PASS','HTTPS master responds with the correct 10.5-dev protocol.');
  const ready=await get('/ready');if(!ready.ready||!ready.checks?.coordinator||ready.version!==EXPECTED)throw Error('The Durable Object coordinator is not ready. Check the MATCHMAKER binding and deployment.');
  record('PASS','Durable Object coordinator initialized and persistent identity loaded.');
  const guest=ready.checks.auth_mode==='guest';
  if(!guest&&!ready.checks.account_bridge_configured)throw Error('Production account bridge is not configured. Set ACCOUNT_API and shared COORDINATOR_API_KEY, or use private-test setup.');
  const keys=generateKeyPairSync('rsa',{modulusLength:2048});
  await new Promise((resolve,reject)=>{
   const ws=new WebSocket(origin.replace(/^http/,'ws')+'/v1/matchmaking');const timer=setTimeout(()=>finish(Error('WebSocket challenge timed out. Check Worker routes and firewall.')),12000);let complete=false;
   function finish(error){if(complete)return;complete=true;clearTimeout(timer);ws.close();error?reject(error):resolve();}
   ws.addEventListener('open',()=>ws.send(JSON.stringify({type:'hello',lobby_only:true,name:'SetupCheck',playlist:'duel_1v1',version:EXPECTED,public_key:keys.publicKey.export({format:'pem',type:'spki'})})));
   ws.addEventListener('message',(event)=>{try{const p=JSON.parse(event.data);if(p.type==='error')return finish(Error(p.message||p.reason||'Master rejected setup check.'));if(p.type==='challenge'){
    record('PASS','Secure WebSocket and game identity challenge work.');
    if(!guest){record('NOTE','Account-required mode: link your game and sign in to verify a full player session.');return finish();}
    ws.send(JSON.stringify({type:'proof',signature:sign('sha256',Buffer.from(p.nonce),keys.privateKey).toString('base64')}));
   }else if(p.type==='party'){record('PASS','Private guest identity authenticated and opened a party without searching.');finish();}}catch(e){finish(e);}});
   ws.addEventListener('error',()=>finish(Error('WebSocket connection failed.')));ws.addEventListener('close',()=>{if(!complete)finish(Error('Master closed the connection before validation finished.'));});
  });
  record(guest?'WARN':'PASS',guest?'Guest mode is ON: private/unranked testing only.':'Account-required mode is enabled; account keys are configured, but external Steam/account sign-in was not exercised.');
  record(ready.checks.turn_configured?'NOTE':'WARN',ready.checks.turn_configured?'TURN keys are present; test two separate networks to verify provider access and relay connectivity.':'TURN keys are missing. Run Configure TURN.cmd before testing difficult NAT networks.');
  record(ready.checks.monitor_configured?'PASS':'WARN',ready.checks.monitor_configured?'Private monitor access is configured.':'Monitor key is missing. Run Configure Monitor.cmd.');
  report.passed=true;output('PASS  Master checks passed. Complete a real two-player match on separate networks before release.');
 }catch(error){record('FAIL',error.message);}
 return report;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 let input=process.argv[2];if(!input){const rl=createInterface({input:process.stdin,output:process.stdout});input=await rl.question('Paste your matchmaking Worker HTTPS URL: ');rl.close();}
 let report;try{report=await checkServer(input);}catch(e){report={passed:false,error:e.message};console.error('FAIL  '+e.message);}
 await writeFile('server-check-result.json',JSON.stringify(report,null,2)+'\n');console.log('Saved server-check-result.json (no private keys or tokens).');process.exitCode=report.passed?0:1;
}
