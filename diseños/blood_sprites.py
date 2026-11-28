# Atlas pixel art de salpicaduras de sangre: 4x2 frames de 32x32 (128x64), fondo transparente.
# Uso: python3 diseños/blood_sprites.py  ->  armagedon/assets/textures/blood/blood_splats.png
import os, random, math
from PIL import Image
random.seed(13)
F = 32
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'armagedon', 'assets', 'textures', 'blood', 'blood_splats.png')
DARK = (70, 0, 4, 255)
RED = (150, 4, 8, 255)
BRIGHT = (215, 18, 18, 255)
HIGH = (255, 92, 80, 255)

def blob_mask(kind):
    m = [[0]*F for _ in range(F)]
    def disc(cx, cy, r):
        for y in range(F):
            for x in range(F):
                if (x-cx)**2 + (y-cy)**2 <= r*r:
                    m[y][x] = 1
    c = F/2
    if kind == 'splat':            # mancha grande con lóbulos y gotas alrededor
        disc(c, c, random.uniform(6, 8))
        for _ in range(random.randint(6, 9)):
            a = random.uniform(0, math.tau); d = random.uniform(5, 9)
            disc(c+math.cos(a)*d, c+math.sin(a)*d, random.uniform(2, 4.5))
        for _ in range(random.randint(5, 8)):
            a = random.uniform(0, math.tau); d = random.uniform(11, 14)
            disc(c+math.cos(a)*d, c+math.sin(a)*d, random.uniform(0.8, 1.8))
    elif kind == 'drops':          # racimo de gotas sueltas
        for _ in range(random.randint(5, 8)):
            disc(random.uniform(6, 26), random.uniform(6, 26), random.uniform(1.5, 4))
    elif kind == 'streak':         # chorro alargado con gota en la punta
        a = random.uniform(0, math.tau)
        for i in range(14):
            t = i/13
            disc(c+math.cos(a)*(t*22-11), c+math.sin(a)*(t*22-11), 1.5+3.2*(1-abs(t-0.75)*1.6 if t>0.5 else t*1.2))
    else:                          # 'burst': estallido con picos radiales
        disc(c, c, 5)
        for _ in range(random.randint(7, 10)):
            a = random.uniform(0, math.tau)
            for k in range(12):
                d = k
                disc(c+math.cos(a)*d, c+math.sin(a)*d, max(0.6, 3.2-k*0.25))
    return m

def paint(kind):
    m = blob_mask(kind)
    img = Image.new('RGBA', (F, F), (0, 0, 0, 0))
    for y in range(F):
        for x in range(F):
            if not m[y][x]:
                continue
            edge = any(not (0 <= x+dx < F and 0 <= y+dy < F and m[y+dy][x+dx]) for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)))
            if edge:
                col = DARK
            elif y < F/2 - 3 and random.random() < 0.55:
                col = BRIGHT
            else:
                col = RED if random.random() < 0.8 else DARK
            img.putpixel((x, y), col)
    # brillos de 1-2 píxeles
    for _ in range(random.randint(2, 4)):
        for _try in range(30):
            x, y = random.randrange(F), random.randrange(F)
            if m[y][x] and y < F - 4:
                img.putpixel((x, y), HIGH)
                break
    return img

kinds = ['splat', 'splat', 'burst', 'drops', 'streak', 'splat', 'burst', 'drops']
atlas = Image.new('RGBA', (F*4, F*2), (0, 0, 0, 0))
for i, k in enumerate(kinds):
    atlas.paste(paint(k), ((i % 4)*F, (i//4)*F))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
atlas.save(OUT)
atlas.resize((F*4*4, F*2*4), Image.NEAREST).save(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out', 'blood_splats_preview.png'))
print('ok', OUT)
