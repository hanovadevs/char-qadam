#!/usr/bin/env bash
set -euo pipefail
# Install official Google SDK tools as the current user. Install Java first.
if ! command -v javac >/dev/null 2>&1; then
  echo 'Java is missing. Run: sudo apt install openjdk-17-jdk'
  exit 1
fi
export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
if [[ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]]; then
  python3 - "$ANDROID_HOME" <<'PY'
import hashlib, os, pathlib, shutil, sys, tempfile, urllib.request, xml.etree.ElementTree as ET, zipfile
sdk = pathlib.Path(sys.argv[1]).resolve()
sdk.mkdir(parents=True, exist_ok=True)
repository = 'https://dl.google.com/android/repository/'
with urllib.request.urlopen(repository + 'repository2-1.xml', timeout=60) as response:
    document = ET.fromstring(response.read())
package = next(p for p in document.iter('remotePackage') if p.get('path') == 'cmdline-tools;latest')
archive = next(a for a in package.findall('./archives/archive') if a.findtext('host-os') == 'linux')
complete = archive.find('complete')
url = complete.findtext('url')
if not url or '/' in url or not url.startswith('commandlinetools-linux-'):
    raise RuntimeError('Unexpected SDK archive URL')
checksum = complete.find('checksum')
print('Downloading official Google Android command-line tools…', flush=True)
with tempfile.TemporaryDirectory(prefix='stepsy-sdk-', dir=sdk) as temporary:
    temporary = pathlib.Path(temporary)
    downloaded = temporary / 'tools.zip'
    urllib.request.urlretrieve(repository + url, downloaded)
    kind = checksum.get('type', 'sha1')
    if kind not in {'sha1', 'sha256'} or hashlib.new(kind, downloaded.read_bytes()).hexdigest() != checksum.text.strip():
        raise RuntimeError('SDK archive checksum mismatch')
    extracted = temporary / 'unpacked'
    extracted.mkdir()
    with zipfile.ZipFile(downloaded) as zipped:
        for member in zipped.infolist():
            target = (extracted / member.filename).resolve()
            if not target.is_relative_to(extracted.resolve()):
                raise RuntimeError('Unsafe archive path')
            zipped.extract(member, extracted)
            if not member.is_dir(): target.chmod((member.external_attr >> 16) & 0o777 or 0o644)
    destination = sdk / 'cmdline-tools' / 'latest'
    destination.parent.mkdir(exist_ok=True)
    if destination.exists(): raise RuntimeError('SDK tools appeared during installation; retry safely')
    shutil.move(str(extracted / 'cmdline-tools'), destination)
PY
fi
manager="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
echo 'Review and accept the Android SDK licenses when prompted.'
"$manager" --sdk_root="$ANDROID_HOME" --licenses
"$manager" --sdk_root="$ANDROID_HOME" 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0'
flutter config --android-sdk "$ANDROID_HOME" --jdk-dir "$JAVA_HOME"
flutter doctor -v
flutter devices
echo 'Android toolchain installed. You can now run flutter run -d 38261FDJH00KR5'
echo 'For future shells set JAVA_HOME and add the Android platform-tools/cmdline-tools folders to PATH.'
