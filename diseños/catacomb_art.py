# Arte pixel art de las catacumbas (pozo del elevador, escalera, derrumbe).
# 1) catacomb_wall.png: tile 64x128 que se repite. Arriba osario (filas de cráneos y cabezas de
#    hueso apiladas); abajo piedra tallada con un nicho funerario oscuro.
# 2) catacomb_sprites.png: atlas 4x2 de 32x32:
#    0 cráneo quieto · 1 cráneo gritando · 2 cráneo gritando con ojos rojos · 3 brazo esquelético
#    4 soporte de antorcha · 5 huesos cruzados · 6 cráneo partido · 7 alma gritando (cara)
# Uso: python3 diseños/catacomb_art.py -> armagedon/assets/textures/transitions/
import os, math, random
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.join(HERE, '..', 'armagedon', 'assets', 'textures', 'transitions')
PREV = os.path.join(HERE, 'out')
os.makedirs(DEST, exist_ok=True)
os.makedirs(PREV, exist_ok=True)
random.seed(13)

BONE_HI = (226, 212, 176)
BONE = (186, 170, 134)
BONE_MID = (146, 130, 100)
BONE_DK = (98, 84, 62)
MORTAR = (34, 27, 22)
HOLE = (16, 12, 10)
STONE_HI = (150, 136, 112)
STONE = (118, 106, 86)
STONE_DK = (78, 68, 54)


def jitter(c, amt=10):
    d = random.randint(-amt, amt)
    return tuple(max(0, min(255, v + d)) for v in c) + (255,)


# ---------------------------------------------------------------- pared (64x128)
W, H = 64, 128
wall = Image.new('RGBA', (W, H), MORTAR + (255,))


def wput(x, y, c):
    wall.putpixel((x % W, y % H), c if len(c) == 4 else c + (255,))


def knob(cx, cy, r):
    """Cabeza de hueso vista de frente (fémur apilado): disco con brillo arriba a la izquierda."""
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            d = math.hypot(x - cx, y - cy)
            if d <= r:
                lit = (x - cx) + (y - cy) < -r * 0.4
                shade = (x - cx) + (y - cy) > r * 0.6
                c = BONE_HI if lit else (BONE_DK if shade else BONE)
                if abs(x - cx) < 0.8 and abs(y - cy) < 0.8 and r > 2.2:
                    c = BONE_MID  # hueco del hueso
                wput(x, y, jitter(c, 8))


def wall_skull(cx, cy):
    """Cráneo de frente de 10 px en la pared del osario."""
    for y in range(cy - 5, cy + 6):
        for x in range(cx - 5, cx + 6):
            dx, dy = x - cx, y - cy
            if (dx / 5.2) ** 2 + ((dy + 1) / 4.6) ** 2 <= 1.0 or (abs(dx) <= 3 and 2 <= dy <= 5):
                c = BONE_HI if dx < -1 and dy < 0 else (BONE_DK if dx > 2 or dy > 3 else BONE)
                wput(x, y, jitter(c, 6))
    for ex in (cx - 2, cx + 2):  # cuencas
        for y in range(cy - 1, cy + 2):
            for x in range(ex - 1, ex + 1):
                wput(x, y, HOLE)
    wput(cx, cy + 2, HOLE)  # nariz
    for x in range(cx - 2, cx + 3):  # dientes
        wput(x, cy + 4, BONE_DK if x % 2 else BONE_HI)


# Osario (y 0..63): fila de cráneos, 3 filas de cabezas de hueso, fila de cráneos, 2 filas más.
y = 6
for row, kind in enumerate(['skull', 'knob', 'knob', 'knob', 'skull', 'knob', 'knob']):
    if kind == 'skull':
        for i in range(5):
            wall_skull(6 + i * 13 + (row % 2) * 6, y)
        y += 12
    else:
        off = 3 if row % 2 else 0
        for i in range(11):
            knob(3 + i * 6 + off + random.uniform(-0.5, 0.5), y, random.uniform(2.2, 2.9))
        y += 6
# Viga de piedra que separa el osario del muro tallado.
for yy in range(64, 69):
    for xx in range(W):
        wput(xx, yy, jitter(STONE_HI if yy == 64 else (STONE if yy < 68 else STONE_DK), 8))
