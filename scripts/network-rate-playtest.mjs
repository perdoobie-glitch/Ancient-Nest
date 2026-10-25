// Local two-process ENet experiment. This does not certify internet/relay performance.
import { spawn } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import dgram from "node:dgram";
import { fileURLToPath } from "node:url";
const root=fileURLToPath(new URL("../",import.meta.url));
const engine=process.env.GODOT_BIN||"C:/Users/Corey/Documents/AncientNest-Unified-Setup-e0bf594/Tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe";
const output=fs.mkdtempSync(path.join(os.tmpdir(),"nest-rate-playtest-"));
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const percentile=(values,p)=>{const a=[...values].sort((x,y)=>x-y);return a[Math.min(a.length-1,Math.floor(a.length*p))]||0;};
console.log("Reports: "+output);
const reports=[];
const actors=Number(process.env.NEST_RATE_ACTORS||10);
const intervals=(process.env.NEST_RATE_TICKS||'3,2,1').split(',').map(Number);
if(intervals.some(t=>![1,2,3].includes(t)))throw Error('NEST_RATE_TICKS must contain 1,2,3');
for(const impaired of [false,true])for(const ticks of intervals){
 const label=(impaired?"jitter-loss":"clean")+"-"+60/ticks;
 const folder=path.join(output,label);fs.mkdirSync(folder);
 const proxy=dgram.createSocket("udp4");const timers=new Set();let active=true,client=null,seed=12345;
 const random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
 let delivered=0,dropped=0,bytes=0;
 const hostPort=17962;
 proxy.on("message",(data,source)=>{
  const fromHost=source.port===hostPort;
  if(!fromHost)client=source;
  const target=fromHost?client:{address:"127.0.0.1",port:hostPort};
  if(!target)return;
  if(impaired&&random()<.02){dropped++;return;}
  const delay=impaired?25+(random()-.5)*24:0;
  const timer=setTimeout(()=>{timers.delete(timer);if(active){proxy.send(data,target.port,target.address);delivered++;bytes+=data.length;}},delay);timers.add(timer);
 });
 await new Promise(resolve=>proxy.bind(0,"127.0.0.1",resolve));
 const relayPort=proxy.address().port;const processes=[],fds=[];
 try{
  for(const role of ["host","client"]){
   const fd=fs.openSync(path.join(folder,role+".log"),"w");fds.push(fd);
   const child=spawn(engine,["--headless","--path",path.join(root,"game"),"--script","res://tests/network_load.gd","--",role,String(hostPort),String(relayPort),path.join(folder,role+".json"),"6",String(ticks),String(actors)],{cwd:root,env:{...process.env,APPDATA:path.join(folder,role+"-data")},stdio:["ignore",fd,fd],windowsHide:true});
   processes.push(child);
  }
  const deadline=Date.now()+35000;
  while(processes.some(child=>child.exitCode===null)&&Date.now()<deadline)await sleep(100);
  if(processes.some(child=>child.exitCode!==0))throw Error(label+" failed; inspect "+folder);
  const host=JSON.parse(fs.readFileSync(path.join(folder,"host.json")));
  const peer=JSON.parse(fs.readFileSync(path.join(folder,"client.json")));
  if(!host.valid||!peer.valid||peer.snapshot_hz!==60/ticks)throw Error(label+" produced invalid state");
  const ticksObserved=Number(peer.stats.interp_ticks||0)+Number(peer.stats.extrapolated_ticks||0);
  const row={label,hz:60/ticks,actors:host.actors,host_frame_p95_ms:percentile(host.frame_cost_ms,.95),encode_mean_ms:host.sample_encode_us/Math.max(1,host.sample_sent)/1000,payload_kib_per_sec:host.sample_payload_bytes/6/1024,estimated_nine_peer_mbps:host.sample_payload_bytes/6*9*8/1e6,client_buffer_p50_ms:percentile(peer.interpolation_ms,.5),client_buffer_p95_ms:percentile(peer.interpolation_ms,.95),received_hz:peer.snapshots_completed/6,extrapolation_percent:100*Number(peer.stats.extrapolated_ticks||0)/Math.max(1,ticksObserved),delivered,dropped,wire_bytes:bytes};
  row.host_physics_p95_ms=percentile(host.physics_cost_ms||[],.95);
  row.physics_overruns=host.stats.physics_overruns||0;
  row.recording_capture_mean_ms=Number(host.recording_metrics?.capture_us||0)/Math.max(1,Number(host.recording_metrics?.samples||0))/1000;
  row.transport_bytes_sent_per_second=host.stats.transport_bytes_sent_per_second||0;
  row.transport_bytes_received_per_second=host.stats.transport_bytes_received_per_second||0;
  row.transport_packets_sent_per_second=host.stats.transport_packets_sent_per_second||0;
  row.transport_packets_received_per_second=host.stats.transport_packets_received_per_second||0;
  reports.push(row);console.log(JSON.stringify(row));
 }finally{
  for(const child of processes)if(child.exitCode===null)child.kill();
  active=false;for(const timer of timers)clearTimeout(timer);proxy.close();
  for(const fd of fds)fs.closeSync(fd);
 }
}
fs.writeFileSync(path.join(output,"summary.json"),JSON.stringify(reports,null,2));
console.log("PASS all "+reports.length+" rate/impairment experiments; summary: "+path.join(output,"summary.json"));
