"""Build PMUI's small, portable, antialiased nine-slice and line-icon assets."""
from pathlib import Path
from PIL import Image, ImageDraw
import re

OUT = Path(__file__).resolve().parents[1] / 'mainmenu/lib/pmui/modern/textures'
OUT.mkdir(parents=True, exist_ok=True)
S = 4
for radius in (8, 12, 16, 24):
    size = 2 * (radius + 2) + 4
    for outline in (False, True):
        im = Image.new('RGBA', (size*S, size*S))
        draw = ImageDraw.Draw(im)
        draw.rounded_rectangle((S//2, S//2, size*S-S//2-1, size*S-S//2-1), radius*S,
                               fill=None if outline else 'white', outline='white' if outline else None, width=S)
        im.resize((size,size), Image.Resampling.LANCZOS).save(OUT / f'pmui_{"outline" if outline else "round"}_{radius}.png')
Image.new('RGBA',(2,2)).save(OUT/'pmui_transparent.png')

# Original 24px line drawings. Coordinates intentionally share a 1.6px stroke.
paths = {
    'box': [[(12,3),(21,8),(21,17),(12,22),(3,17),(3,8),(12,3)],[(3,8),(12,13),(21,8)],[(12,13),(12,22)],[(7.5,5.5),(16.5,10.5)]],
    'back': [[(10,5),(3,12),(10,19)],[(3,12),(21,12)]],
    'plus': [[(12,4),(12,20)],[(4,12),(20,12)]],
    'play': [[(7,4),(20,12),(7,20),(7,4)]],
    'folder': [[(3,20),(3,5),(9,5),(12,8),(21,8),(21,20),(3,20)]],
    'sprout': [[(12,22),(12,12),(8,9)],[(12,12),(12,6),(16,3),(21,3),(21,8),(17,11),(12,12)],[(12,15),(7,15),(3,11),(3,7),(7,7),(11,10)],[(7,22),(17,22)]],
    'users': [[(2,21),(2,18),(5,15),(11,15),(14,18),(14,21)],[(17,15),(21,18),(21,21)]],
    'globe': [[(2,11),(8,11),(8,6),(13,6)],[(6,20),(6,15),(12,15),(12,21)],[(15,3),(15,10),(22,10)]],
    'info': [[(12,11),(12,18)]],
    'puzzle': [[(3,3),(9,3),(9,6),(12,8),(15,6),(15,3),(21,3),(21,9),(18,9),(16,12),(18,15),(21,15),(21,21),(15,21),(15,18),(12,16),(9,18),(9,21),(3,21),(3,15),(6,15),(8,12),(6,9),(3,9),(3,3)]],
    'search': [[(16,16),(22,22)]],
    'download': [[(12,2),(12,16)],[(7,11),(12,16),(17,11)],[(3,17),(3,22),(21,22),(21,17)]],
    'settings': [[(4,7),(20,7)],[(4,17),(20,17)],[(8,3),(8,11)],[(16,13),(16,21)]],
    'trash': [[(5,7),(6,22),(18,22),(19,7)],[(3,7),(21,7)],[(8,7),(8,3),(16,3),(16,7)],[(10,11),(10,18)],[(14,11),(14,18)]],
    'save': [[(3,3),(18,3),(21,6),(21,21),(3,21),(3,3)],[(7,3),(7,10),(16,10),(16,3)],[(7,21),(7,15),(17,15),(17,21)]],
}
for name, segments in paths.items():
    im = Image.new('RGBA',(24*S,24*S)); draw = ImageDraw.Draw(im)
    for points in segments:
        draw.line([(round(x*S),round(y*S)) for x,y in points], fill='white',width=round(1.6*S),joint='curve')
    for bounds in ({'globe':[(2,2,22,22)],'info':[(2,2,22,22),(11.5,6,12.5,7)],
                    'users':[(4,3,12,11),(15,4,21,10)],'search':[(2,2,18,18)]}.get(name,[])):
        draw.ellipse(tuple(round(v*S) for v in bounds),outline='white',width=round(1.6*S))
    im.resize((72,72),Image.Resampling.LANCZOS).save(OUT/f'pmui_icon_{name}.png')
# Mainmenu accepts literal filenames, unlike in-game texture modifiers.
sources = [OUT.parent/'init.lua', OUT.parent/'theme.lua', OUT.parents[3]/'ui/pack_detail.css', OUT.parents[3]/'ui/controls.lua']
palette = set(re.findall(r'#[0-9A-Fa-f]{6}', '\n'.join(p.read_text(encoding='utf8') for p in sources)))
for path in list(OUT.glob('pmui_*.png')):
    if re.search(r'_[0-9A-Fa-f]{6}\.png$', path.name) or path.stem == 'pmui_transparent':
        continue
    base = Image.open(path).convert('RGBA')
    for color in palette:
        tinted = Image.new('RGBA', base.size, color)
        tinted.putalpha(base.getchannel('A'))
        tinted.save(path.with_name(path.stem+'_'+color[1:]+'.png'))
print(f'Built {len(list(OUT.glob("*.png")))} PMUI assets')
