import {PLAYLISTS,VERSION} from "./core";
type J=Record<string,any>;
export function snapshot(rooms:J[], users:J[], parties:J[], history:J[], totals:J, time:number, capabilities:J):J {
 const online=new Set(users.filter(a=>a.build===VERSION && time-a.seen<15).map(a=>a.user));
 const liveParties=parties.filter(p=>p.members.some((u:string)=>online.has(u)));
 const active=rooms.filter(r=>!["complete","failed"].includes(r.phase));
 const matches=rooms.map(r=>{
  const players=Object.entries(r.roster).map(([id,m]:[string,any])=>({name:m.name,team:m.faction,online:online.has(id),host:id===r.authority}));
  return {id:r.id,playlist:r.playlist,mode:r.config.mode,map:r.config.map,phase:r.phase,epoch:r.epoch,capacity:players.length,online:players.filter(p=>p.online).length,disconnected:players.filter(p=>!p.online).length,host:r.roster[r.authority]?.name||"Selecting host",age_seconds:Math.max(0,Math.floor(time-r.born)),players,live:r.live||null};
 });
 const playlists=Object.entries(PLAYLISTS).map(([id,p])=>({id,name:p.name,team_size:p.size/2,max_players:p.size,searching:users.filter(a=>a.playlist===id && a.queued && online.has(a.user)).length,parties:liveParties.filter(q=>q.playlist===id).length,playing:active.filter(r=>r.playlist===id && r.phase==="running").length,forming:active.filter(r=>r.playlist===id && r.phase!=="running").length}));
 const activeRows=matches.filter(r=>!["complete","failed"].includes(r.phase));
 const modeNames:Record<number,string>={0:"Extraction",1:"Iso Deathmatch",2:"Team Deathmatch",3:"Capture the Flag",4:"Bomb Defusal"};
 return {release:"10.5-dev",protocol:VERSION,generated_at:time,scope:"master-coordinated matches only",offline_practice:"not tracked",capabilities,
 summary:{online_players:online.size,queued_players:users.filter(a=>a.queued&&online.has(a.user)).length,parties:liveParties.length,playing_matches:active.filter(r=>r.phase==="running").length,forming_matches:active.filter(r=>!["running","results"].includes(r.phase)).length,results_matches:active.filter(r=>r.phase==="results").length,disconnected_slots:activeRows.reduce((n,r)=>n+r.disconnected,0),...totals},
 playlists,game_types:Object.entries(modeNames).map(([id,name])=>({id:Number(id),name,playing:active.filter(r=>r.phase==="running"&&r.config.mode===Number(id)).length})),matches,recent:history.slice(-100).reverse()};
}
export async function monitorAuthorized(request:Request,token:string|undefined):Promise<boolean>{
 if(!token||token.length<32)return false;
 const provided=request.headers.get("Authorization")||"";
 if(!provided.startsWith("Bearer ")||provided.length>256)return false;
 const hash=(s:string)=>crypto.subtle.digest("SHA-256",new TextEncoder().encode(s));
 const [a,b]=await Promise.all([hash(provided.slice(7)),hash(token)]);
 const aa=new Uint8Array(a),bb=new Uint8Array(b);let difference=0;
 for(let i=0;i<aa.length;i++)difference|=aa[i]^bb[i];return difference===0;
}
