"""Derive layered Mochii motion assets from the owner's supplied logo."""
from pathlib import Path
from PIL import Image, ImageDraw
import math

ROOT = Path(__file__).resolve().parents[1]
out = ROOT / 'assets/animations'
out.mkdir(exist_ok=True)
source = Image.open(ROOT / 'assets/app_logo.png').convert('RGBA')
# Separate the mascot from the wordmark, preserving the tip of its book.
for y in range(840, source.height):
    for x in range(source.width):
        if x < 480 or x > 760 or y > 883:
            source.putpixel((x, y), (0, 0, 0, 0))
crop = (280, 80, 960, 880)
base = source.crop(crop)
eyes = Image.new('RGBA', base.size)
for raw in [(487, 437, 602, 504), (655, 437, 771, 504)]:
    x0, y0, x1, y1 = raw
    box = (x0-crop[0], y0-crop[1], x1-crop[0], y1-crop[1])
    for y in range(box[1], box[3]):
        left = base.getpixel((box[0]-4, y))
        right = base.getpixel((box[2]+4, y))
        for x in range(box[0], box[2]):
            original = base.getpixel((x, y))
            t = (x-box[0])/(box[2]-box[0])
            bg = tuple(round(left[k]*(1-t)+right[k]*t) for k in range(3)) + (255,)
            base.putpixel((x, y), bg)
            alpha = max(0, min(1, (original[1]-bg[1])/max(1, 250-bg[1])))
            if alpha > .03:
                eyes.putpixel((x, y), (255, 250, 255, round(alpha*255)))
base = base.resize((408, 480), Image.Resampling.LANCZOS)
eyes = eyes.resize((408, 480), Image.Resampling.LANCZOS)
base.save(out / 'mochii_reading_base.png')
eyes.save(out / 'mochii_reading_eyes.png')
Image.alpha_composite(base, eyes).save(out / 'mochii_reading_poster.png')
frames = []
for i in range(60):
    phase = i/60
    wave = phase*2*math.pi
    blink = 1
    for at in [.18, .27]:
        distance = abs(phase-at)
        if distance < .023:
            blink = min(blink, .08+.92*distance/.023)
    art = base.copy()
    eye = eyes.resize((408, max(1, round(480*blink))), Image.Resampling.LANCZOS)
    art.alpha_composite(eye, (0, round(235*(1-blink))))
    art = art.resize((272, 320), Image.Resampling.LANCZOS).rotate(
        1.6*math.sin(wave), Image.Resampling.BICUBIC, expand=True)
    frame = Image.new('RGBA', (420, 460), '#F7F3FC')
    draw = ImageDraw.Draw(frame)
    shadow = 1-.08*math.sin(wave)
    draw.ellipse((210-68*shadow, 372, 210+68*shadow, 385), fill='#E6DBF3')
    bob = round(-7*math.sin(wave))
    frame.alpha_composite(art, ((420-art.width)//2, 35+bob))
    draw = ImageDraw.Draw(frame)
    for x, y, offset, size in [(66, 113, 0, 8), (351, 83, .3, 10), (342, 290, .65, 6)]:
        strength = .55+.4*math.sin(wave+offset*6.28)
        r = size*(.7+.3*strength)
        draw.polygon([(x,y-r),(x+r*.32,y-r*.32),(x+r,y),(x+r*.32,y+r*.32),
                      (x,y+r),(x-r*.32,y+r*.32),(x-r,y),(x-r*.32,y-r*.32)], fill='#B692DE')
    turn = (phase-.36)/.4
    if 0 < turn < 1:
        spread = 65*math.cos(math.pi*turn)
        draw.polygon([(209,269+bob),(209+spread,231+bob),
                      (209+spread*.8,221+bob),(209,239+bob)], fill='#FFF6D5', outline='#BA97DD')
    frames.append(frame.convert('RGB'))
frames[0].save(out / 'mochii_reading_preview.webp', save_all=True, append_images=frames[1:],
               duration=40, loop=0, quality=85, method=6)
preview = ROOT / 'docs/startup'
preview.mkdir(exist_ok=True, parents=True)
frames[0].save(preview / 'loading-art-preview.png')
print('Created layered PNG assets and a 2.4s WebP preview.')
