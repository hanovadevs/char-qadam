"""Pack the rendered masters for Flutter's explicit drawImageRect renderer."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'design/stepsy-companion/renders'
assets=ROOT/'design/stepsy-companion/legacy-assets'
(assets/'animations').mkdir(parents=True,exist_ok=True); (assets/'static').mkdir(exist_ok=True)
manifest={'version':1,'authoring':'Blender 5.2.1 cutouts','runtimeFrameSize':[128,128],
          'masterFrameSize':[256,256],'footAnchor':[128,223],'cropOffset':[0,0],'clips':{}}
folders=sorted(p for p in source.iterdir() if p.is_dir())
sheet=Image.new('RGB',(768,((len(folders)+2)//3)*256),'#FAFBF8'); draw=ImageDraw.Draw(sheet)
for ci,folder in enumerate(folders):
    paths=sorted(folder.glob('*.png')); clip=folder.name
    atlas=Image.new('RGBA',(768,512))
    for index,path in enumerate(paths):
        frame=Image.open(path).convert('RGBA'); assert frame.getbbox() is not None
        assert frame.getbbox()[0]>0 and frame.getbbox()[1]>0 and frame.getbbox()[2]<256 and frame.getbbox()[3]<256, (clip,index,'clipped')
        thumb=frame.resize((128,128),Image.Resampling.LANCZOS)
        atlas.paste(thumb,((index%6)*128,(index//6)*128))
    pose=Image.open(paths[len(paths)//2]).convert('RGBA')
    sheet.paste(pose,((ci%3)*256,(ci//3)*256),pose)
    draw.text(((ci%3)*256+12,(ci//3)*256+232),clip,fill='#102B32')
    if clip=='rest':
        pose.resize((128,128),Image.Resampling.LANCZOS).save(assets/'static/rest.png',optimize=True)
    else: atlas.save(assets/'animations'/f'{clip}.png',optimize=True)
    manifest['clips'][clip]={'frames':len(paths),'fps':24,'loop':clip=='walk','columns':6,
        'source':[str(p.relative_to(ROOT)).replace('\\','/') for p in paths],
        'atlas':f'assets/companion/animations/{clip}.png' if clip!='rest' else None,
        'canvas':[256,256],'bounds':list(pose.getbbox()),'anchor':[128,223],
        'fallback':'assets/companion/static/rest.png','decodedBytes':768*512*4 if clip!='rest' else 128*128*4}
(assets/'manifest.json').write_text(json.dumps(manifest,indent=2))
sheet.save(ROOT/'design/stepsy-companion/contact-sheet.png')
size=sum(p.stat().st_size for p in assets.rglob('*') if p.is_file())
print('Runtime asset bytes:',size,'; maximum decoded clip bytes:',768*512*4)
