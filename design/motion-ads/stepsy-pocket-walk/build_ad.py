"""Pack user-owned brand artwork and selected supplied footage into one HTML file."""
import base64
import json
import sys
import argparse
from PIL import Image
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
CACHE = ROOT / 'mobile/build/stepsy-ad-cache'
OUTPUT = ROOT / 'artifacts/stepsy-motion-ad'
parser = argparse.ArgumentParser()
parser.add_argument('--composition', default='composition.js')
parser.add_argument('--name', default='Stepsy-ad-editable.html')
parser.add_argument('--logo', default='mobile/assets/icon/Stepsy_Icon1.png')
args = parser.parse_args()
sys.path.insert(0, str(ROOT / 'mobile/build/stepsy-ad-tools/python'))
from fontTools.ttLib import TTFont

def data_url(path, mime):
    return f'data:{mime};base64,' + base64.b64encode(path.read_bytes()).decode()

font = TTFont(ROOT / 'mobile/assets/fonts/Nunito.ttf')
font.flavor = 'woff2'
font_path = CACHE / 'Nunito.woff2'
font.save(font_path)
images = {
    'logo': ROOT / args.logo,
    'welcome': ROOT / 'mobile/assets/companion/portraits/welcome.png',
    'wave': ROOT / 'mobile/assets/companion/animations/wave.png',
    'walk': ROOT / 'mobile/assets/companion/animations/walk.png',
    'rest': ROOT / 'mobile/assets/companion/static/rest.png',
    'trail': ROOT / 'mobile/assets/illustrations/cozy-walking-track.png',
}
assets = {k: data_url(v, 'image/png') for k, v in images.items()}
with Image.open(images['logo']) as logo:
    # Ignore imperceptible alpha=1 specks when framing the visible mark.
    mask = logo.getchannel('A').point(lambda alpha: 255 if alpha > 1 else 0) if logo.mode == 'RGBA' else logo
    left, top, right, bottom = mask.getbbox()
    logo_bounds = [left, top, right-left, bottom-top]
assets['walkingFrames'] = [data_url(p, 'image/jpeg') for p in sorted((CACHE / 'Walk').glob('frame-*.jpg'))]
assets['joggingFrames'] = [data_url(p, 'image/jpeg') for p in sorted((CACHE / 'jogging').glob('frame-*.jpg'))]
if not assets['walkingFrames'] or not assets['joggingFrames']:
    raise RuntimeError('Prepare clip frames before building the composition')
font_url = data_url(font_path, 'font/woff2')
html = '''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Stepsy — Qadam aapke. Faida bhi aapka.</title>
<style>
@font-face{font-family:Nunito;src:url("__FONT__") format("woff2");font-weight:200 1000;font-display:block}
*{box-sizing:border-box}body{margin:0;background:#e8ecdf;color:#264a3a;font-family:Nunito,sans-serif;display:flex;flex-direction:column;align-items:center;min-height:100vh;padding:16px;gap:12px}
canvas{width:auto;height:calc(100vh - 100px);max-width:100%;aspect-ratio:9/16;border-radius:16px;box-shadow:0 8px 40px #264a3a20}
nav{display:flex;align-items:center;gap:12px;width:min(560px,95vw)}button{border:0;border-radius:30px;background:#4f6a4d;color:#fffbf3;font:800 15px Nunito;padding:10px 20px;cursor:pointer}input{flex:1;accent-color:#4f6a4d}output{font-variant-numeric:tabular-nums;font-weight:700;min-width:4em}
.render{margin:0;padding:0;display:block;overflow:hidden;background:#fef8ec}.render canvas{position:absolute;left:0;top:0;width:1080px;height:1920px;max-width:none;border-radius:0;box-shadow:none}.render nav{display:none}
</style><canvas id="stage" width="1080" height="1920" aria-label="Stepsy walking rewards demonstration"></canvas>
<nav><button id="play">Play</button><input id="scrub" type="range" min="0" max="30" step=".01" value="0" aria-label="Video position"><output id="time">0:00</output></nav>
<script>const ASSETS=__ASSETS__;const LOGO_BOUNDS=__BOUNDS__;</script><script>__SCRIPT__</script></html>'''
html = html.replace('__FONT__', font_url).replace('__ASSETS__', json.dumps(assets, separators=(',', ':'))).replace('__BOUNDS__', json.dumps(logo_bounds)).replace('__SCRIPT__', (HERE / args.composition).read_text(encoding='utf8'))
OUTPUT.mkdir(parents=True, exist_ok=True)
out = OUTPUT / args.name
out.write_text(html, encoding='utf8')
print(json.dumps({'html': str(out), 'bytes': out.stat().st_size, 'walking_frames': len(assets['walkingFrames']), 'jogging_frames': len(assets['joggingFrames'])}))
