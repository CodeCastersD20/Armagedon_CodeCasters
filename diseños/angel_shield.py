# Escudo angelical redondo y abombado. Blender: frente = +X, centro en z=CZ. Misma huella que el escudo viejo (Shield.glb, ya borrado).
import os
D=os.path.dirname(os.path.abspath(__file__))+'/'
exec(open(D+'style_head.py').read()); exec(open(D+'angel_palette.py').read())
CZ=0.38
def solid(name,loops_yz,x0,x1,reg,tile=True,bev=0.008):
    return extrude_poly(name,[(x1,y,z) for y,z in loops_yz],(x0-x1,0,0),reg,tile,bev)
def circle(r,seg,cy=0.0,cz=CZ,off=0.0):
    return [(cy+r*math.cos(2*math.pi*i/seg+off),cz+r*math.sin(2*math.pi*i/seg+off)) for i in range(seg)]
def disc(name,R,x0,x1,reg,seg=24,rings=6,cy=0.0,cz=CZ):
    m=bpy.data.meshes.new(name); bm=bmesh.new()
    def layer(x):
        c=bm.verts.new((x,cy,cz))
        rs=[[bm.verts.new((x,cy+R*(k/rings)*math.cos(2*math.pi*i/seg),cz+R*(k/rings)*math.sin(2*math.pi*i/seg))) for i in range(seg)] for k in range(1,rings+1)]
        return c,rs
    cf,rf=layer(x1); cb,rb=layer(x0)
    for c,rs,flip in((cf,rf,False),(cb,rb,True)):
        for i in range(seg):
            f=(c,rs[0][i],rs[0][(i+1)%seg]); bm.faces.new(f[::-1] if flip else f)
        for k in range(rings-1):
            for i in range(seg):
                f=(rs[k][i],rs[k+1][i],rs[k+1][(i+1)%seg],rs[k][(i+1)%seg]); bm.faces.new(f[::-1] if flip else f)
    for i in range(seg): bm.faces.new((rf[-1][i],rb[-1][i],rb[-1][(i+1)%seg],rf[-1][(i+1)%seg]))
    bmesh.ops.recalc_face_normals(bm,faces=bm.faces[:])
    bm.to_mesh(m); bm.free(); return link(name,m,(0,0,0),(0,0,0),reg,True)
def ring(name,rin,rout,x0,x1,reg,seg=20,cy=0.0,cz=CZ):
    m=bpy.data.meshes.new(name); bm=bmesh.new()
    o=[bm.verts.new((x1,y,z)) for y,z in circle(rout,seg,cy,cz)]
    n=[bm.verts.new((x1,y,z)) for y,z in circle(rin,seg,cy,cz)]
    fs=[bm.faces.new((o[i],o[(i+1)%seg],n[(i+1)%seg],n[i])) for i in range(seg)]
    r=bmesh.ops.extrude_face_region(bm,geom=fs)
    bmesh.ops.translate(bm,vec=(x0-x1,0,0),verts=[e for e in r['geom'] if isinstance(e,bmesh.types.BMVert)])
    bmesh.ops.recalc_face_normals(bm,faces=bm.faces[:])
    bm.to_mesh(m); bm.free(); return link(name,m,(0,0,0),(0,0,0),reg,True)
def feather_poly(cy,cz,ang,length,width):
    a=math.radians(ang); d=(math.cos(a),math.sin(a)); n=(-d[1],d[0])
    pts=[(0,0),(0.25,0.5),(0.75,0.5),(1.0,0.0),(0.75,-0.45),(0.25,-0.4)]
    return [(cy+d[0]*u*length+n[0]*v*width, cz+d[1]*u*length+n[1]*v*width) for u,v in pts]
