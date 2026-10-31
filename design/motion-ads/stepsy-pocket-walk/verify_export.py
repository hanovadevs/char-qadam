"""Decode the delivered MP4 and measure its audio, not only the HTML source."""
import argparse
import json
import re
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('video', type=Path)
parser.add_argument('--ffmpeg', default='ffmpeg')
parser.add_argument('--report', type=Path)
args = parser.parse_args()
result = subprocess.run([
    args.ffmpeg, '-hide_banner', '-nostdin', '-i', str(args.video),
    '-af', 'loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json',
    '-f', 'null', '-'
], capture_output=True, text=True)
if result.returncode:
    raise RuntimeError(result.stderr[-3000:])
metadata = result.stderr.split('Stream mapping:')[0]
match = re.search(r'Duration: (\d+):(\d+):([\d.]+)', metadata)
if not match:
    raise RuntimeError('Missing media duration')
duration = int(match[1])*3600 + int(match[2])*60 + float(match[3])
frames = int(re.findall(r'frame=\s*(\d+)', result.stderr)[-1])
audio = json.loads(re.search(r'\{\s*"input_i".*?\}', result.stderr, re.S)[0])
assert '1080x1920' in metadata and 'h264' in metadata and 'yuv420p' in metadata
assert '48000 Hz, stereo' in metadata and '60 fps' in metadata
assert abs(duration-20.625) < .06 and abs(frames-round(20.625*60)) <= 1
assert float(audio['input_tp']) < -1 and -21 < float(audio['input_i']) < -13
report = {
    'file': str(args.video.resolve()), 'bytes': args.video.stat().st_size,
    'duration_seconds': duration, 'decoded_frames': frames,
    'video': 'H.264, yuv420p, 1080x1920, 60 fps',
    'audio': 'AAC, 48000 Hz, stereo',
    'integrated_lufs': float(audio['input_i']), 'true_peak_dbtp': float(audio['input_tp']),
    'full_decode': 'passed'
}
if args.report:
    args.report.write_text(json.dumps(report, indent=2), encoding='utf8')
print(json.dumps(report))
