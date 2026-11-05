package com.oanarinaldi.wakemeup;
import android.app.*;import android.content.*;
public class AlarmReceiver extends BroadcastReceiver {
 public void onReceive(Context c,Intent in){String id=in.getStringExtra("id");if(id==null)return;AlarmScheduler.channels(c);
  if(id.equals("bedtime")){PendingIntent open=PendingIntent.getActivity(c,0,new Intent(c,MainActivity.class),PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT);c.getSystemService(NotificationManager.class).notify(200,new Notification.Builder(c,"bedtime").setSmallIcon(android.R.drawable.ic_lock_idle_alarm).setContentTitle("Make room for morning").setContentText("A quiet moment to wind down. Your sunrise is waiting.").setContentIntent(open).setAutoCancel(true).build());AlarmScheduler.refresh(c);return;}
  if("cancelSnooze".equals(in.getStringExtra("action"))){AlarmScheduler.dismissSnooze(c,id);AlarmScheduler.cancel(c,id);AlarmScheduler.refresh(c);return;}
  if("stop".equals(in.getStringExtra("action"))){RingService.stop(c);return;}
  if("snooze".equals(in.getStringExtra("action"))){RingService.snooze(c,id);return;}
  AlarmScheduler.dismissSnooze(c,id);WakeData.pending(c,id);c.startForegroundService(new Intent(c,RingService.class).putExtra("id",id));AlarmScheduler.refresh(c);
 }
}