# frente
disc('Base',0.62,0.0,0.04,IV)
disc('BackWood',0.60,-0.045,0.0,WOOD)
ring('Rim',0.55,0.66,0.035,0.085,GD,seg=24)
ring('RimBack',0.57,0.66,-0.07,0.035,GD,seg=24)
ring('RimInner',0.52,0.55,0.035,0.06,GDK)
ring('MidRing',0.40,0.43,0.04,0.065,GD)
angs=[-25,-5,15,35,55]; lens=[0.42,0.56,0.64,0.60,0.48]
for s in(-1,1):
    for k,(ag,ln) in enumerate(zip(angs,lens)):
        a=ag if s>0 else 180-ag
        solid(f'Feather{s}{k}',feather_poly(s*0.13,CZ-0.02,a,ln,0.10),0.045,0.075+0.006*k,FE,tile=False,bev=0.004)
solid('RayUp',[(-0.035,CZ+0.17),(0.035,CZ+0.17),(0.012,CZ+0.53),(-0.012,CZ+0.53)],0.05,0.09,GD,bev=0.004)
solid('RayDown',[(-0.035,CZ-0.17),(-0.012,CZ-0.53),(0.012,CZ-0.53),(0.035,CZ-0.17)],0.05,0.09,GD,bev=0.004)
for dg in(45,135,225,315):
    a=math.radians(dg); dy,dz=math.cos(a),math.sin(a); ny,nz=-dz,dy
    pts=[(0.18*dy+0.02*ny,CZ+0.18*dz+0.02*nz),(0.30*dy,CZ+0.30*dz),(0.18*dy-0.02*ny,CZ+0.18*dz-0.02*nz)]
    solid(f'RayDiag{dg}',pts,0.05,0.085,GD,bev=0.003)
disc('BossBase',0.17,0.05,0.10,SV,seg=16,rings=3)
ring('BossRing',0.15,0.19,0.06,0.115,GD,seg=16)
solid('Gem',circle(0.075,8,off=math.pi/8),0.10,0.14,SKY,tile=False,bev=0.012)
for i in range(8):
    a=2*math.pi*i/8+math.pi/8
    cyl(f'Stud{i}',(0.095,0.605*math.cos(a),CZ+0.605*math.sin(a)),0.025,0.03,reg=GD,seg=6,axis='X')
# atrás: cazoleta, empuñadura, correa, travesaños, remaches
ring('BossCup',0.12,0.18,-0.11,-0.045,SV,seg=16)
disc('BossHollow',0.12,-0.07,-0.045,HOLLOW,seg=16,rings=2)
for y in(-0.24,0.24): box(f'GripMount{y}',(-0.085,y,CZ),(0.08,0.05,0.07),reg=STEEL,bev=0.008)
box('GripBar',(-0.135,0,CZ),(0.035,0.54,0.05),reg=STEEL,bev=0.008)
box('GripWrap',(-0.135,0,CZ),(0.045,0.22,0.06),reg=LTH,bev=0.01)
for y in(-0.30,0.30):
    h=2*(0.58**2-y*y)**0.5
    box(f'Batten{y}',(-0.065,y,CZ),(0.04,0.09,h*0.92),reg=WOOD,bev=0.008)
z=CZ+0.27
box('ArmStrap',(-0.10,0,z),(0.025,0.66,0.07),reg=LTH,bev=0.008)
box('Buckle',(-0.115,0.10,z),(0.02,0.07,0.09),reg=GD,bev=0.006)
for y in(-0.30,0.30): box(f'StrapRivet{y}',(-0.115,y,z),(0.02,0.04,0.04),reg=GD,bev=0.006)
for i in range(12):
    a=2*math.pi*i/12
    cyl(f'BackStud{i}',(-0.055,0.52*math.cos(a),CZ+0.52*math.sin(a)),0.02,0.03,reg=GD,seg=6,axis='X')
g=join('Shield')
BULGE=0.12; RAD=0.66   # abombado: todo se desplaza en X según la distancia al centro
for v in g.data.vertices:
    rr=((v.co.y)**2+(v.co.z-CZ)**2)**0.5
    v.co.x+=BULGE*max(0.0,1.0-(min(rr,RAD)/RAD)**2)
g.data.update()
export(OUT+'AngelShield.glb'); print('DIMS',g.dimensions)
renders('ang',(0,0,CZ),[(3.2,0,0.5),(1.6,-2.6,0.6),(-3.0,1.0,0.6),(-1.8,-2.4,1.2)])
