# Sonidos de las transiciones entre círculos, sintetizados (sin samples de terceros).
# Genera WAV temporales y los convierte a .ogg (q1) con ffmpeg, como pide AGENTS.md.
# Uso: python3 diseños/transition_sfx.py -> armagedon/assets/audio/sfx/transitions/*.ogg
import os, subprocess, tempfile, wave
import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.join(HERE, '..', 'armagedon', 'assets', 'audio', 'sfx', 'transitions')
os.makedirs(DEST, exist_ok=True)
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(SR * seconds)) / SR


def env(n, attack=0.005, release=0.3):
    e = np.ones(n)
    a = max(1, int(SR * attack))
    r = max(1, int(SR * release))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e


def lowpass(x, alpha):
    """Filtro de un polo (alpha pequeño = más grave)."""
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def norm(x, peak=0.85):
    m = np.max(np.abs(x))
    return x / m * peak if m > 0 else x


def save(name, x):
    x = norm(x)
    data = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
        path = tmp.name
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    out = os.path.join(DEST, name + '.ogg')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', path, '-vn', '-map_metadata', '-1',
                    '-c:a', 'libvorbis', '-q:a', '1', out], check=True)
    os.remove(path)
    print('OK', out)


# Campana grave de iglesia: parciales inarmónicos que decaen a ritmos distintos.
x = t(4.5)
bell = np.zeros_like(x)
for ratio, amp, decay in [(0.5, 0.5, 0.6), (1.0, 1.0, 0.9), (1.19, 0.6, 1.3), (1.5, 0.4, 1.6),
                          (2.0, 0.35, 2.2), (2.74, 0.2, 3.0), (3.0, 0.15, 3.5)]:
    bell += amp * np.sin(2 * np.pi * 98.0 * ratio * x + rng.uniform(0, 6)) * np.exp(-decay * x)
bell += 0.3 * rng.standard_normal(len(x)) * np.exp(-60 * x)  # golpe del badajo
save('SFX_Bell_Toll', bell * env(len(x), 0.002, 0.8))

# Retumbo de tierra: ruido muy grave con pulsos.
x = t(3.2)
rumble = lowpass(rng.standard_normal(len(x)), 0.004)
rumble *= 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 1.7 * x))
save('SFX_Rumble', rumble * env(len(x), 0.4, 1.0))

# Alma en pena: aullido con vibrato, dos voces desafinadas y aire.
x = t(2.4)
pitch = 420 + 140 * np.sin(np.pi * x / 2.4) + 12 * np.sin(2 * np.pi * 6.0 * x)
phase = 2 * np.pi * np.cumsum(pitch) / SR
wail = np.sin(phase) + 0.6 * np.sin(phase * 1.013 + 1.0) + 0.25 * np.sin(phase * 2.0)
wail += 0.25 * lowpass(rng.standard_normal(len(x)), 0.08)
save('SFX_Soul_Wail', wail * np.sin(np.pi * np.clip(x / 2.4, 0, 1)) ** 1.5)

# Piedra que se agrieta y cae: crujidos + caída grave.
x = t(1.8)
crack = np.zeros_like(x)
for start in np.sort(rng.uniform(0, 0.6, 12)):
    i = int(start * SR)
    n = int(0.03 * SR)
    crack[i:i + n] += rng.standard_normal(n) * np.exp(-120 * np.arange(n) / SR)
fall = lowpass(rng.standard_normal(len(x)), 0.01) * np.exp(-2.0 * np.abs(x - 0.9))
save('SFX_Stone_Crack', (crack + 1.6 * fall) * env(len(x), 0.001, 0.6))

# Remo en el agua: chapoteo (ruido filtrado) + burbujas.
x = t(1.3)
splash = lowpass(rng.standard_normal(len(x)), 0.12) * np.exp(-6 * x)
bubbles = sum(np.sin(2 * np.pi * f * x * (1 + 0.6 * x)) * np.exp(-9 * x) * 0.15 for f in
              rng.uniform(400, 1200, 6))
save('SFX_Water_Oar', (splash + bubbles) * env(len(x), 0.04, 0.5))
