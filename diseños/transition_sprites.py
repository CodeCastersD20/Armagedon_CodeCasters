# Sprites pixel art de las transiciones entre círculos: atlas 4x2 de 32x32 (128x64).
# Fila 0: alma (3 frames que ondulan) + Sello del Jefe.
# Fila 1: polvo, chispa, eslabón de cadena, brazo que sale del agua.
# Uso: python3 diseños/transition_sprites.py -> armagedon/assets/textures/transitions/transition_sprites.png
import os, math, random
from PIL import Image

F = 32
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'armagedon', 'assets', 'textures', 'transitions', 'transition_sprites.png')
PREV = os.path.join(HERE, 'out', 'transition_sprites_preview.png')
img = Image.new('RGBA', (F * 4, F * 2), (0, 0, 0, 0))


def put(col, row, x, y, c):
    if 0 <= x < F and 0 <= y < F:
        img.putpixel((col * F + x, row * F + y), c)


def outline(col, row, mask, color):
    for y in range(F):
        for x in range(F):
            if mask[y][x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < F and 0 <= ny < F and mask[ny][nx]:
                    put(col, row, x, y, color)
                    break


# --- Alma: cabeza redonda, cuerpo que se deshilacha en cola ondulante, cuencas oscuras.
SOUL_DARK = (70, 110, 150, 255)
SOUL = (150, 205, 235, 255)
SOUL_LT = (225, 248, 255, 255)
for f in range(3):
    mask = [[0] * F for _ in range(F)]
    for y in range(F):
        for x in range(F):
            head = math.hypot(x - 15.5, y - 10.0) <= 7.0
            body = False
            if 10 <= y <= 29:
                t = (y - 10) / 19.0
                sway = math.sin(t * 5.0 + f * 2.1) * 3.0 * t
                half = 7.0 * (1.0 - t) ** 0.8 + 0.5
                body = abs(x - 15.5 - sway) <= half
            if head or body:
                mask[y][x] = 1
                d = math.hypot(x - 13.0, y - 7.0)
                c = SOUL_LT if d < 3.5 else (SOUL if y < 22 else SOUL_DARK)
                put(f, 0, x, y, c)
    for ex in (11, 18):  # cuencas vacías
        for dy in range(4):
            for dx in range(3):
                if not (dy in (0, 3) and dx in (0, 2)):
                    put(f, 0, ex + dx, 8 + dy, (20, 30, 50, 255))
    for my in range(13, 17 + (f % 2)):  # boca abierta en grito
        for mx in range(14, 18):
            if not ((my == 13 or my == 16 + (f % 2)) and mx in (14, 17)):
                put(f, 0, mx, my, (20, 30, 50, 255))
    outline(f, 0, mask, (30, 50, 80, 255))

# --- Sello del Jefe: anillo dorado con runa y núcleo rojo.
GOLD = (240, 190, 70, 255)
GOLD_DK = (140, 90, 20, 255)
CORE = (255, 60, 30, 255)
CORE_LT = (255, 200, 120, 255)
mask = [[0] * F for _ in range(F)]
for y in range(F):
    for x in range(F):
        d = math.hypot(x - 15.5, y - 15.5)
        if d <= 14.0:
            mask[y][x] = 1
            if d >= 11.0:
                c = GOLD if (x + y) % 5 else GOLD_DK
            elif d >= 9.5:
                c = GOLD_DK
            else:
                c = CORE_LT if d < 3.0 else CORE
            put(3, 0, x, y, c)
for a in range(8):  # marcas rúnicas del anillo
    ang = a * math.pi / 4
    for r in (11.5, 12.5, 13.3):
        put(3, 0, int(15.5 + math.cos(ang) * r), int(15.5 + math.sin(ang) * r), (90, 30, 10, 255))
for i in range(-6, 7):  # cruz invertida en el núcleo
    put(3, 0, 15 + 0, 15 + i, GOLD)
    put(3, 0, 16, 15 + i, GOLD)
for i in range(-3, 4):
    put(3, 0, 15 + i, 18, GOLD)
outline(3, 0, mask, (40, 15, 5, 255))

# --- Polvo: nube grumosa marrón grisácea.
random.seed(4)
mask = [[0] * F for _ in range(F)]
blobs = [(15.5 + random.uniform(-7, 7), 17 + random.uniform(-5, 5), random.uniform(4, 7)) for _ in range(7)]
for y in range(F):
    for x in range(F):
        best = min(math.hypot(x - bx, y - by) - br for bx, by, br in blobs)
        if best <= 0:
            mask[y][x] = 1
            c = (150, 132, 112, 255) if y < 16 else (110, 96, 82, 255)
            if best < -3.5:
                c = (178, 162, 140, 255)
            put(0, 1, x, y, c)
outline(0, 1, mask, (60, 50, 42, 255))

# --- Chispa: estrella de 4 puntas brillante.
for i in range(-11, 12):
    w = max(0, 2 - abs(i) // 4)
    for j in range(-w, w + 1):
        c = (255, 255, 210, 255) if abs(i) < 4 else (255, 190, 60, 255)
        put(1, 1, 15 + i, 15 + j, c)
        put(1, 1, 15 + j, 15 + i, c)

# --- Eslabón de cadena: óvalo de hierro (vertical) con brillo.
mask = [[0] * F for _ in range(F)]
for y in range(F):
    for x in range(F):
        e = ((x - 15.5) / 8.0) ** 2 + ((y - 15.5) / 14.0) ** 2
        ei = ((x - 15.5) / 4.0) ** 2 + ((y - 15.5) / 9.5) ** 2
        if e <= 1.0 and ei > 1.0:
            mask[y][x] = 1
            c = (120, 116, 112, 255) if x < 15 else (72, 68, 66, 255)
            if x < 11 and 6 < y < 25:
                c = (180, 176, 170, 255)
            put(2, 1, x, y, c)
outline(2, 1, mask, (28, 24, 22, 255))

# --- Brazo que sale del agua: antebrazo pálido con mano de dedos abiertos.
mask = [[0] * F for _ in range(F)]
for y in range(F):
    for x in range(F):
        arm = 12 <= y <= 31 and abs(x - 15.5 - (31 - y) * 0.12) <= 3.0
        palm = math.hypot(x - 15.5, y - 9.5) <= 4.5
        finger = False
        for k, fx in enumerate((-4.5, -1.5, 1.5, 4.5)):
            top = 2 + abs(k - 1.5) * 1.2
            if top <= y <= 8 and abs(x - 15.5 - fx - (8 - y) * fx * 0.08) <= 0.9:
                finger = True
        if arm or palm or finger:
            mask[y][x] = 1
            c = (190, 196, 180, 255) if x < 16 else (140, 146, 132, 255)
            put(3, 1, x, y, c)
outline(3, 1, mask, (40, 46, 40, 255))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
os.makedirs(os.path.dirname(PREV), exist_ok=True)
img.save(OUT)
img.resize((img.width * 6, img.height * 6), Image.NEAREST).save(PREV)
print('OK', OUT)
