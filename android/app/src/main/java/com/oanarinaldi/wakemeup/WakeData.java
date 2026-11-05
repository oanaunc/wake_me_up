package com.oanarinaldi.wakemeup;
import android.content.*;
import org.json.*;
public final class WakeData {
 static synchronized JSONObject read(Context c){try{return new JSONObject(c.getSharedPreferences("wake",0).getString("state","{}"));}catch(Exception e){return new JSONObject();}}
 static synchronized void write(Context c,JSONObject o){if(!c.getSharedPreferences("wake",0).edit().putString("state",o.toString()).commit())throw new IllegalStateException("Your morning could not be saved. Free some device storage and try again.");}
 static JSONObject find(Context c,String id){JSONArray a=read(c).optJSONArray("alarms");if(a!=null)for(int i=0;i<a.length();i++)if(id.equals(a.optJSONObject(i).optString("id")))return a.optJSONObject(i);return null;}
 static void put(JSONObject o,String k,Object v){try{o.put(k,v);}catch(JSONException e){throw new IllegalArgumentException(e);}}
 static String pending(Context c){return c.getSharedPreferences("wake",0).getString("pending","");}
 static void pending(Context c,String id){c.getSharedPreferences("wake",0).edit().putString("pending",id).commit();}
}
