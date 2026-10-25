// Real local native WebRTC lifecycle tests; guest identities only on loopback.
import { spawn } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
const root=fileURLToPath(new URL("../",import.meta.url));
const engine=process.env.GODOT_BIN||"C:/Users/Corey/Documents/AncientNest-Unified-Setup-e0bf594/Tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe";
const out=fs.mkdtempSync(path.join(os.tmpdir(),"nest-lifecycle-"));console.log("Reports: "+out);
const ps=[],fds=[],sequences=[0,0,0,0],checks=[];
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
function start(args,name,env){const fd=fs.openSync(path.join(out,name+".log"),"w");fds.push(fd);const p=spawn(args[0],args.slice(1),{cwd:root,env,stdio:["pipe",fd,fd],windowsHide:true});ps.push(p);return p;}
const lastStates=[]; function state(i){try{lastStates[i]=JSON.parse(fs.readFileSync(path.join(out,"state-"+i+".json")))}catch{}return lastStates[i]??null;}
function command(i,action,extra={}){fs.writeFileSync(path.join(out,"command-"+i+".json"),JSON.stringify({sequence:++sequences[i],action,...extra}));}
async function wait(label,test,seconds=40){const until=Date.now()+seconds*1000;while(Date.now()<until){if(test()){console.log("PASS "+label);checks.push(label);return;}await sleep(150);}throw Error(label+" timed out: "+JSON.stringify([0,1,2,3].map(state)));}
const playing=ids=>ids.every(i=>{const s=state(i);return s?.running&&!s.frozen&&s.phase==="playing"&&s.camera;});
const party=ids=>ids.every(i=>state(i)?.connected&&state(i)?.phase==="party"&&!state(i)?.running);
let success=false;
try{
 const env={...process.env,NEST_CF_STATE:path.join(out,"master"),NEST_QA_SHARED_CPU:"1"};
 start(["node","matchmaking/tests/local-server.mjs"],"server",env);
 await wait("Local coordinator ready",()=>fs.readFileSync(path.join(out,"server.log"),"utf8").includes("READY"),30);
 for(let i=0;i<3;i++)start([engine,"--headless","--path",path.join(root,"game"),"--script","res://tests/hybrid/lifecycle_client.gd","--",out,String(i),"--qa-hybrid-client"],"client-"+i,{...env,APPDATA:path.join(out,"user-"+i)});
 await wait("Two clients ready",()=>state(0)&&state(1));
 for(const i of [0,1,2])command(i,"browser");
 await wait("Three clients open browser",()=>party([0,1,2]));command(0,"create",{capacity:4});
 await wait("Owner creates public lobby",()=>state(0)?.party.custom);
 let code=state(0).party.code;command(1,"browse");
 await wait("Other player discovers lobby",()=>state(1)?.lobbies.some(l=>l.code===code));command(1,"join",{code});
 await wait("Both join same lobby",()=>[0,1].every(i=>state(i)?.party.code===code&&state(i)?.party.members.length===2));
 command(2,"join",{code});await wait("Third player joins custom lobby",()=>state(1)?.party.members.length===3);
 command(0,"leave_party");
 await wait("Owner departure transfers leadership",()=>state(1)?.party.members.length===2&&state(1)?.party.members[0].leader&&state(0)?.party.code!==code);
 command(0,"join",{code});await wait("Former owner rejoins",()=>state(1)?.party.members.length===3);command(1,"start");
 await wait("Three-player custom game has local first-person views",()=>playing([0,1,2])&&[0,1,2].every(i=>state(i).custom&&state(i).actors===3));
 await wait("Odd-sized custom checkpoint commits",()=>[0,1,2].every(i=>state(i)?.checkpoint));
 const beforeOutage=[0,1,2].map(i=>state(i).snapshots);const outageEpoch=state(0).epoch;
 for(const i of [0,1,2])command(i,"control_outage");
 await sleep(6000);
 await wait("Signed majority keeps gameplay live after injected master-lease expiry",()=>playing([0,1,2])&&[0,1,2].every(i=>!state(i).connected&&state(i).continuity>state(i).master_time&&state(i).epoch===outageEpoch)&&(state(0).authority||state(0).snapshots>beforeOutage[0]+60),10);
 for(const i of [0,1,2])command(i,"control_recover");
 await wait("Control reconnect restores registration without replacing gameplay transport",()=>playing([0,1,2])&&[0,1,2].every(i=>state(i).connected&&state(i).epoch===outageEpoch),25);
 let authority=[0,1,2].find(i=>state(i).authority);command(authority,"finish");
 await wait("Custom results return to same lobby",()=>party([0,1,2])&&[0,1,2].every(i=>state(i).party.code===code),25);
 command(1,"start");await wait("Custom lobby starts a second game",()=>playing([0,1,2]));
 const guest=[0,1,2].find(i=>!state(i).authority);command(guest,"drop");await sleep(900);command(guest,"browser");
 await wait("Disconnected client rejoins running custom game",()=>playing([0,1,2])&&[0,1,2].every(i=>state(i).actors===3),45);
 for(const i of [0,1,2])command(i,"disconnect");await sleep(1200);
 for(const i of [0,1])command(i,"matchmaking");await wait("Both open ranked party flow",()=>party([0,1])&&[0,1].every(i=>!state(i).custom));
 command(0,"search");await wait("Search countdown enters queue",()=>state(0)?.phase==="queue");command(0,"cancel");
 await wait("Cancel search restores both idle parties",()=>party([0,1]));
 for(const i of [0,1])command(i,"search");
 await wait("Matchmaking forms and starts 1v1",()=>playing([0,1])&&[0,1].every(i=>!state(i).custom&&state(i).actors===2),55);
 for(const i of [0,1])command(i,"disconnect");await sleep(1200);
 for(let i=3;i<4;i++)start([engine,"--headless","--path",path.join(root,"game"),"--script","res://tests/hybrid/lifecycle_client.gd","--",out,String(i),"--qa-hybrid-client"],"client-"+i,{...env,APPDATA:path.join(out,"user-"+i)});
 await wait("Four native clients ready",()=>[0,1,2,3].every(i=>state(i)));
 for(const i of [0,1,2,3])command(i,"matchmaking",{playlist:"doubles_2v2"});
 await wait("Four players open 2v2",()=>party([0,1,2,3])&&[0,1,2,3].every(i=>state(i)?.party?.playlist==="doubles_2v2"));
 command(1,"join",{code:state(0).party.code});command(3,"join",{code:state(2).party.code});
 await wait("Two two-player parties assemble",()=>state(0)?.party.members.length===2&&state(2)?.party.members.length===2);
 command(0,"search");command(2,"search");
 await wait("2v2 starts with four humans",()=>playing([0,1,2,3])&&[0,1,2,3].every(i=>state(i).actors===4),60);
 const roster=state(0).roster;const team=n=>roster.find(p=>p.name==="Playtester"+n)?.faction;
 if(team(0)!==team(1)||team(2)!==team(3)||team(0)===team(2))throw Error("Matchmaking split a party across teams");
 console.log("PASS parties remain on their assigned teams");checks.push("parties remain on their assigned teams");
 await wait("Checkpoint committed",()=>[0,1,2,3].every(i=>state(i)?.checkpoint));
 authority=[0,1,2,3].find(i=>state(i).authority);const remaining=[0,1,2,3].filter(i=>i!==authority);const epoch=state(authority).epoch;command(authority,"drop");
 await wait("Three-player majority restores after host departure",()=>playing(remaining)&&remaining.every(i=>state(i).epoch>epoch&&state(i).actors===4)&&remaining.filter(i=>state(i).authority).length===1,95);
 command(authority,"matchmaking",{playlist:"doubles_2v2"});
 await wait("Original host rejoins as a player after migration",()=>playing([0,1,2,3])&&[0,1,2,3].filter(i=>state(i).authority).length===1,45);
 success=true;fs.writeFileSync(path.join(out,"summary.json"),JSON.stringify({passed:true,checks,states:[0,1,2,3].map(state)},null,2));
 console.log("PASS all native lobby lifecycle checks");
}catch(error){fs.writeFileSync(path.join(out,"failure.json"),JSON.stringify({error:error.message,checks,states:[0,1,2,3].map(state)},null,2));console.error(error.message);process.exitCode=1;}
finally{
 for(const child of ps.slice(1))if(child.exitCode===null)child.kill();
 ps[0]?.stdin.end("shutdown\n");await sleep(2000);for(const child of ps)if(child.exitCode===null)child.kill();for(const fd of fds)fs.closeSync(fd);
 console.log((success?"Completed: ":"Failure reports: ")+out);
}
