export const RANK_NAMES=['Forgebound','Striker','Sentinel','Vanguard','Praetorian','War Marshal','Ascendant'] as const;
export function rank(rp:number){const stage=Math.min(21,Math.floor(Math.max(0,rp)/150)+1);const name=stage===21?'Angel':RANK_NAMES[Math.floor((stage-1)/3)];const tier=['I','II','III'][(stage-1)%3];return {number:stage,name,tier,league:stage===21?'Angel':name+' '+tier};}
export function performance(scores:number[]):number[]{return scores.map(score=>{const above=scores.filter(s=>s>score).length;const tied=scores.filter(s=>s===score).length;return scores.length<2?100:100-50*(above+(tied-1)/2)/(scores.length-1);});}
export function elo(before:number,ownAverage:number,opponentAverage:number,outcome:number):number {const expected=1/(1+10**((opponentAverage-ownAverage)/400));let delta=Math.round(32*(outcome-expected));if(outcome===1)delta=Math.max(1,delta);if(outcome===0)delta=Math.min(-1,delta);return Math.max(1,before+delta);}

export type PlaylistCard={elo:number;matches:number;wins:number;losses:number;draws:number;kills:number;deaths:number;assists:number;flags_captured:number;flags_stopped:number;player_rating:number|null};
export function serviceCard(cards:PlaylistCard[],includeUnplayed=false){
 const played=cards.filter(c=>c.matches>0),included=includeUnplayed?cards:played;
 const mean=(values:number[])=>values.length?values.reduce((a,b)=>a+b,0)/values.length:null;
 const weight=included.reduce((n,c)=>n+Math.max(1,c.matches),0);
 const eloAverage=weight?included.reduce((n,c)=>n+c.elo*Math.max(1,c.matches),0)/weight:null;const eloValue=eloAverage===null?1:Math.round(eloAverage);
 const rated=played.filter(c=>c.matches>=3&&c.player_rating!==null);
 const rating=mean(rated.map(c=>c.player_rating!));const rankInfo=rank(eloValue);
 const totals=Object.fromEntries(['matches','wins','losses','draws','kills','deaths','assists','flags_captured','flags_stopped'].map(key=>[key,cards.reduce((sum,c)=>sum+c[key as keyof PlaylistCard]!,0)]));
 return {scope:'service',league:rankInfo.league,rank_level:rankInfo.number,elo:eloValue,elo_average:eloAverage,player_rating:rating===null?null:Math.round(rating),rating_grade:ratingGrade(rating),...totals,kd:totals.deaths?totals.kills/totals.deaths:null,playlists_played:played.length,playlists_rated:rated.length,playlists_total:cards.length,averaging:includeUnplayed?'match_weighted_all_playlists':'match_weighted_played_playlists',rating_averaging:'equally_weighted_rated_playlists',has_record:played.length>0};
}

export function ratingGrade(value:number|null):string|null {
 if(value===null||!Number.isFinite(value))return null;
 const rating=Math.round(Math.max(0,Math.min(100,value)));
 for(const [low,grade] of [[97,'A+'],[93,'A'],[90,'A−'],[87,'B+'],[83,'B'],[80,'B−'],[77,'C+'],[73,'C'],[70,'C−'],[67,'D+'],[63,'D'],[60,'D−'],[0,'F']] as const)if(rating>=low)return grade;
 return 'F';
}
