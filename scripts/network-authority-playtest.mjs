import {spawn} from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import dgram from 'node:dgram';
const root=fileURLToPath(new URL('../',import.meta.url));
const engine=process.env.GODOT_BIN||'C:/Users/Corey/Documents/AncientNest-Unified-Setup-e0bf594/Tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe';
const out=fs.mkdtempSync(path.join(os.tmpdir(),'nest-authority-'));
console.log('Reports: '+out);
const fixture=process.argv[2]||'network_bidirectional_damage';
const children=[],fds=[];
let proxy=null,remote=null,seed=12345;
let connectPort=17956;
const impaired=process.argv.includes('--impaired');
if(impaired){
 proxy=dgram.createSocket('udp4');
 proxy.on('message',(packet,source)=>{
  const fromHost=source.port===17956;
  if(!fromHost)remote=source;
  const target=fromHost?remote:{address:'127.0.0.1',port:17956};
  seed=(Math.imul(seed,1664525)+1013904223)>>>0;if(!target||seed/4294967296<.02)return;
  const delay=25+(seed/4294967296-.5)*24;
  setTimeout(()=>{if(proxy)proxy.send(packet,target.port,target.address)},delay);
 });
 await new Promise(r=>proxy.bind(0,'127.0.0.1',r));connectPort=proxy.address().port;
}
try {
 for(const role of ['host','client']) {
  const fd=fs.openSync(path.join(out,role+'.log'),'w');fds.push(fd);
  const args=['--headless','--path',path.join(root,'game'),'--script','res://tests/'+fixture+'.gd','--',role];
  if(fixture==='network_netcode')args.push('17956',String(connectPort),path.join(out,role+'.json'),impaired?'jitter-loss':'clean');
  children.push(spawn(engine,args,{cwd:root,env:{...process.env,APPDATA:path.join(out,role+'-data')},stdio:['ignore',fd,fd],windowsHide:true}));
 }
 const until=Date.now()+240000;
 while(children.some(p=>p.exitCode===null)&&Date.now()<until)await new Promise(r=>setTimeout(r,200));
 for(const role of ['host','client'])console.log(fs.readFileSync(path.join(out,role+'.log'),'utf8').split('\n').filter(l=>/PASS |FAIL |SCRIPT ERROR|Parse Error|failures=/.test(l)).join('\n'));
 if(children.some(p=>p.exitCode!==0))throw Error('Fixture failed: '+out);
}finally{for(const p of children)if(p.exitCode===null)p.kill();for(const fd of fds)fs.closeSync(fd);if(proxy){const old=proxy;proxy=null;old.close();}}
