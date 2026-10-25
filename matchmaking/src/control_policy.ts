import defaults from "../../game/data/network_defaults.json";
export const CONTROL=Object.freeze(defaults);
export function retryDelay(attempt:number,random=.5,retryAfter=0):number {
 return Math.max(retryAfter,Math.min(CONTROL.retry_cap_seconds,2**Math.min(8,Math.max(0,attempt)))*(.5+.5*Math.max(0,Math.min(1,random))));
}
export function retryAfter(value:string|null,time=Date.now()):number {
 if(!value)return 0;
 const seconds=Number(value);
 return Number.isFinite(seconds)?Math.max(0,seconds):Math.max(0,(Date.parse(value)-time)/1000)||0;
}
export function hostAvailable(received:number,time:number):boolean {
 return Number.isFinite(received)&&received>0&&time-received<CONTROL.host_stale_seconds;
}
export function validHostUpdate(update:{epoch?:number;revision?:number},epoch:number,revision:number):boolean {
 return update.epoch===epoch&&Number.isSafeInteger(update.revision)&&update.revision!>revision;
}
export function nextAlarm(time:number,deadlines:number[]):number {
 return Math.max(time+.1,Math.min(time+30,...deadlines.filter(d=>Number.isFinite(d)&&d>time)));
}
