import {spawn} from 'node:child_process';
import fs from 'node:fs';import os from 'node:os';import path from 'node:path';import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
const engine=process.env.GODOT_BIN||'C:/Users/Corey/Documents/AncientNest-Unified-Setup-e0bf594/Tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe';
const count=Number(process.argv[2]||2);if(![2,4].includes(count))throw Error('Use 2 or 4 clients');
const out=fs.mkdtempSync(path.join(os.tmpdir(),'nest-chapters-native-'));console.log('Reports: '+out);
const children=[],fds=[],seq=Array(count).fill(0),cache=[],checks=[];const pause=ms=>new Promise(r=>setTimeout(r,ms));
function state(i){try{cache[i]=JSON.parse(fs.readFileSync(path.join(out,'state-'+i+'.json')));}catch{}return cache[i];}
function command(i,action,extra={}){fs.writeFileSync(path.join(out,'command-'+i+'.json'),JSON.stringify({sequence:++seq[i],action,...extra}));}
const all=fn=>Array.from({length:count},(_,i)=>state(i)).every(s=>s&&fn(s));
async function wait(label,fn,seconds=45){const end=Date.now()+seconds*1000;while(Date.now()<end){if(fn()){checks.push(label);console.log('PASS '+label);return;}for(let i=0;i<count;i++){if(/SCRIPT ERROR|Parse Error|Compile Error/.test(fs.readFileSync(path.join(out,'client-'+i+'.log'),'utf8')))throw Error('Script error in client '+i);}await pause(150);}throw Error(label+' timed out: '+JSON.stringify(cache));}
async function sent(i,action,extra={}){command(i,action,extra);await wait('Command '+action+' accepted by '+i,()=>state(i)?.sequence===seq[i]);}
try{
 for(let i=0;i<count;i++){const fd=fs.openSync(path.join(out,'client-'+i+'.log'),'w');fds.push(fd);children.push(spawn(engine,['--headless','--path',path.join(root,'game'),'--script','res://tests/campaign_native.gd','--',out,String(i),'18779'],{cwd:root,env:{...process.env,APPDATA:path.join(out,'user-'+i),NEST_ISOLATED_QA:'1'},stdio:['ignore',fd,fd],windowsHide:true}));}
 await wait('Native clients ready',()=>all(s=>!s.active));await sent(0,'select_mission',{mission:2});await sent(0,'host');
 for(let i=1;i<count;i++)await sent(i,'join');
 await wait('All existing squad seats join',()=>all(s=>s.members===count&&s.slot>0));
 for(let i=0;i<count;i++)await sent(i,'ready');await sent(0,'start');
 await wait('Mission 2 loads four motorcycles on every peer',()=>all(s=>s.mission===2&&s.phase==='CHAPTER'&&s.loaded&&Object.keys(s.journey?.motorcycles?.bikes||{}).length===4),70);
 for(let i=0;i<count;i++)await sent(i,'pickup_hold');await pause(1800);
 for(let i=0;i<count;i++)await sent(i,'stop_interact');
 await wait('Each player mounts own bike through held interaction',()=>all(s=>Array.from({length:count},(_,i)=>s.journey.motorcycles.bikes[String(i+1)]?.mounted).every(Boolean)));
 const slot=String(state(1).slot),before=state(0).positions[slot];await sent(1,'move');await pause(2300);await sent(1,'stop_move');
 await wait('Guest throttle moves authoritative motorcycle',()=>{const p=state(0)?.positions[slot];return p&&Math.hypot(p[0]-before[0],p[2]-before[2])>12;});
 await wait('Host vehicle position reaches the guest',()=>{const a=state(0)?.positions[slot],b=state(1)?.positions[slot];return a&&b&&Math.hypot(a[0]-b[0],a[2]-b[2])<4;});
 await sent(0,'chapter',{mission:3});
 await wait('World transition preserves co-op cameras and readiness',()=>all(s=>s.mission===3&&s.phase==='CHAPTER'&&s.loaded&&s.camera));
 await wait('Actual Annu are present in new chapter',()=>state(0)?.actors>count);await sent(0,'chapter_clear');
 await sent(0,'at_objective',{slot:Number(slot)});await pause(700);await sent(1,'pickup_hold');await pause(4000);await sent(1,'stop_interact');
 await wait('Guest objective advances shared mission stage',()=>all(s=>s.chapter_stage===1));
 await sent(0,'wipe');await wait('Squad wipe offers chapter retry',()=>all(s=>s.phase==='DEFEAT'));
 await sent(0,'retry');await wait('Retry retains completed stage and restores living squad',()=>all(s=>s.mission===3&&s.chapter_stage===1&&s.phase==='CHAPTER'&&s.alive&&s.camera));
 await sent(1,'disconnect');await wait('Chapter disconnect releases loading quorum',()=>state(0)?.connected===count-1);await sent(1,'join');
 await wait('Same enrolled player reconnects to chapter checkpoint',()=>all(s=>s.mission===3&&s.chapter_stage===1&&s.connected===count&&s.camera));
 for(let i=0;i<count;i++)command(i,'quit');await pause(1500);
 for(let i=0;i<count;i++)if(/SCRIPT ERROR|Parse Error|Compile Error/.test(fs.readFileSync(path.join(out,'client-'+i+'.log'),'utf8')))throw Error('Script error in client '+i);
 fs.writeFileSync(path.join(out,'summary.json'),JSON.stringify({passed:true,players:count,checks},null,2));console.log('PASS '+checks.length+' native chapter checkpoints');
}catch(error){fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.message,checks},null,2));console.error(error.message);process.exitCode=1;}
finally{for(const child of children)if(child.exitCode===null)child.kill();for(const fd of fds)fs.closeSync(fd);console.log('Reports: '+out);}
