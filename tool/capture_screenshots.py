#!/usr/bin/env python3
"""Refresh README screenshots from the running app, without editing the images.

Usage: ANDROID_SERIAL=emulator-5554 python tool/capture_screenshots.py
Requires ADB and an already installed, running Amaranto Feed app.
"""
import os
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ADB = os.environ.get('ADB', '/home/dff/Android/Sdk/platform-tools/adb')
COMMAND = [ADB, '-s', os.environ.get('ANDROID_SERIAL', 'emulator-5554')]
OUTPUT = ROOT / 'docs/screenshots'


def adb(*args):
    return subprocess.check_output(COMMAND + list(args))


def tap_tab(label):
    adb('shell', 'uiautomator', 'dump', '/sdcard/amaranto-ui.xml')
    tree = ET.fromstring(adb('exec-out', 'cat', '/sdcard/amaranto-ui.xml'))
    matches = []
    for node in tree.iter('node'):
        labels = [node.get('text', '')] + node.get('content-desc', '').splitlines()
        if label in labels and node.get('clickable') == 'true':
            x1, y1, x2, y2 = map(int, re.findall(r'\d+', node.get('bounds')))
            matches.append(((y1 + y2) // 2, (x1 + x2) // 2))
    if not matches:
        raise RuntimeError(f'Navigation tab not found: {label}')
    y, x = max(matches)
    adb('shell', 'input', 'tap', str(x), str(y))
    time.sleep(1)


size = adb('shell', 'wm', 'size').decode()
width, height = map(int, re.findall(r'(\d+)x(\d+)', size)[-1])
OUTPUT.mkdir(parents=True, exist_ok=True)
for label, filename in [
    ('Chat', 'chat'), ('Calendario', 'calendar'), ('Feed', 'feed'),
    ('Classifica', 'standings'), ('Profilo', 'profile'),
]:
    tap_tab(label)
    if label != 'Chat':
        # Return each scrollable tab to its beginning, even after manual review.
        for _ in range(5):
            adb('shell', 'input', 'swipe', str(width // 2), str(height // 4),
                str(width // 2), str(height * 3 // 4), '180')
        time.sleep(3)
    path = OUTPUT / f'{filename}.png'
    path.write_bytes(adb('exec-out', 'screencap', '-p'))
    print(f'Captured {label}: {path.relative_to(ROOT)}', flush=True)

tap_tab('Feed')
