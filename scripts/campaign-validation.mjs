import {spawn} from 'node:child_process';import fs from 'node:fs';import os from 'node:os';import path from 'node:path';import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));const engine=process.env.GODOT_BIN||'C:/Users/Corey/Documents/AncientNest-Unified-Setup-e0bf594/Tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe';
const out=fs.mkdtempSync(path.join(os.tmpdir(),'nest-campaign-validation-'));console.log('Reports: '+out);
const fixtures=process.argv.slice(2);if(!fixtures.length)fixtures.push('campaign_state','campaign_ui','campaign_mission','campaign_spawn','campaign_combat','unified_account','falling_and_weapon_controls','server_browser','master_control','network_policy','film_playback','age_policy','discord_dashboard_layout');
const results=[];
for(const name of fixtures){
 if(!/^[a-z_]+$/.test(name))throw Error('Invalid fixture name');
 const file=path.join(out,name+'.log'),fd=fs.openSync(file,'w');
 const child=spawn(engine,['--headless','--path',path.join(root,'game'),'--script','res://tests/'+name+'.gd'],{cwd:root,env:{...process.env,APPDATA:path.join(out,name+'-user'),NEST_ISOLATED_QA:'1'},stdio:['ignore',fd,fd],windowsHide:true});
 let timedOut=false;const timeout=setTimeout(()=>{timedOut=true;child.kill();},90000);
 const code=await new Promise(resolve=>{child.once('exit',resolve);child.once('error',()=>resolve(-1));});clearTimeout(timeout);fs.closeSync(fd);
 const log=fs.readFileSync(file,'utf8');const scriptErrors=/SCRIPT ERROR|Parse Error|Compile Error|(?:^|\n)FAIL[: ]/m.test(log);const passed=code===0&&!timedOut&&!scriptErrors;
 results.push({fixture:name,passed,code,timedOut,scriptErrors});console.log((passed?'PASS ':'FAIL ')+name);
 if(!passed)console.log(log.split('\n').filter(l=>/SCRIPT ERROR|Parse Error|FAIL|res:\/\//.test(l)).slice(0,12).join('\n'));
}
fs.writeFileSync(path.join(out,'summary.json'),JSON.stringify({passed:results.every(x=>x.passed),results},null,2));console.log('Reports: '+out);if(results.some(x=>!x.passed))process.exitCode=1;
