import {test} from 'node:test';
import assert from 'node:assert/strict';
import {CONTROL,hostAvailable,validHostUpdate,nextAlarm,retryDelay,retryAfter} from '../dist/control_policy.js';
test('central defaults keep gameplay independent from discovery timers',()=>{
 assert.deepEqual([CONTROL.host_heartbeat_seconds,CONTROL.host_stale_seconds,CONTROL.browser_refresh_seconds,CONTROL.queue_fallback_seconds,CONTROL.request_timeout_seconds,CONTROL.retry_cap_seconds],[20,60,15,5,10,30]);
 assert.deepEqual([CONTROL.simulation_hz,CONTROL.input_hz,CONTROL.snapshot_min_hz,CONTROL.snapshot_max_hz],[60,60,20,30]);
});
test('fake clock: host availability is filtered at sixty seconds before cleanup',()=>{
 assert(hostAvailable(100,159.999));assert(!hostAvailable(100,160));assert(!hostAvailable(0,1));
 assert(hostAvailable(159,160),'New receipt cannot be removed by an older stale observation');
});
test('old epochs and duplicate/out-of-order host revisions cannot update state',()=>{
 assert(validHostUpdate({epoch:3,revision:8},3,7));
 for(const update of [{epoch:2,revision:999},{epoch:3,revision:7},{epoch:3,revision:6},{epoch:3,revision:Infinity}])assert(!validHostUpdate(update,3,7));
});
test('retry backoff is bounded, jittered and honors seconds and HTTP-date Retry-After',()=>{
 for(let i=0;i<30;i++){assert(retryDelay(i,0)<=30);assert(retryDelay(i,1)<=30);assert(retryDelay(i,0)<=retryDelay(i,1));}
 assert.equal(retryDelay(20,1),30);assert.equal(retryDelay(2,0,120),120);
 assert.equal(retryAfter('12',0),12);assert.equal(retryAfter('Thu, 01 Jan 1970 00:01:00 GMT',0),60);assert.equal(retryAfter('invalid',0),0);
});
test('idle cleanup uses deadlines, not a perpetual one-second alarm',()=>{
 assert.equal(nextAlarm(100,[]),130);assert.equal(nextAlarm(100,[105,160]),105);assert.equal(nextAlarm(100,[99,NaN,Infinity]),130);
});
