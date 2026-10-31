#!/usr/bin/env python3
"""Capture a cold launch for splash QA; keep reusable frames in /tmp by default.

Usage: ANDROID_SERIAL=emulator-5554 python tool/capture_launch.py [output-directory]
"""
import os
from pathlib import Path
import subprocess
import sys
import time

from PIL import Image

adb = os.environ.get('ADB', '/home/dff/Android/Sdk/platform-tools/adb')
serial = os.environ.get('ANDROID_SERIAL', 'emulator-5554')
command = [adb, '-s', serial]
output = Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/amaranto-launch')
output.mkdir(parents=True, exist_ok=True)
subprocess.run(command + ['shell', 'am', 'force-stop', 'it.davideferrara.amarantofeed'], check=True)
start = time.monotonic()
launch = subprocess.Popen(command + [
    'shell', 'am', 'start', '-W', '-n', 'it.davideferrara.amarantofeed/.MainActivity',
], stdout=subprocess.DEVNULL)
for index in range(30):
    frame = output / f'{index:02d}.png'
    with frame.open('wb') as target:
        subprocess.run(command + ['exec-out', 'screencap', '-p'], stdout=target, check=True)
    with Image.open(frame) as image:
        top = image.getpixel((5, image.height // 4))
        bottom = image.getpixel((5, image.height * 3 // 4))
    print(f'{frame}: {time.monotonic() - start:.2f}s top={top} bottom={bottom}')
launch.wait(timeout=30)
