# Atlas pixel art de huesos/polvo para la muerte de esqueletos: 4x2 frames de 32x32 (128x64).
# Uso: python3 diseños/bone_sprites.py  ->  armagedon/assets/textures/blood/bone_shards.png
import os, random, math
from PIL import Image
random.seed(29)
F = 32
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'armagedon', 'assets', 'textures', 'blood', 'bone_shards.png')
OUTLINE = (58, 46, 34, 255)
SHADE = (176, 160, 128, 255)
BONE = (226, 214, 184, 255)
LIGHT = (250, 244, 226, 255)

def new_mask():
    return [[0]*F for _ in range(F)]

def disc(m, cx, cy, r):
    for y in range(F):
        for x in range(F):
            if (x-cx)**2 + (y-cy)**2 <= r*r:
                m[y][x] = 1

def capsule(m, x0, y0, x1, y1, r):
    for i in range(24):
        t = i/23
        disc(m, x0+(x1-x0)*t, y0+(y1-y0)*t, r)

def long_bone():                   # fémur con nudos en ambos extremos
    m = new_mask(); a = random.uniform(0, math.pi); L = random.uniform(9, 12)
    dx, dy = math.cos(a)*L, math.sin(a)*L; px, py = -dy/L*2.2, dx/L*2.2; c = F/2
    capsule(m, c-dx, c-dy, c+dx, c+dy, 1.8)
    for s in (-1, 1):
        disc(m, c+s*dx+px, c+s*dy+py, 2.6); disc(m, c+s*dx-px, c+s*dy-py, 2.6)
    return m

def broken_bone():                 # hueso partido con punta astillada
    m = new_mask(); a = random.uniform(0, math.pi); c = F/2
    dx, dy = math.cos(a), math.sin(a)
    capsule(m, c-dx*9, c-dy*9, c+dx*6, c+dy*6, 2.0)
    disc(m, c-dx*9+dy*2, c-dy*9-dx*2, 2.6); disc(m, c-dx*9-dy*2, c-dy*9+dx*2, 2.6)
    for k in range(3):             # astillas en la punta rota
        capsule(m, c+dx*6, c+dy*6, c+dx*(9+k)+dy*(k-1)*2.5, c+dy*(9+k)-dx*(k-1)*2.5, 0.8)
    return m

def skull_piece():                 # trozo de cráneo con cuenca
    m = new_mask(); disc(m, 16, 15, 9)
    hole = new_mask(); disc(hole, 13, 15, 3); disc(hole, 21, 19, 2)
    for y in range(F):
        for x in range(F):
            if y > 22 or hole[y][x]:
                m[y][x] = 0
    return m

def fragments():                   # esquirlas sueltas
    m = new_mask()
    for _ in range(random.randint(6, 9)):
        x, y = random.uniform(6, 26), random.uniform(6, 26); a = random.uniform(0, math.pi)
        capsule(m, x, y, x+math.cos(a)*random.uniform(2, 5), y+math.sin(a)*random.uniform(2, 5), 1.1)
    return m

def dust():                        # nube de polvo de hueso
    m = new_mask()
    for _ in range(random.randint(7, 10)):
        a = random.uniform(0, math.tau); d = random.uniform(0, 8)
        disc(m, 16+math.cos(a)*d, 16+math.sin(a)*d, random.uniform(2.5, 5))
    return m

def paint(m, is_dust=False):
    img = Image.new('RGBA', (F, F), (0, 0, 0, 0))
    for y in range(F):
        for x in range(F):
            if not m[y][x]:
                continue
            edge = any(not (0 <= x+dx < F and 0 <= y+dy < F and m[y+dy][x+dx]) for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)))
            if is_dust:
                col = SHADE if edge else (BONE if random.random() < 0.7 else LIGHT)
            elif edge:
                col = OUTLINE
            elif m[y-1][x] == 0 if y > 0 else True:
                col = LIGHT
            else:
                col = BONE if random.random() < 0.8 else SHADE
            img.putpixel((x, y), col)
    return img

frames = [paint(long_bone()), paint(broken_bone()), paint(skull_piece()), paint(fragments()),
          paint(long_bone()), paint(broken_bone()), paint(dust(), True), paint(fragments())]
atlas = Image.new('RGBA', (F*4, F*2), (0, 0, 0, 0))
for i, fr in enumerate(frames):
    atlas.paste(fr, ((i % 4)*F, (i//4)*F))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
atlas.save(OUT)
os.makedirs(os.path.join(HERE, 'out'), exist_ok=True)
atlas.resize((F*16, F*8), Image.NEAREST).save(os.path.join(HERE, 'out', 'bone_shards_preview.png'))
print('ok', OUT)
