#!/usr/bin/env python3
"""Create the persistent Android release key once; never commit its files."""
import os
from pathlib import Path
import secrets
import subprocess

ROOT = Path(__file__).resolve().parents[1]
KEYSTORE = ROOT / 'android/app/amaranto-feed-release.jks'
PROPERTIES = ROOT / 'android/key.properties'
if KEYSTORE.exists() or PROPERTIES.exists():
    raise SystemExit('Signing files already exist; reuse them. Nothing was overwritten.')

os.umask(0o077)
password = secrets.token_urlsafe(32)
environment = dict(os.environ, AMARANTO_STORE_PASSWORD=password)
subprocess.run([
    'keytool', '-genkeypair', '-v', '-keystore', str(KEYSTORE),
    '-storetype', 'PKCS12', '-storepass:env', 'AMARANTO_STORE_PASSWORD',
    '-keypass:env', 'AMARANTO_STORE_PASSWORD', '-alias', 'amaranto-feed',
    '-keyalg', 'RSA', '-keysize', '3072', '-validity', '10000',
    '-dname', 'CN=Amaranto Feed, O=Davide Ferrara, C=IT',
], env=environment, check=True)
PROPERTIES.write_text(
    f'storePassword={password}\nkeyPassword={password}\n'
    'keyAlias=amaranto-feed\nstoreFile=amaranto-feed-release.jks\n'
)
KEYSTORE.chmod(0o600)
PROPERTIES.chmod(0o600)
print('Created ignored Android signing files. Back up the keystore and key.properties securely.')
