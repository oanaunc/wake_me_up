package com.oanarinaldi.wakemeup;
import android.content.*;
public class BootReceiver extends BroadcastReceiver { public void onReceive(Context c,Intent i){if(java.util.Set.of(Intent.ACTION_BOOT_COMPLETED,Intent.ACTION_MY_PACKAGE_REPLACED,Intent.ACTION_TIME_CHANGED,Intent.ACTION_TIMEZONE_CHANGED).contains(i.getAction()==null?"":i.getAction()))AlarmScheduler.refresh(c);} }
