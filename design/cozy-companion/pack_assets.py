"""Validate and pack Blender renders; only atlases/static PNGs ship in Flutter."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
SOURCE=Path(__file__).resolve().parent
CLIPS=['rest','walk','wave','point','cheer','ready','wait','reassure','idle','wiggle','love','gift','peek']
FRAME=192
FRAMES=60
ASSETS=ROOT/'mobile/assets/companion'


def pack():
    # Validate the entire set before replacing any live asset.
    frames={}
    for clip in CLIPS:
        paths=sorted((SOURCE/'renders'/clip).glob('*.png'))
        assert len(paths)==(1 if clip=='rest' else FRAMES),(clip,'missing frames',len(paths))
        frames[clip]=[]
        for path in paths:
            with Image.open(path) as image:
                frame=image.convert('RGBA')
            assert frame.size==(384,384),(clip,'wrong dimensions')
            bounds=frame.getchannel('A').getbbox()
            assert bounds and min(bounds[:2])>2 and max(bounds[2:])<382,(clip,path,'clipped',bounds)
            frames[clip].append(frame)
    manifest=dict(version=3,authoring='Blender 5.2.1 continuous skinned cloth',
                  character='Cozy walking companion',runtimeFrameSize=[FRAME,FRAME],
                  masterFrameSize=[384,384],columns=6,rows=10,cropOffset=[0,0],
                  footAnchor=[192,350],clips={})
    sheet=Image.new('RGB',(1000,5*290),'#FFF4E4')
    draw=ImageDraw.Draw(sheet)
    total=0
    for i,clip in enumerate(CLIPS):
        atlas=Image.new('RGBA',(6*FRAME,10*FRAME))
        for n,frame in enumerate(frames[clip]):
            thumb=frame.resize((FRAME,FRAME),Image.Resampling.LANCZOS)
            atlas.paste(thumb,((n%6)*FRAME,(n//6)*FRAME))
        path=ASSETS/('static/rest.png' if clip=='rest' else f'animations/{clip}.png')
        path.parent.mkdir(parents=True,exist_ok=True)
        (thumb if clip=='rest' else atlas).save(path,optimize=True)
        total+=path.stat().st_size
        pose=frames[clip][len(frames[clip])//2]
        preview=pose.resize((270,270),Image.Resampling.LANCZOS)
        sheet.paste(preview,((i%3)*333+30,(i//3)*290),preview)
        draw.text(((i%3)*333+135,(i//3)*290+270),clip,fill='#3F352C')
        manifest['clips'][clip]=dict(frames=len(frames[clip]),fps=50 if clip=='walk' else 24,loop=clip=='walk',
            columns=6,atlas=None if clip=='rest' else f'assets/companion/animations/{clip}.png',
            canvas=[384,384],bounds=list(pose.getchannel('A').getbbox()),anchor=[192,350],
            fallback='assets/companion/static/rest.png',
            decodedBytes=FRAME*FRAME*4*(1 if clip=='rest' else FRAMES),
            sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    (ASSETS/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    sheet.save(SOURCE/'contact-sheet.png')
    print(f'Runtime PNG bytes: {total}; max decoded atlas: {FRAME*FRAME*FRAMES*4}')


if __name__=='__main__': pack()
