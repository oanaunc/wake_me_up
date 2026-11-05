(function(root){
'use strict';
const uid=()=>globalThis.crypto?.randomUUID?.()||'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g,c=>{let n=Math.random()*16|0;return(c==='x'?n:(n&3|8)).toString(16)});
const day=d=>{let x=new Date(d);x.setHours(0,0,0,0);return x.getTime()};
const localDate=d=>{let x=new Date(d);return `${x.getFullYear()}-${String(x.getMonth()+1).padStart(2,'0')}-${String(x.getDate()).padStart(2,'0')}`};
const step=id=>{let m=MISSIONS.find(x=>x.id===id)||MISSIONS[2];return{mission:m.id,target:m.target,difficulty:1,intention:'Today I will start small.',destinationID:null}};
const alarm=()=>({id:uid(),hour:7,minute:0,label:'My morning',weekdays:[1,2,3,4,5],route:[step('dance')],scheduleMode:'weekly',datedAt:Date.now()+86400000,cycleStart:day(Date.now()),workDays:2,restDays:2,skippedDates:[],pausedUntil:null,nextOverride:null,snoozeMinutes:0,wakeCheckMinutes:0,tone:'FirstLight',gentleSound:false,enabled:true,isNap:false});
function nextFire(a,after=Date.now()){
 if(!a.enabled)return null;
 if(a.nextOverride>after&&a.nextOverride>=(a.pausedUntil||0))return a.nextOverride;
 if(a.scheduleMode==='dated')return a.datedAt>after&&a.datedAt>=(a.pausedUntil||0)?a.datedAt:null;
 let lower=Math.max(after,a.pausedUntil||0),cursor=new Date(day(lower));
 for(let i=0;i<740;i++){
  let c=new Date(cursor);c.setHours(a.hour,a.minute,0,0);
  let off=Math.round((Date.UTC(c.getFullYear(),c.getMonth(),c.getDate())-(()=>{let s=new Date(a.cycleStart);return Date.UTC(s.getFullYear(),s.getMonth(),s.getDate())})())/86400000);
  let match=a.scheduleMode==='rotation'?off>=0&&off%Math.max(1,a.workDays+a.restDays)<a.workDays:!a.weekdays.length||a.weekdays.includes(c.getDay());
  if(c>after&&c>=lower&&match&&!a.skippedDates.includes(localDate(c))&&(!a.nextOverride||localDate(c)!==localDate(a.nextOverride)))return+c;
  cursor.setDate(cursor.getDate()+1);
 }
 return null;
}
function occurrences(a,after=Date.now(),count=14){let out=[],at=after;for(let i=0;i<count;i++){let next=nextFire(a,at);if(!next)break;out.push(next);at=next;if(a.scheduleMode==='dated'||a.scheduleMode==='weekly'&&!a.weekdays.length)break}return out}
function streak(records,now=Date.now()){let days=new Set(records.map(x=>localDate(x.date)));let c=new Date(day(now));if(!days.has(localDate(c)))c.setDate(c.getDate()-1);let n=0;while(days.has(localDate(c))){n++;c.setDate(c.getDate()-1)}return n}
const normalize=x=>x.normalize('NFD').replace(/\p{Diacritic}/gu,'').toLowerCase().replace(/[^\p{L}\p{N}]/gu,'');
const blank=()=>({welcomed:false,alarms:[],sunrises:[],presets:[],destinations:[],importedTones:[],wakeChecks:[],soundEnabled:true,ritualVolume:.55,hideStreak:false,sleepGoalHours:8,bedtimeEnabled:false,bedtimeHour:22,bedtimeMinute:0,session:null});
const api={uid,day,localDate,step,alarm,nextFire,occurrences,streak,normalize,blank};root.Core=api;if(typeof module!=='undefined')module.exports=api;
})(globalThis);
