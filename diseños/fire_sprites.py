# Fuego pixel art de "La Espada en Llamas".
# 1) flame_sprites.png: 4 frames de 16x24 (llamas de la hoja, partículas billboard).
# 2) fire_slash.png: 4 frames de 64x32 (media luna de fuego que se lanza, billboard).
# Uso: python3 diseños/fire_sprites.py -> armagedon/assets/textures/fire/
import os, math, random
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.join(HERE, '..', 'armagedon', 'assets', 'textures', 'fire')
PREV = os.path.join(HERE, 'out')
os.makedirs(DEST, exist_ok=True)
os.makedirs(PREV, exist_ok=True)

# Rampa de calor: 0 = borde rojo oscuro ... 1 = núcleo blanco.
RAMP = [
    (0.00, (110, 16, 8)),
    (0.25, (200, 40, 10)),
    (0.50, (250, 110, 16)),
    (0.72, (255, 196, 40)),
    (0.90, (255, 244, 170)),
    (1.00, (255, 255, 240)),
]
STEPS = 5  # pocos colores: look PS1/pixel


def heat_color(h):
    h = max(0.0, min(1.0, round(h * STEPS) / STEPS))
    for i in range(len(RAMP) - 1):
        a, ca = RAMP[i]
        b, cb = RAMP[i + 1]
        if h <= b:
            t = (h - a) / (b - a)
            return tuple(int(ca[k] + (cb[k] - ca[k]) * t) for k in range(3)) + (255,)
    return RAMP[-1][1] + (255,)


def noise(x, y, seed):
    return (math.sin(x * 1.7 + seed * 3.1) * math.cos(y * 1.3 - seed * 1.9)
            + math.sin((x + y) * 0.9 + seed * 5.3)) * 0.25 + 0.5


# --- Llamas de la hoja: lengua de fuego que sube y ondula.
FW, FH = 16, 24
flames = Image.new('RGBA', (FW * 4, FH), (0, 0, 0, 0))
for f in range(4):
    for y in range(FH):
        v = 1.0 - y / (FH - 1)  # 0 abajo, 1 arriba
        sway = math.sin(v * 5.0 + f * 1.6) * 2.2 * v
        half = 6.5 * (1.0 - v) ** 0.6 * (0.85 + 0.15 * math.sin(f * 2.1 + v * 7))
        for x in range(FW):
            dx = abs(x - 7.5 - sway)
            if dx > half:
                continue
            core = 1.0 - dx / max(half, 0.01)
            h = core * 0.75 + (1.0 - v) * 0.45 + (noise(x, y, f) - 0.5) * 0.35 - 0.2
            if h < 0.05:
                continue
            flames.putpixel((f * FW + x, y), heat_color(h))
flames.save(os.path.join(DEST, 'flame_sprites.png'))
flames.resize((flames.width * 8, flames.height * 8), Image.NEAREST).save(
    os.path.join(PREV, 'flame_sprites_preview.png'))

# --- Media luna de fuego: arco con núcleo brillante y lenguas hacia afuera.
SW, SH = 64, 32
slash = Image.new('RGBA', (SW * 4, SH), (0, 0, 0, 0))
CX, CY = 31.5, 33.0  # centro del arco abajo: la media luna se curva hacia arriba
R_OUT, R_IN = 27.0, 15.0
for f in range(4):
    for y in range(SH):
        for x in range(SW):
            dx, dy = x - CX, y - CY
            r = math.hypot(dx, dy)
            ang = math.atan2(dx, -dy)  # 0 arriba
            span = abs(ang) / 1.3  # 0 centro, 1 puntas
            if span > 1.0:
                continue
            taper = (1.0 - span ** 2)
            thick = (R_OUT - R_IN) * taper
            inner = R_OUT - thick
            lick = (noise(x * 1.3, y * 0.7, f + 7) - 0.5) * 7.0 * taper  # lenguas hacia fuera
            outer = R_OUT + max(lick, -1.0)
            if r < inner or r > outer:
                continue
            depth = (outer - r) / max(outer - inner, 0.01)  # 0 borde exterior, 1 interior
            h = depth * 0.9 + taper * 0.25 + (noise(x, y, f) - 0.5) * 0.3 - 0.1
            if h < 0.06:
                continue
            slash.putpixel((f * SW + x, y), heat_color(h))
    # chispas sueltas
    random.seed(f * 13 + 3)
    for _ in range(10):
        a = random.uniform(-1.0, 1.0)
        r = R_OUT + random.uniform(1, 5)
        x = int(CX + math.sin(a) * r)
        y = int(CY - math.cos(a) * r)
        if 0 <= x < SW and 0 <= y < SH:
            slash.putpixel((f * SW + x, y), heat_color(0.8))
slash.save(os.path.join(DEST, 'fire_slash.png'))
slash.resize((slash.width * 4, slash.height * 4), Image.NEAREST).save(
    os.path.join(PREV, 'fire_slash_preview.png'))
print('OK')
