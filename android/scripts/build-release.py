#!/usr/bin/env python3
"""Build signed release artifacts; fail closed if Play licensing key is unconfigured."""
import pathlib,os,subprocess,json,hashlib,shutil,sys
root=pathlib.Path(__file__).resolve().parents[2];project=root/'android'
subprocess.run(['node',str(project/'tests/core.cjs')],check=True)
c=json.loads(pathlib.Path(os.environ.get('WAKE_SIGNING_CONFIG',str(pathlib.Path.home()/'.local/share/wake-me-up/android-upload/signing.json'))).read_text())
env=dict(os.environ)
for field,var in [('keystore','WAKE_KEYSTORE'),('storePassword','WAKE_STORE_PASSWORD'),('keyPassword','WAKE_KEY_PASSWORD')]:env[var]=c[field]
env['WAKE_PLAY_PUBLIC_KEY']=c.get('playPublicKey','')
candidate='--candidate' in sys.argv
if not env['WAKE_PLAY_PUBLIC_KEY'] and not candidate:raise SystemExit('Add this app’s Play licensing public key before a submission build. --candidate produces a clearly marked preview.')
env.setdefault('JAVA_HOME','/Applications/Android Studio.app/Contents/jbr/Contents/Home');env.setdefault('ANDROID_HOME',str(pathlib.Path.home()/'Library/Android/sdk'))
subprocess.run([str(project/'gradlew'),'-p',str(project),':app:testDebugUnitTest',':app:lintRelease',':app:assembleRelease',':app:bundleRelease'],env=env,check=True)
folder=root/'output/android/release';folder.mkdir(exist_ok=True,parents=True)
suffix='-candidate' if candidate else ''
for source,ext in [('app/build/outputs/bundle/release/app-release.aab','aab'),('app/build/outputs/apk/release/app-release.apk','apk')]:shutil.copyfile(project/source,folder/f'WakeMeUp-1.0-1{suffix}.{ext}')
aab=project/'app/build/outputs/bundle/release/app-release.aab'
report=dict(package='com.oanarinaldi.wakemeup',versionName='1.0',versionCode=1,sha256=hashlib.sha256(aab.read_bytes()).hexdigest(),bytes=aab.stat().st_size,billingPublicKeyConfigured=bool(env['WAKE_PLAY_PUBLIC_KEY']),candidateOnly=candidate)
(folder/'build-info.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
