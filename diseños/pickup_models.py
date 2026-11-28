# Pickups 3D low-poly: Esquirla (racimo de cristales), Fe (orbe con aureola), Vida (corazón).
# Uso: blender -b -P diseños/pickup_models.py -> armagedon/assets/models/pickups/*.glb
# Centro del modelo en el origen (Godot lo hace flotar y girar).
import os
D = os.path.dirname(os.path.abspath(__file__)) + '/'
exec(open(D + 'style_head.py').read())
DEST = D + '../armagedon/assets/models/pickups/'
os.makedirs(DEST, exist_ok=True)
random.seed(11)

CR_LT, CR, CR_DK, ORB, ORB_DK, HALO, HEART, HEART_LT = range(8)
def _crystal_lt(x, y): b = 0.95 + 0.05 * random.random(); return (b, b * 0.80, b * 0.28)
def _crystal(x, y): b = 0.86 + 0.06 * random.random(); return (b, b * 0.66, b * 0.18)
def _crystal_dk(x, y): b = 0.50 + 0.08 * random.random(); return (b, b * 0.55, b * 0.14)
def _orb(x, y):
    d = ((x - 10) ** 2 + (y - 22) ** 2) ** 0.5 / 26
    return (0.10 + 0.45 * (1 - d), 0.30 + 0.45 * (1 - d), 0.95)
def _orb_dk(x, y): b = 0.55 + 0.1 * random.random(); return (b * 0.20, b * 0.38, b)
def _halo(x, y): b = 0.92 + 0.08 * random.random(); return (b, b * 0.78, b * 0.30)
def _heart(x, y): b = 0.78 + 0.08 * random.random(); return (b, b * 0.10, b * 0.14)
def _heart_lt(x, y):
    d = ((x - 12) ** 2 + (y - 20) ** 2) ** 0.5 / 22
    return (1.0, 0.25 + 0.5 * (1 - d), 0.28 + 0.45 * (1 - d))
for i, fn in enumerate([_crystal_lt, _crystal, _crystal_dk, _orb, _orb_dk, _halo, _heart, _heart_lt]):
    region(i, fn)
mat = make_material('PickupMat')


def crystal(name, loc, r, h_top, h_bot, tilt, sides=6, reg_top=CR_LT, reg_bot=CR):
    """Bipirámide facetada (cristal)."""
    m = bpy.data.meshes.new(name); bm = bmesh.new()
    ring = [bm.verts.new((r * math.cos(2 * math.pi * i / sides), r * math.sin(2 * math.pi * i / sides), 0))
            for i in range(sides)]
    top = bm.verts.new((0, 0, h_top)); bot = bm.verts.new((0, 0, -h_bot))
    for i in range(sides):
        a, b = ring[i], ring[(i + 1) % sides]
        bm.faces.new((a, b, top)).material_index = 0
        bm.faces.new((b, a, bot)).material_index = 0
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(m); bm.free()
    o = link(name, m, loc, tilt, reg_top, False)
    # Caras de abajo con la región oscura: se remapean tras link().
    bm = bmesh.new(); bm.from_mesh(m); uv = bm.loops.layers.uv.active
    ox, oy = (reg_bot % 4) * 0.25, (reg_bot // 4) * 0.25
    for f in bm.faces:
        if f.calc_center_median().z < 0:
            for l in f.loops:
                u, v = l[uv].uv
                l[uv].uv = (ox + (u % 0.25), oy + (v % 0.25))
    bm.to_mesh(m); bm.free()
    return o


def ico(name, loc, r, reg, subdiv=1):
    m = bpy.data.meshes.new(name); bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    bm.to_mesh(m); bm.free(); return link(name, m, loc, (0, 0, 0), reg, False)


def torus(name, loc, R, r, reg, seg=16, rseg=4, rot=(0, 0, 0)):
    m = bpy.data.meshes.new(name); bm = bmesh.new()
    rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        ring = []
        for j in range(rseg):
            b = 2 * math.pi * j / rseg
            ring.append(bm.verts.new(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a), r * math.sin(b))))
        rings.append(ring)
    for i in range(seg):
        for j in range(rseg):
            bm.faces.new((rings[i][j], rings[(i + 1) % seg][j], rings[(i + 1) % seg][(j + 1) % rseg], rings[i][(j + 1) % rseg]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(m); bm.free(); return link(name, m, loc, rot, reg, False)


def finish(name):
    g = join(name)
    bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
    g.location = (0, 0, 0)
    bpy.ops.object.select_all(action='DESELECT'); g.select_set(True)
    bpy.context.view_layer.objects.active = g
    bpy.ops.export_scene.gltf(filepath=DEST + name + '.glb', export_format='GLB', use_selection=True)
    print('DIMS', name, tuple(round(v, 3) for v in g.dimensions))
    g.hide_render = True
    return g


# Esquirla: cristal principal + dos pequeños inclinados (Blender: Z arriba).
crystal('ShardMain', (0, 0, 0.02), 0.075, 0.20, 0.12, (0, 0, 15))
crystal('ShardL', (-0.07, 0.01, -0.04), 0.04, 0.10, 0.05, (0, -32, 0), sides=5)
crystal('ShardR', (0.065, -0.02, -0.05), 0.035, 0.08, 0.04, (24, 28, 0), sides=5)
shard = finish('PickupShard')
parts.clear()

# Fe: orbe azul + aureola dorada inclinada encima.
ico('FaithOrb', (0, 0, 0), 0.15, ORB, subdiv=2)
torus('FaithHalo', (0, 0, 0.21), 0.10, 0.018, HALO, rot=(12, 0, 0))
faith = finish('PickupFaith')
parts.clear()

# Vida: corazón extruido (contorno en el plano XZ, grosor en Y) con bisel.
pts = []
for i in range(24):
    t = 2 * math.pi * i / 24
    x = 16 * math.sin(t) ** 3
    z = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
    pts.append((x * 0.0105, -0.045, z * 0.0105))
extrude_poly('HeartBody', pts, (0, 0.09, 0), HEART, tile=False, bev=0.022)
ico('HeartShine', (-0.07, -0.035, 0.06), 0.035, HEART_LT, subdiv=1)
heart = finish('PickupHealth')

for o in (shard, faith, heart):
    o.hide_render = False
shard.location = (-0.5, 0, 0); heart.location = (0.5, 0, 0)
renders('pickup', (0, 0, 0), [(0, -1.8, 0.5), (1.2, -1.2, 0.9)], res=500)
