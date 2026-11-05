#!/usr/bin/env python3
"""Copy the Apple app's complete mission copy and original artwork/audio into Android."""
import pathlib,re,json,shutil,subprocess,hashlib
root=pathlib.Path(__file__).resolve().parents[2];assets=root/'android/app/src/main/assets'
src=(root/'Sources/Models.swift').read_text();ids=['pushups','squats','dance','march','stretch','breathe','sunTaps','math','memory','words','scanCode','daylight','water'];data=[]
for id in ids:
 d={'id':id}
 for field in ['title','subtitle','instructions','countingHint']:
  section=src.split('var '+field+': String')[1].split('\n    } }')[0]
  for match in re.finditer(r'case ([^:]+):\s*"([^"]*)"',section):
   if '.'+id in match[1].split(','):d[field]=match[2].replace('On iPad, guided mode is more comfortable.','On a tablet, guided mode is more comfortable.')
 d['target']=5 if id in ['pushups','squats'] else 8 if id=='sunTaps' else 3 if id in ['math','memory'] else 1 if id in ['words','scanCode','daylight','water'] else 30
 d['unit']='reps' if id in ['pushups','squats'] else 'taps' if id=='sunTaps' else 'sums' if id=='math' else 'rounds' if id=='memory' else 'intention' if id=='words' else 'destination' if id=='scanCode' else 'action' if id in ['daylight','water'] else 'seconds'
 d['tint']='peach' if id in ['pushups','squats'] else 'lavender' if id in ['dance','sunTaps','math','memory','words'] else 'green'
 assert all(k in d for k in ['title','subtitle','instructions','countingHint']),d
 data.append(d)
(assets/'missions.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');(assets/'mission-data.js').write_text('globalThis.MISSIONS='+json.dumps(data,ensure_ascii=False)+';\n')
manifest={}
for source,destination in [('Resources/Assets.xcassets/SunriseLandscape.imageset/sunrise.png','art/sunrise.png'),('Resources/Assets.xcassets/SunMascot.imageset/sun.png','art/sun.png')]:
 shutil.copyfile(root/source,assets/destination);manifest[destination]=dict(source=source,sha256=hashlib.sha256((assets/destination).read_bytes()).hexdigest())
for p in (root/'Resources').glob('*.m4a'):
 shutil.copyfile(p,assets/p.name);manifest[p.name]=dict(source=str(p.relative_to(root)),sha256=hashlib.sha256(p.read_bytes()).hexdigest())
for p in (root/'Resources').glob('*Alarm.caf'):
 destination=assets/(p.stem+'.m4a');subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(p),'-c:a','aac','-b:a','160k',str(destination)],check=True);manifest[destination.name]=dict(source=str(p.relative_to(root)),conversion='PCM CAF to AAC at 160 kbps',sha256=hashlib.sha256(destination.read_bytes()).hexdigest())
(root/'GooglePlay/apple-asset-map.json').write_text(json.dumps(manifest,indent=2)+'\n');print('Synced 13 complete missions, two original illustrations and all six sounds and alarm clips.')
