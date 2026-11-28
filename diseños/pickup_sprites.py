# Atlas pixel art de los pickups 2D (billboard): 3 filas x 4 frames de 32x32 (128x96).
# Fila 0 Esquirla (cristal dorado girando), 1 Fe (orbe azul con aureola), 2 Vida (corazón latiendo).
# Uso: python3 diseños/pickup_sprites.py -> armagedon/assets/textures/pickups/pickup_sprites.png
import os, math
from PIL import Image

F = 32
FRAMES = 4
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'armagedon', 'assets', 'textures', 'pickups', 'pickup_sprites.png')
PREVIEW = os.path.join(HERE, 'out', 'pickup_sprites_preview.png')
img = Image.new('RGBA', (F * FRAMES, F * 3), (0, 0, 0, 0))


def put(ox, oy, x, y, c):
    if 0 <= x < F and 0 <= y < F:
        img.putpixel((ox + x, oy + y), c)


def outline(ox, oy, mask, color):
    for y in range(F):
        for x in range(F):
            if mask[y][x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < F and 0 <= ny < F and mask[ny][nx]:
                    put(ox, oy, x, y, color)
                    break


def sparkle(ox, oy, cx, cy, size, color):
    put(ox, oy, cx, cy, color)
    for i in range(1, size + 1):
        for dx, dy in ((i, 0), (-i, 0), (0, i), (0, -i)):
            put(ox, oy, cx + dx, cy + dy, color)


# --- Esquirla: rombo facetado que "gira" estrechándose; la cara clara cambia de lado.
GOLD_DK = (120, 74, 18, 255)
GOLD = (222, 168, 52, 255)
GOLD_LT = (255, 222, 120, 255)
WHITE = (255, 252, 236, 255)
for f in range(FRAMES):
    ox, oy = f * F, 0
    width = [9.5, 6.0, 2.5, 6.0][f]
    flip = f >= 2
    mask = [[0] * F for _ in range(F)]
    cx, top, mid, bot = 15.5, 3, 12, 28
    for y in range(F):
        if top <= y <= mid:
            half = width * (y - top) / (mid - top)
        elif mid < y <= bot:
            half = width * (bot - y) / (bot - mid)
        else:
            continue
        for x in range(F):
            dx = x - cx
            if abs(dx) <= half + 0.3:
                mask[y][x] = 1
                lit = (dx < 0) != flip
                if y <= mid:
                    c = GOLD_LT if lit else GOLD
                else:
                    c = GOLD if lit else GOLD_DK
                if abs(dx) < 0.8 and width > 3:
                    c = WHITE if y <= mid else GOLD_LT
                put(ox, oy, x, y, c)
    outline(ox, oy, mask, (60, 34, 8, 255))
    sx = [10, 20, 22, 12][f]
    sy = [6, 9, 18, 22][f]
    sparkle(ox, oy, sx, sy, 2 if f % 2 == 0 else 1, WHITE)


# --- Fe: orbe azul con brillo que pulsa y aureola dorada encima.
def orb(ox, oy, r, base, light, dark, core):
    mask = [[0] * F for _ in range(F)]
    cx, cy = 15.5, 17.5
    for y in range(F):
        for x in range(F):
            d = math.hypot(x - cx, y - cy)
            if d <= r:
                mask[y][x] = 1
                hl = math.hypot(x - (cx - r * 0.35), y - (cy - r * 0.35)) / r
                c = dark if d > r * 0.75 else base
                if hl < 0.55:
                    c = light
                if hl < 0.22:
                    c = core
                put(ox, oy, x, y, c)
    return mask


for f in range(FRAMES):
    ox, oy = f * F, F
    r = [9.0, 9.6, 10.0, 9.6][f]
    mask = orb(
        ox, oy, r, (54, 110, 230, 255), (130, 190, 255, 255), (24, 50, 150, 255),
        (235, 248, 255, 255)
    )
    outline(ox, oy, mask, (12, 22, 70, 255))
    for x in range(F):  # aureola: elipse fina dorada sobre el orbe
        for y in range(0, 9):
            e = ((x - 15.5) / 8.5) ** 2 + ((y - 4.0) / 2.3) ** 2
            if 0.62 <= e <= 1.08:
                put(ox, oy, x, y, GOLD_LT if x < 16 else GOLD)
    glow = [(4, 26), (27, 12), (26, 27), (5, 11)][f]
    sparkle(ox, oy, glow[0], glow[1], 1, (200, 230, 255, 255))


# --- Vida: corazón rojo que late.
for f in range(FRAMES):
    ox, oy = f * F, 2 * F
    s = [1.0, 0.86, 0.94, 0.86][f]
    mask = [[0] * F for _ in range(F)]
    for y in range(F):
        for x in range(F):
            u = (x - 15.5) / s
            v = (y - 16.0) / s
            lobe = min(math.hypot(u + 5.0, v + 3.6), math.hypot(u - 5.0, v + 3.6))
            tip = -3.4 <= v <= 11.0 and abs(u) <= (11.0 - v) * 0.78
            notch = abs(u) < 1.6 - (v + 7.5) * 0.5 and v < -4.5
            if (lobe <= 5.8 or tip) and not notch:
                u, v = u / 10.5, -v / 10.5
                mask[y][x] = 1
                hl = math.hypot(u + 0.42, v - 0.38)
                c = (204, 26, 36, 255)
                if v < -0.62 or u > 0.66:
                    c = (126, 10, 22, 255)
                if hl < 0.32:
                    c = (255, 110, 110, 255)
                if hl < 0.13:
                    c = (255, 228, 228, 255)
                put(ox, oy, x, y, c)
    outline(ox, oy, mask, (54, 4, 10, 255))
    if f == 0:
        sparkle(ox, oy, 25, 6, 2, (255, 236, 236, 255))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
img.save(OUT)
img.resize((img.width * 6, img.height * 6), Image.NEAREST).save(PREVIEW)
print('OK', OUT)
