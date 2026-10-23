import {test} from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const result=await build({entryPoints:[new URL('../src/ranking.ts',import.meta.url).pathname],bundle:true,write:false,format:'esm',platform:'node'});
const {rank,performance,elo,serviceCard,ratingGrade}=await import('data:text/javascript;base64,'+Buffer.from(result.outputFiles[0].text).toString('base64'));
test('all 21 rank boundaries, bottom and cap',()=>{for(let n=1;n<=21;n++){assert.equal(rank((n-1)*150).number,n);if(n<21)assert.equal(rank(n*150-1).number,n);}assert.equal(rank(3200).number,21);assert.equal(rank(0).name,'Forgebound');assert.equal(rank(3000).tier,'III');});
test('six-player placements, ties, negative scores and other lobby sizes',()=>{assert.deepEqual(performance([6,5,4,3,2,1]),[100,90,80,70,60,50]);assert.deepEqual(performance([6,6,4,3,2,1]),[95,95,80,70,60,50]);assert.deepEqual(performance([-1,-1,-1,-1,-1,-1]),[75,75,75,75,75,75]);for(let n=2;n<=10;n++){const a=performance(Array.from({length:n},(_,i)=>-i));assert.equal(a[0],100);assert.equal(a[n-1],50);}});
test('team Elo uses match outcome, keeps Elo floor 1 without an upper cap, and rewards upsets',()=>{assert.equal(elo(500,500,500,1),516);assert.equal(elo(500,500,500,0),484);assert.equal(elo(500,500,700,1),524);assert.equal(elo(500,500,700,0),492);assert.equal(elo(1,1,1,0),1);assert.equal(elo(3200,3200,3200,1),3216);assert.equal(elo(500,500,500,.5),500);});

test("Angel is rank level 21 and fresh accounts are Forgebound I",()=>{assert.equal(rank(3220).league,"Angel");assert.equal(rank(3220).number,21);assert.equal(rank(1).league,"Forgebound I");assert.equal(elo(3220,3220,3220,1),3236);});

const sample=(elo,matches,rating,kills=10,deaths=5)=>({elo,matches,player_rating:rating,wins:1,losses:0,draws:0,kills,deaths,assists:2,flags_captured:0,flags_stopped:0});
test('service record weights played playlist Elo by completed matches, totals combat and excludes unrated percentages',()=>{
 const a=serviceCard([sample(100,3,90,30,10),sample(500,8,80,10,10),sample(900,1,null,2,1),sample(1,0,null,0,0),sample(1,0,null,0,0)]);
 assert.equal(a.elo,433);assert.equal(a.player_rating,85);assert.equal(a.playlists_played,3);assert.equal(a.playlists_rated,2);assert.equal(a.kills,42);assert.equal(a.deaths,21);assert.equal(a.kd,2);assert.equal(a.matches,12);
});
test('fresh service record has no fabricated rating and starts Forgebound I',()=>{
 const a=serviceCard(Array.from({length:5},()=>sample(1,0,null,0,0)));assert.equal(a.elo,1);assert.equal(a.league,'Forgebound I');assert.equal(a.player_rating,null);assert.equal(a.has_record,false);assert.equal(a.kd,null);
});
test('service display derives rank from average Elo while the configurable all-playlist option includes untouched records',()=>{
 const cards=[sample(3220,3,92),sample(1,0,null)];assert.equal(serviceCard(cards).league,'Angel');assert.equal(serviceCard(cards,true).elo,2415);assert.equal(serviceCard(cards,true).averaging,'match_weighted_all_playlists');
});

test('grade bands handle boundaries, rounded percentages and hidden ratings',()=>{
 assert.equal(ratingGrade(null),null);assert.equal(ratingGrade(92),'A−');assert.equal(ratingGrade(93),'A');assert.equal(ratingGrade(97),'A+');assert.equal(ratingGrade(59),'F');assert.equal(ratingGrade(60),'D−');
});
test('first new playlist game no longer halves a veteran service average',()=>{const a=serviceCard([sample(3220,100,92),sample(1,1,null)]);assert.equal(a.elo,3188);assert.equal(a.player_rating,92);});
