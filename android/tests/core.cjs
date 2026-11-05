const assert=require('node:assert/strict');require('../app/src/main/assets/mission-data.js');const C=require('../app/src/main/assets/core.js');
const at=x=>new Date(x).getTime();let tests=0;function test(name,fn){fn();console.log('PASS '+name);tests++}
process.env.TZ='Europe/Bucharest';
test('all thirteen challenges preserve Apple content and default targets',()=>{assert.equal(MISSIONS.length,13);for(const m of MISSIONS){assert.ok(m.instructions.length>60);assert.ok(m.title&&m.subtitle&&m.countingHint);assert.equal(C.step(m.id).target,m.target)}});
test('weekday plans roll to Monday',()=>{let a=C.alarm();assert.equal(C.nextFire(a,at('2026-11-06T08:00:00+02:00')),at('2026-11-09T07:00:00+02:00'))});
test('one-shot dated alarms expire',()=>{let a=C.alarm();a.scheduleMode='dated';a.datedAt=at('2026-11-05T10:00:00+02:00');assert.equal(C.occurrences(a,at('2026-11-05T09:00:00+02:00')).length,1);assert.equal(C.nextFire(a,a.datedAt),null)});
test('work rest cycles and pause',()=>{let a=C.alarm();a.scheduleMode='rotation';a.cycleStart=at('2026-11-01T00:00:00+02:00');a.pausedUntil=at('2026-11-03T00:00:00+02:00');assert.equal(C.nextFire(a,at('2026-11-01T00:00:00+02:00')),at('2026-11-05T07:00:00+02:00'))});
test('skip and override cannot duplicate a day',()=>{let a=C.alarm();a.skippedDates=['2026-11-05'];a.nextOverride=at('2026-11-06T06:00:00+02:00');let dates=C.occurrences(a,at('2026-11-05T00:00:00+02:00'),3);assert.deepEqual(dates,[at('2026-11-06T06:00:00+02:00'),at('2026-11-09T07:00:00+02:00'),at('2026-11-10T07:00:00+02:00')])});
test('spring DST keeps wall-clock time',()=>{let a=C.alarm();a.weekdays=[];let fire=C.nextFire(a,at('2026-03-28T08:00:00+02:00'));assert.equal(fire,at('2026-03-29T07:00:00+03:00'))});
test('autumn DST keeps wall-clock time',()=>{let a=C.alarm();a.weekdays=[0];assert.equal(C.nextFire(a,at('2026-10-24T08:00:00+03:00')),at('2026-10-25T07:00:00+02:00'))});
test('streak merges multiple completions on the same date',()=>{let records=['2026-11-04T07:00:00+02:00','2026-11-04T08:00:00+02:00','2026-11-03T07:00:00+02:00'].map(x=>({date:at(x)}));assert.equal(C.streak(records,at('2026-11-05T08:00:00+02:00')),2)});
test('intentions ignore punctuation case and diacritics',()=>assert.equal(C.normalize('Today, I will start SMALL!'),C.normalize('today I will start small.')));
console.log(tests+' core tests passed');