# Muro tallado (y 69..127): bloques de piedra con un nicho funerario (loculus).
for yy in range(69, H):
    for xx in range(W):
        bx = (xx + (8 if ((yy - 69) // 15) % 2 else 0)) % 16
        by = (yy - 69) % 15
        c = STONE
        if bx == 0 or by == 0:
            c = STONE_DK
        elif bx == 1 or by == 1:
            c = STONE_HI
        wput(xx, yy, jitter(c, 9))
# Nicho: hueco oscuro con borde y huesos dentro.
nx0, nx1, ny0, ny1 = 10, 54, 84, 108
for yy in range(ny0 - 2, ny1 + 3):
    for xx in range(nx0 - 2, nx1 + 3):
        if nx0 <= xx <= nx1 and ny0 <= yy <= ny1:
            depth = min(xx - nx0, nx1 - xx, yy - ny0, ny1 - yy)
            wput(xx, yy, (10 + depth, 8 + depth, 7 + depth))
        else:
            wput(xx, yy, jitter(STONE_DK, 5))
for i in range(5):  # huesos largos tirados en el nicho
    bx = 14 + i * 8
    for xx in range(bx, bx + 7):
        wput(xx, 104 - (i % 2), jitter(BONE_MID, 8))
    knob(bx, 104 - (i % 2), 1.4)
    knob(bx + 7, 104 - (i % 2), 1.4)
wall_skull(32, 98)
wall.save(os.path.join(DEST, 'catacomb_wall.png'))
tile3 = Image.new('RGBA', (W * 3, H * 2))
for i in range(3):
    for j in range(2):
        tile3.paste(wall, (i * W, j * H))
tile3.resize((tile3.width * 3, tile3.height * 3), Image.NEAREST).save(
    os.path.join(PREV, 'catacomb_wall_preview.png'))

# ---------------------------------------------------------------- sprites (4x2 de 32x32)
F = 32
sp = Image.new('RGBA', (F * 4, F * 2), (0, 0, 0, 0))


def sput(cell, x, y, c):
    if 0 <= x < F and 0 <= y < F:
        sp.putpixel(((cell % 4) * F + x, (cell // 4) * F + y), c if len(c) == 4 else c + (255,))


def outline(cell, mask, color=(30, 22, 16)):
    for y in range(F):
        for x in range(F):
            if mask[y][x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < F and 0 <= ny < F and mask[ny][nx]:
                    sput(cell, x, y, color)
                    break


def skull(cell, jaw_open, red_eyes=False, cracked=False):
    mask = [[0] * F for _ in range(F)]
    drop = 5 if jaw_open else 0
    for y in range(F):
        for x in range(F):
            dx, dy = x - 15.5, y - 13.0
            cran = (dx / 11.0) ** 2 + (dy / 10.5) ** 2 <= 1.0 and y <= 19
            cheek = abs(dx) <= 8 and 17 <= y <= 22
            jaw = abs(dx) <= 7 - max(0, y - 25 - drop) and 22 + drop <= y <= 27 + drop
            if cran or cheek or jaw:
                mask[y][x] = 1
                lit = dx < -3 and dy < -2
                c = BONE_HI if lit else (BONE_DK if dx > 6 or y > 24 + drop else BONE)
                sput(cell, x, y, jitter(c, 6))
    eye = (255, 40, 20) if red_eyes else HOLE
    for ex in (10, 18):  # cuencas grandes
        for y in range(11, 17):
            for x in range(ex, ex + 5):
                if not ((y in (11, 16)) and x in (ex, ex + 4)):
                    sput(cell, x, y, HOLE)
        if red_eyes:
            sput(cell, ex + 2, 13, eye)
            sput(cell, ex + 2, 14, eye)
            sput(cell, ex + 1, 14, (255, 140, 60))
    for y in range(17, 20):  # nariz
        for x in range(15, 17 + (y > 17)):
            sput(cell, x, y, HOLE)
    for x in range(10, 22):  # dientes de arriba
        sput(cell, x, 21, BONE_DK if x % 2 else BONE_HI)
    if jaw_open:  # boca abierta en grito
        for y in range(22, 22 + drop):
            for x in range(10, 22):
                sput(cell, x, y, HOLE)
        for x in range(10, 22):
            sput(cell, x, 22 + drop, BONE_DK if x % 2 else BONE_HI)
    if cracked:
        x = 20
        for y in range(4, 13):
            x += random.choice((-1, 0, 1))
            sput(cell, x, y, BONE_DK)
    outline(cell, mask)


skull(0, False)
skull(1, True)
skull(2, True, red_eyes=True)
skull(6, False, cracked=True)

# 3: brazo esquelético que sale estirándose (huesos + mano de dedos abiertos).
mask = [[0] * F for _ in range(F)]
def bone_line(cell, x0, y0, x1, y1, r, m):
    steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    for i in range(steps):
        t = i / max(steps - 1, 1)
        cx, cy = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                if 0 <= x < F and 0 <= y < F and math.hypot(x - cx, y - cy) <= r:
                    m[y][x] = 1
                    sput(cell, x, y, jitter(BONE if x < cx else BONE_MID, 6))
bone_line(3, 4, 30, 13, 19, 1.6, mask)        # cúbito/radio
bone_line(3, 6, 30, 15, 20, 1.0, mask)
bone_line(3, 13, 19, 16, 14, 2.0, mask)       # muñeca/palma
for k, (fx, fy) in enumerate([(13, 4), (17, 3), (21, 5), (24, 9), (9, 9)]):
    bone_line(3, 15 + (k - 2) * 1.2, 14, fx, fy, 0.9, mask)  # dedos
outline(3, mask)

# 4: soporte de antorcha (hierro) con mango de madera; el fuego va aparte.
mask = [[0] * F for _ in range(F)]
for y in range(F):
    for x in range(F):
        cup = abs(x - 15.5) <= 5 - (y - 8) * 0.3 and 8 <= y <= 13
        handle = abs(x - 15.5) <= 1.5 and 13 <= y <= 24
        ring = abs(x - 15.5) <= 4 and 19 <= y <= 20
        plate = abs(x - 15.5) <= 3 and 24 <= y <= 30
        if cup or handle or ring or plate:
            mask[y][x] = 1
            iron = (70, 66, 64) if x < 16 else (44, 40, 38)
            wood = (110, 70, 36) if x < 16 else (80, 48, 24)
            sput(4, x, y, jitter(wood if handle and not ring else iron, 5))
for x in range(12, 20):  # brasas en la copa
    sput(4, x, 8, (255, 120 + (x % 3) * 40, 30))
outline(4, mask)

# 5: huesos cruzados.
mask = [[0] * F for _ in range(F)]
bone_line(5, 6, 6, 26, 26, 1.5, mask)
bone_line(5, 26, 6, 6, 26, 1.5, mask)
for cx, cy in ((6, 6), (26, 26), (26, 6), (6, 26)):
    for ox, oy in ((-1.5, 1.5), (1.5, -1.5)):
        for y in range(F):
            for x in range(F):
                if math.hypot(x - cx - ox, y - cy - oy) <= 2.2:
                    mask[y][x] = 1
                    sput(5, x, y, jitter(BONE_HI, 6))
outline(5, mask)

# 7: alma gritando (cara alargada y fantasmal).
mask = [[0] * F for _ in range(F)]
for y in range(F):
    for x in range(F):
        t = y / 31.0
        half = 9.5 * math.sin(min(t * 1.3, 1.0) * math.pi * 0.5) * (1.0 - t * 0.55) + 1
        sway = math.sin(t * 6.0) * 2.0 * t
        if abs(x - 15.5 - sway) <= half and y >= 2:
            mask[y][x] = 1
            c = (215, 240, 255) if y < 10 else ((150, 200, 230) if y < 22 else (80, 120, 160))
            sput(7, x, y, c)
for ex in (11, 18):
    for y in range(8, 13):
        for x in range(ex, ex + 3):
            sput(7, x, y, (15, 20, 40))
for y in range(14, 24):  # boca estirada
    half = 2 + (y - 14) // 4
    for x in range(int(15.5 - half), int(16.5 + half)):
        sput(7, x, y, (15, 20, 40))
outline(7, mask, (30, 50, 80))

sp.save(os.path.join(DEST, 'catacomb_sprites.png'))
sp.resize((sp.width * 6, sp.height * 6), Image.NEAREST).save(
    os.path.join(PREV, 'catacomb_sprites_preview.png'))
print('OK')
