# Metralleta pesada estilo handcannon. Blender: adelante = -Y (glTF +Z), arriba = +Z, X = lateral.
# Origen cerca de la empuñadura/receptor, igual que la escopeta.
import os
D=os.path.dirname(os.path.abspath(__file__))+'/'
exec(open(D+'style_head.py').read()); exec(open(D+'gun_palette.py').read())
DK=D_
# --- receptor
box('Receiver',(0,0.0,0.15),(0.58,1.05,0.64),reg=DK,bev=0.025)
box('ReceiverLow',(0,-0.05,-0.20),(0.50,0.85,0.12),reg=D2)
box('TopCover',(0,-0.02,0.50),(0.44,0.95,0.06),reg=PL)
box('TopInset',(0,-0.02,0.535),(0.06,0.85,0.014),reg=RD,tile=False,bev=0)
for i in range(4): box(f'TopNotch{i}',(0,-0.32+0.2*i,0.545),(0.09,0.03,0.016),reg=BK,tile=False,bev=0)
# asa de carga
for y in(-0.30,0.22): box(f'HandlePost{y}',(0,y,0.64),(0.07,0.06,0.22),reg=BK,bev=0.01)
box('HandleBar',(0,-0.04,0.76),(0.09,0.64,0.07),reg=BK,bev=0.012)
box('HandleWrap',(0,-0.04,0.76),(0.11,0.34,0.09),reg=GR,bev=0.015)
box('RearSight',(0,0.38,0.58),(0.07,0.07,0.09),reg=BK)
# lado derecho (+X): placa, ventana de expulsión, palanca de carga, glifo
box('RPlate',(0.30,-0.05,0.18),(0.05,0.62,0.40),reg=PL,bev=0.02)
for z in(0.40,-0.04): box(f'RRed{z}',(0.33,-0.05,z),(0.012,0.64,0.022),reg=RD,tile=False,bev=0)
box('Eject',(0.335,-0.12,0.22),(0.012,0.30,0.10),reg=BK,tile=False,bev=0)
box('ChargeRail',(0.31,0.30,0.30),(0.03,0.30,0.05),reg=BK,bev=0.006)
box('ChargeKnob',(0.37,0.40,0.30),(0.10,0.06,0.07),reg=BK,bev=0.01)
box('RDecal',(0.30,0.36,0.08),(0.012,0.20,0.20),reg=DC,tile=False,bev=0)
# lado izquierdo (-X): caja de munición grande + cinta de balas hacia el receptor
box('AmmoBox',(-0.55,0.02,-0.08),(0.44,0.62,0.56),reg=D2,bev=0.025)
box('AmmoLid',(-0.55,0.02,0.22),(0.48,0.66,0.06),reg=PL,bev=0.015)
box('AmmoPanel',(-0.775,0.02,-0.08),(0.012,0.44,0.34),reg=DC,tile=False,bev=0)
for z in(0.10,-0.28): box(f'AmmoRed{z}',(-0.775,0.02,z),(0.014,0.56,0.022),reg=RD,tile=False,bev=0)
box('AmmoLatch',(-0.555,-0.30,0.08),(0.12,0.03,0.10),reg=BK,bev=0.008)
box('FeedPort',(-0.31,-0.08,0.28),(0.08,0.26,0.14),reg=PL,bev=0.012)
for i in range(8):
    t=i/7.0
    x=-0.62+0.30*t; z=0.30+0.16*math.sin(math.pi*t)
    cyl(f'Round{i}',(x,-0.08,z),0.028,0.20,reg=BR,seg=8,axis='Y')
    box(f'Link{i}',(x,-0.08,z-0.03),(0.045,0.22,0.012),reg=BK,tile=False,bev=0)
# cañón: cubierta ancha con ventilación + aletas disipadoras
box('Shroud',(0,-1.30,0.20),(0.48,1.55,0.46),reg=DK,bev=0.02)
box('ShroudTop',(0,-1.30,0.445),(0.24,1.45,0.03),reg=D2)
for s in(-1,1):
    for r_,z in enumerate((0.30,0.12)):
        for i in range(6): box(f'Vent{s}{r_}{i}',(s*0.242,-0.72-0.17*i,z),(0.012,0.10,0.05),reg=BK,tile=False,bev=0)
    box(f'ShroudRed{s}',(s*0.242,-1.30,0.02),(0.014,1.40,0.02),reg=RD,tile=False,bev=0)
for i in range(5): box(f'Fin{i}',(0,-1.62-0.09*i,0.20),(0.56,0.03,0.54),reg=D2,bev=0.006)
cyl('BarrelOut',(0,-2.18,0.20),0.085,0.22,reg=BK,seg=8,axis='Y')
# freno de boca grande con puertos laterales
box('Brake',(0,-2.42,0.20),(0.32,0.30,0.30),reg=D2,bev=0.02)
for s in(-1,1):
    for i in range(3): box(f'BrakePort{s}{i}',(s*0.162,-2.34-0.08*i,0.20),(0.012,0.05,0.16),reg=BK,tile=False,bev=0)
cyl('BoreRing',(0,-2.575,0.20),0.10,0.02,reg=PL,seg=8,axis='Y')
cyl('Bore',(0,-2.585,0.20),0.07,0.02,reg=BK,seg=8,axis='Y')
box('FrontSight',(0,-2.05,0.47),(0.05,0.07,0.10),reg=BK)
# riel inferior + empuñadura delantera + bípode plegado
box('UnderRail',(0,-1.10,-0.04),(0.20,0.90,0.05),reg=D2)
box('ForeGrip',(0,-0.95,-0.24),(0.16,0.14,0.36),rot=(-10,0,0),reg=GR)
box('ForeGripCap',(0,-0.97,-0.42),(0.18,0.16,0.04),rot=(-10,0,0),reg=BK,bev=0.008)
for s in(-1,1): box(f'Bipod{s}',(s*0.08,-1.75,-0.04),(0.035,0.60,0.035),reg=BK,bev=0.006)
# empuñadura trasera + guardamonte
box('Grip',(0,0.36,-0.36),(0.26,0.24,0.58),rot=(22,0,0),reg=GR)
box('GripEdge',(0,0.25,-0.38),(0.18,0.025,0.52),rot=(22,0,0),reg=PL,tile=False)
box('GuardF',(0,-0.20,-0.32),(0.05,0.04,0.20),reg=BK,bev=0.008)
box('GuardBot',(0,0.04,-0.42),(0.05,0.50,0.04),reg=BK,bev=0.008)
box('Trigger',(0,0.0,-0.30),(0.035,0.04,0.14),rot=(-15,0,0),reg=BK,bev=0.006)
# trasera: tapa con buffer
box('RearCap',(0,0.58,0.15),(0.54,0.12,0.58),reg=D2,bev=0.02)
box('RearRed',(0,0.645,0.15),(0.40,0.012,0.03),reg=RD,tile=False,bev=0)
cyl('Buffer',(0,0.72,0.20),0.10,0.18,reg=BK,seg=8,axis='Y')
g=join('Gun')
# Reflejo en X: en Godot el arma gira 180° en Y, así la caja de munición queda hacia el centro de la pantalla.
g.scale.x=-1; bpy.ops.object.transform_apply(scale=True)
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
export(OUT+'HeavyMG.glb'); print('DIMS',g.dimensions)
renders('hmg',(-0.1,-0.9,0.1),[(4.8,-0.9,1.0),(-4.8,-0.6,1.2),(3.0,-4.2,2.4),(1.2,2.6,1.0)])
