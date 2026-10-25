import {spawn} from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
const engine=process.env.GODOT_BIN||'C:/Users/Corey/Documents/AncientNest-Unified-Setup-e0bf594/Tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe';
const out=fs.mkdtempSync(path.join(os.tmpdir(),'nest-campaign-render-'));
const fd=fs.openSync(path.join(out,'renderer.log'),'w');
const report=path.join(out,'render.json');
console.log('Rendered scenery benchmark, isolated profile: '+out);
const child=spawn(engine,['--path',path.join(root,'game'),'--script','res://tests/campaign_render.gd'],{cwd:root,env:{...process.env,APPDATA:path.join(out,'user'),NEST_ISOLATED_QA:'1',NEST_RENDER_REPORT:report},stdio:['ignore',fd,fd],windowsHide:true});
let timeout=false;const timer=setTimeout(()=>{timeout=true;child.kill();},90000);
const code=await new Promise(resolve=>{child.once('exit',resolve);child.once('error',()=>resolve(-1));});clearTimeout(timer);fs.closeSync(fd);
const log=fs.readFileSync(path.join(out,'renderer.log'),'utf8');
if(code!==0||timeout||/SCRIPT ERROR|Parse Error|Shader compilation failed/.test(log)||!fs.existsSync(report)){console.error(log);process.exitCode=1;}
else for(const row of JSON.parse(fs.readFileSync(report,'utf8')))console.log(JSON.stringify(row));
console.log('Scenery only: excludes gameplay/AI, sustained thermals, and physical-PC co-op. No claim of uncapped gameplay FPS.');
