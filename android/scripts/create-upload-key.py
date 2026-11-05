#!/usr/bin/env python3
"""Create and preserve an app-specific Play upload key outside the repository."""
import pathlib,secrets,os,json,subprocess
folder=pathlib.Path.home()/'.local/share/wake-me-up/android-upload'
folder.mkdir(parents=True,exist_ok=True,mode=0o700)
config=folder/'signing.json'; key=folder/'upload.keystore'
if config.exists() or key.exists():raise SystemExit('Upload key already exists; preserve it.')
password=secrets.token_urlsafe(32)
env=dict(os.environ,WAKE_NEW_KEY_PASSWORD=password)
jdk=pathlib.Path('/Applications/Android Studio.app/Contents/jbr/Contents/Home')
subprocess.run([str(jdk/'bin/keytool'),'-genkeypair','-keystore',str(key),'-alias','upload','-keyalg','RSA','-keysize','3072','-validity','10000','-storepass:env','WAKE_NEW_KEY_PASSWORD','-keypass:env','WAKE_NEW_KEY_PASSWORD','-dname','CN=Wake Me Up, O=Oana Rinaldi, C=RO'],env=env,check=True)
key.chmod(0o600)
with config.open('x') as f:json.dump(dict(keystore=str(key),storePassword=password,keyPassword=password,alias='upload'),f)
config.chmod(0o600)
print('Created private upload key outside Git. Preserve this folder for future updates.')
