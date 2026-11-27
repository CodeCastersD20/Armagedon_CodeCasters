# Espada angelical. Blender: X = ancho de guarda, Y = grosor, Z = largo (punta z=0, pomo arriba).
# Misma huella que "Espada PS1": largo 0.944 y centro del mango en z~0.836 (model_grip_center de sword.gd).
import os
D=os.path.dirname(os.path.abspath(__file__))+'/'
exec(open(D+'style_head.py').read()); exec(open(D+'angel_palette.py').read())
def polyY(name,pts,y0,y1,reg,tile=True,bev=0.003):
    return extrude_poly(name,[(x,y1,z) for x,z in pts],(0,y0-y1,0),reg,tile,bev)
GZ=0.765
blade=[(0,0),(0.030,0.07),(0.034,0.60),(0.040,0.70),(0.046,GZ-0.02),(-0.046,GZ-0.02),(-0.040,0.70),(-0.034,0.60),(-0.030,0.07)]
polyY('Blade',blade,-0.007,0.007,SV,bev=0.004)
for s in(-1,1):
    box(f'Fuller{s}',(0,s*0.0075,0.40),(0.012,0.004,0.52),reg=GD,tile=False,bev=0.001)
    box(f'Ricasso{s}',(0,s*0.0085,0.71),(0.05,0.004,0.06),reg=GD,tile=False,bev=0.002)
box('GuardCore',(0,0,GZ),(0.075,0.036,0.045),reg=GD,bev=0.006)
for s in(-1,1):
    cyl(f'GuardGem{s}',(0,s*0.02,GZ),0.014,0.01,reg=SKY,seg=8,axis='Y')
    for k,(ang,ln,w) in enumerate([(8,0.16,0.034),(28,0.13,0.030),(48,0.10,0.026),(-14,0.10,0.024)]):
        a=math.radians(ang); d=(s*math.cos(a),math.sin(a)); n=(-d[1],d[0])
        bx,bz=s*0.03,GZ+0.005
        pts=[(0,0),(0.25,0.5),(0.75,0.5),(1.0,0.0),(0.75,-0.45),(0.25,-0.4)]
        poly=[(bx+d[0]*u*ln+n[0]*v*w, bz+d[1]*u*ln+n[1]*v*w) for u,v in pts]
        polyY(f'Feather{s}{k}',poly,-0.009+0.002*k,0.009-0.002*k,FE,tile=False,bev=0.002)
    box(f'GuardTip{s}',(s*0.04,0,GZ-0.022),(0.02,0.03,0.012),reg=GD,bev=0.003)
cyl('Grip',(0,0,0.836),0.015,0.10,reg=LTH,seg=8,axis='Z')
for z in(0.795,0.836,0.877): cyl(f'Band{z}',(0,0,z),0.017,0.008,reg=GD,seg=8,axis='Z')
cyl('Collar',(0,0,0.785),0.02,0.012,reg=GD,seg=8,axis='Z')
cyl('Pommel',(0,0,0.912),0.03,0.026,reg=GD,seg=10,axis='Y')
for s in(-1,1): cyl(f'PommelGem{s}',(0,s*0.014,0.912),0.016,0.006,reg=SKY,seg=8,axis='Y')
cyl('PommelCap',(0,0,0.944),0.012,0.016,reg=GD,seg=6,axis='Z')
g=join('AngelSword'); export(OUT+'AngelSword.glb'); print('DIMS',g.dimensions)
renders('swd',(0,0,0.47),[(1.6,-0.4,0.6),(0.5,-1.5,0.9),(0.0,-0.55,0.82)])
