package com.oanarinaldi.wakemeup;
import org.json.*;
import java.time.*;
import java.util.*;
/** Calendar-local dates preserve the chosen wall clock through DST and timezone changes. */
public final class AlarmMath {
 public static long next(JSONObject a,long after,ZoneId zone){
  if(!a.optBoolean("enabled"))return 0;
  long pause=a.optLong("pausedUntil",0),override=a.optLong("nextOverride",0);
  if(override>after&&override>=pause)return override;
  String mode=a.optString("scheduleMode","weekly");
  if(mode.equals("dated")){long at=a.optLong("datedAt");return at>after&&at>=pause?at:0;}
  LocalDate day=Instant.ofEpochMilli(Math.max(after,pause)).atZone(zone).toLocalDate();
  LocalDate start=Instant.ofEpochMilli(a.optLong("cycleStart",after)).atZone(zone).toLocalDate();
  Set<String> skips=new HashSet<>();JSONArray skipped=a.optJSONArray("skippedDates");if(skipped!=null)for(int i=0;i<skipped.length();i++)skips.add(skipped.optString(i));
  JSONArray weekdays=a.optJSONArray("weekdays");
  for(int i=0;i<740;i++,day=day.plusDays(1)){
   long at=day.atTime(Math.max(0,Math.min(23,a.optInt("hour",7))),Math.max(0,Math.min(59,a.optInt("minute")))).atZone(zone).toInstant().toEpochMilli();
   boolean match=false;
   if(mode.equals("rotation")){long offset=java.time.temporal.ChronoUnit.DAYS.between(start,day);int work=Math.max(1,a.optInt("workDays",2)),rest=Math.max(1,a.optInt("restDays",2));match=offset>=0&&offset%(work+rest)<work;}
   else{match=weekdays==null||weekdays.length()==0;int wd=day.getDayOfWeek().getValue()%7;if(weekdays!=null)for(int k=0;k<weekdays.length();k++)match|=weekdays.optInt(k)==wd;}
   if(at>after&&at>=pause&&match&&!skips.contains(day.toString())&&(override==0||!day.equals(Instant.ofEpochMilli(override).atZone(zone).toLocalDate())))return at;
  }return 0;
 }
}
