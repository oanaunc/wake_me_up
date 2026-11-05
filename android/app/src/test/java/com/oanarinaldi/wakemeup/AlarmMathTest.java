package com.oanarinaldi.wakemeup;
import org.junit.Test;import static org.junit.Assert.*;import java.time.*;import org.json.*;
public class AlarmMathTest {
 ZoneId zone=ZoneId.of("Europe/Bucharest");long time(String s){return ZonedDateTime.parse(s).toInstant().toEpochMilli();}
 JSONObject alarm()throws Exception{return new JSONObject("{enabled:true,hour:7,minute:0,scheduleMode:'weekly',weekdays:[1,2,3,4,5]}");}
 @Test public void fridayAfterAlarmRollsToMonday()throws Exception{assertEquals(time("2026-11-09T07:00+02:00"),AlarmMath.next(alarm(),time("2026-11-06T08:00+02:00"),zone));}
 @Test public void disabledNeverFires()throws Exception{assertEquals(0,AlarmMath.next(alarm().put("enabled",false),0,zone));}
 @Test public void dateExpires()throws Exception{JSONObject a=alarm().put("scheduleMode","dated").put("datedAt",1000);assertEquals(1000,AlarmMath.next(a,999,zone));assertEquals(0,AlarmMath.next(a,1000,zone));}
 @Test public void exceptionsAndOverride()throws Exception{JSONObject a=alarm().put("skippedDates",new JSONArray("['2026-11-05']")).put("nextOverride",time("2026-11-06T06:00+02:00"));long fire=AlarmMath.next(a,time("2026-11-05T00:00+02:00"),zone);assertEquals(time("2026-11-06T06:00+02:00"),fire);assertEquals(time("2026-11-09T07:00+02:00"),AlarmMath.next(a,fire,zone));}
 @Test public void rotationPause()throws Exception{JSONObject a=alarm().put("scheduleMode","rotation").put("cycleStart",time("2026-11-01T00:00+02:00")).put("workDays",2).put("restDays",2).put("pausedUntil",time("2026-11-03T00:00+02:00"));assertEquals(time("2026-11-05T07:00+02:00"),AlarmMath.next(a,time("2026-11-01T00:00+02:00"),zone));}
 @Test public void dstSpringUsesLocalTime()throws Exception{JSONObject a=alarm().put("weekdays",new JSONArray("[0]"));assertEquals(time("2026-03-29T07:00+03:00"),AlarmMath.next(a,time("2026-03-28T08:00+02:00"),zone));}
 @Test public void dstAutumnUsesLocalTime()throws Exception{JSONObject a=alarm().put("weekdays",new JSONArray("[0]"));assertEquals(time("2026-10-25T07:00+02:00"),AlarmMath.next(a,time("2026-10-24T08:00+03:00"),zone));}
 @Test public void signaturesRejectUnsignedPurchases(){assertFalse(PlayBilling.verify("{}","",""));}
}
