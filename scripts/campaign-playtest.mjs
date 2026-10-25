import {spawn} from 'node:child_process';
import fs from 'node:fs';import os from 'node:os';import path from 'node:path';import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
const engine=process.env.GODOT_BIN||'C:/Users/Corey/Documents/AncientNest-Unified-Setup-e0bf594/Tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe';
const count=Number(process.argv[2]||2);if(![2,4].includes(count))throw Error('Use 2 or 4 clients');
const out=fs.mkdtempSync(path.join(os.tmpdir(),'nest-campaign-'));console.log('Reports: '+out);
const children=[],fds=[],seq=Array(count).fill(0),cached=[],checks=[];const pause=ms=>new Promise(r=>setTimeout(r,ms));
function state(i){try{cached[i]=JSON.parse(fs.readFileSync(path.join(out,'state-'+i+'.json')));}catch{}return cached[i];}
function command(i,action,extra={}){fs.writeFileSync(path.join(out,'command-'+i+'.json'),JSON.stringify({sequence:++seq[i],action,...extra}));}
async function wait(label,fn,seconds=35){const end=Date.now()+seconds*1000;while(Date.now()<end){if(fn()){console.log('PASS '+label);checks.push(label);return;}await pause(120);}throw Error(label+' timed out. States: '+JSON.stringify(Array.from({length:count},(_,i)=>state(i))));}
const all=fn=>Array.from({length:count},(_,i)=>state(i)).every(s=>s&&fn(s));
try{
 for(let i=0;i<count;i++){const fd=fs.openSync(path.join(out,'client-'+i+'.log'),'w');fds.push(fd);children.push(spawn(engine,['--headless','--path',path.join(root,'game'),'--script','res://tests/campaign_native.gd','--',out,String(i),'17779'],{cwd:root,env:{...process.env,APPDATA:path.join(out,'user-'+i)},stdio:['ignore',fd,fd],windowsHide:true}));}
 await wait('Native clients ready',()=>all(s=>!s.active));command(0,'host');await wait('Host opens expedition',()=>state(0)?.active);
 for(let i=1;i<count;i++)command(i,'join');
 await wait(count+' members join with host-selected Difficulty',()=>all(s=>s.members===count&&s.difficulty==='Hard'&&s.slot>0));
 for(let i=0;i<count;i++)command(i,'ready');await pause(700);command(0,'start');
 await wait('Shared intro starts only after load readiness',()=>all(s=>s.phase==='INTRO'&&s.loaded));
 command(0,'skip');await pause(700);if(!all(s=>s.phase==='INTRO'))throw Error('A single skip vote ended the co-op intro');checks.push('Single skip vote cannot skip squad cinematic');
 for(let i=1;i<count;i++)command(i,'skip');await wait('Unanimous skip restores preparation and input transport',()=>all(s=>s.phase==='PREPARATION'&&s.running&&s.camera));
 command(0,'practice_one');await pause(700);if(!all(s=>s.phase==='PREPARATION'))throw Error('One player completed other players readiness');checks.push('Personal readiness does not complete another player');
 command(1,'flashlight');await wait('Independent flashlight state replicates',()=>all(s=>s.flashlights[String(state(1).slot)]===true&&!s.flashlights['1']));
 command(0,'practice_all');await wait('Whole squad preparation unlocks boarding',()=>all(s=>s.phase==='BOARDING'));
 command(0,'board_all');await wait('Boarded squad launches',()=>all(s=>s.phase==='DEPARTURE'&&s.loaded));
 for(let i=0;i<count;i++)command(i,'skip');await wait('Departure initializes deterministic forest crash',()=>all(s=>s.phase==='CRASH'&&s.loaded));
 for(let i=0;i<count;i++)command(i,'skip');await wait('Crash handoff restores all local cameras',()=>all(s=>s.phase==='CRASH_ORIENTATION'&&s.camera));
 const movingSlot=String(state(1).slot),beforeMove=state(0).positions[movingSlot];command(1,'move');await pause(1300);command(1,'stop_move');
 await wait('Remote movement is accepted after the crash session reset',()=>{const p=state(0)?.positions[movingSlot];return p&&Math.hypot(p[0]-beforeMove[0],p[2]-beforeMove[2])>.7&&state(0).acknowledgements[movingSlot]>0;});
 command(0,'down',{slot:state(1).slot});await wait('Downed state replicates',()=>state(1)?.alive===false&&all(s=>s.downed===1));
 command(0,'revive',{slot:state(1).slot});await wait('Teammate revive restores shared downed state',()=>all(s=>s.downed===0)&&state(1)?.alive===true);
 command(0,'charge');await wait('Shared charge recovery commits once',()=>all(s=>s.bomb==='carried')&&state(0)?.result.charge===true&&state(0)?.result.duplicate_charge===false);
 command(0,'secure');await wait('Charge security replicates independently of waves',()=>all(s=>s.bomb==='secured'));
 command(1,'disconnect');await wait('Disconnect removes readiness requirements',()=>state(0)?.connected===count-1&&!state(1)?.active);
 command(1,'join');await wait('Enrolled client reconnects to existing mission',()=>all(s=>s.connected===count&&s.phase==='CRASH_ORIENTATION'&&s.camera),45);
 command(0,'wave');await wait('Assault starts',()=>all(s=>s.phase==='WAVE_1'));
 command(0,'wipe');await wait('Full squad defeat is authoritative',()=>all(s=>s.phase==='DEFEAT'));
 command(0,'retry');await wait('Checkpoint retry preserves secured charge',()=>all(s=>s.phase==='CRASH_ORIENTATION'&&s.bomb==='secured'&&s.alive));
 command(0,'wave');await wait('Retry starts clean wave one',()=>all(s=>s.phase==='WAVE_1'));
 const beforeAmmo=state(1).ammo[0],hostAmmo=state(0).ammo[0];command(1,'fire');await pause(900);command(1,'stop_fire');await wait('Client weapon consumption remains independent and authoritative',()=>state(1)?.ammo[0]<beforeAmmo&&state(0)?.ammo[0]===hostAmmo);
 for(let wave=0;wave<5;wave++){command(0,'finish_wave');await wait('Wave '+(wave+1)+' exact kills replicate',()=>all(s=>s.waves===wave+1));if(wave<4){command(0,'wave');await wait('Next wave guard '+(wave+2),()=>all(s=>s.phase==='WAVE_'+(wave+2)));}}
 await wait('Radio becomes ready after thirty-four enemies',()=>all(s=>s.phase==='RADIO_READY'&&s.kills===34));command(0,'radio');await wait('Ending synchronizes',()=>all(s=>s.phase==='ENDING'&&s.loaded));
 for(let i=0;i<count;i++)command(i,'skip');await wait('Completion saves exactly once for squad',()=>all(s=>s.phase==='COMPLETE'&&s.completion===1));
 for(let i=0;i<count;i++)command(i,'quit');await pause(1500);
 for(let i=0;i<count;i++){const log=fs.readFileSync(path.join(out,'client-'+i+'.log'),'utf8');if(/SCRIPT ERROR|Parse Error|Compile Error/.test(log))throw Error('Native client script errors: '+i);}
 fs.writeFileSync(path.join(out,'summary.json'),JSON.stringify({passed:true,players:count,checks},null,2));console.log('PASS '+checks.length+' campaign checkpoints with '+count+' clients');
}catch(error){fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.message,checks},null,2));console.error(error.message);process.exitCode=1;}
finally{for(const child of children)if(child.exitCode===null)child.kill();for(const fd of fds)fs.closeSync(fd);console.log('Reports: '+out);}
