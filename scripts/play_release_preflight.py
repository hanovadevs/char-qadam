#!/usr/bin/env python3
"""Read-only checks for public review endpoints and an optional fresh signed AAB."""
import argparse
import concurrent.futures
import pathlib
import subprocess
import sys
import tempfile
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--api', default='https://api.stepsyapp.com')
p.add_argument('--bundle', type=pathlib.Path)
args = p.parse_args()
failures = []

def check(path):
    url = args.api.rstrip('/') + path
    try:
        with urllib.request.urlopen(url, timeout=20) as r:
            body = r.read(100000).decode('utf-8')
            if path in ('/privacy', '/delete-account'):
                assert 'text/html' in r.headers.get('Content-Type', '')
                assert 'Stepsy' in body and 'contact@hanovadevs.com' in body
            return path, None
    except Exception as e:
        return path, str(e)

if not args.api.startswith('https://'):
    p.error('A production API must use HTTPS')
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    for path, error in pool.map(check, ['/health', '/health/ready', '/privacy', '/delete-account']):
        print(('FAIL' if error else 'PASS'), path, error or '')
        if error:
            failures.append(path)

manifest = ET.parse(ROOT / 'mobile/android/app/src/main/AndroidManifest.xml')
android = '{http://schemas.android.com/apk/res/android}'
if manifest.find('application').get(android + 'usesCleartextTraffic') != 'false':
    failures.append('Cleartext traffic enabled in main manifest')

if args.bundle:
    bundle = args.bundle.resolve()
    if not bundle.is_file():
        failures.append('AAB does not exist')
    else:
        sources = [*ROOT.glob('mobile/lib/**/*.dart'), *ROOT.glob('mobile/android/app/src/main/**/*')]
        sources += [ROOT / 'mobile/pubspec.yaml', ROOT / 'mobile/pubspec.lock', ROOT / 'mobile/android/app/build.gradle.kts']
        if any(f.is_file() and f.stat().st_mtime > bundle.stat().st_mtime for f in sources):
            failures.append('AAB predates source changes: build a fresh bundle')
        with zipfile.ZipFile(bundle) as z:
            if not any(n.upper().startswith('META-INF/') and n.upper().endswith('.SF') for n in z.namelist()):
                failures.append('AAB has no signing metadata')
            with tempfile.TemporaryDirectory(prefix='stepsy-aab-') as tmp:
                for name in z.namelist():
                    if '/lib/' not in name or not name.endswith('.so'):
                        continue
                    f = pathlib.Path(tmp) / 'library.so'
                    f.write_bytes(z.read(name))
                    headers = subprocess.run(['readelf', '-lW', str(f)], capture_output=True, text=True, check=True).stdout
                    alignments = [int(line.split()[-1], 16) for line in headers.splitlines() if line.strip().startswith('LOAD ')]
                    if not alignments or min(alignments) < 16384:
                        failures.append('16 KB ELF alignment: ' + name)
        signature = subprocess.run(['jarsigner', '-verify', str(bundle)], capture_output=True, text=True)
        if signature.returncode or 'jar verified' not in signature.stdout:
            failures.append('AAB signature did not verify')
        print('Bundle inspected:', bundle)
else:
    print('AAB not supplied: signing, freshness and native alignment NOT verified.')

for issue in failures:
    print('BLOCKER:', issue)
print('Still verify Play upload certificate/version code, bundletool ZIP alignment, reviewer login, and physical-device flows.')
sys.exit(1 if failures else 0)
