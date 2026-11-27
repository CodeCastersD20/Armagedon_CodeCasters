# Helpers compartidos: atlas 128x128 (regiones 32x32), cajas/cilindros/prismas, export y renders.
import bpy,bmesh,math,random,os
from mathutils import Vector, Matrix
OUT=D+'out/'
os.makedirs(OUT,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
N=128; R=32
px=[[0,0,0,1] for _ in range(N*N)]
def put(x,y,c): px[y*N+x]=[c[0],c[1],c[2],1]
def region(idx,fn):
    ox,oy=(idx%4)*R,(idx//4)*R
    for y in range(R):
        for x in range(R): put(ox+x,oy+y,fn(x,y))
def make_material(name):
    img=bpy.data.images.new(name+'_tex',N,N); img.pixels=[c for p in px for c in p]; img.pack()
    mat=bpy.data.materials.new(name); mat.use_nodes=True
    b=mat.node_tree.nodes['Principled BSDF']
    t=mat.node_tree.nodes.new('ShaderNodeTexImage'); t.image=img; t.interpolation='Closest'
    mat.node_tree.links.new(t.outputs['Color'],b.inputs['Base Color'])
    b.inputs['Metallic'].default_value=0; b.inputs['Roughness'].default_value=0.85
    return mat
mat=None
parts=[]
def uvmap(m,reg,tile):
    bm=bmesh.new(); bm.from_mesh(m); uv=bm.loops.layers.uv.new('UVMap')
    ox,oy=(reg%4)*0.25,(reg//4)*0.25
    for f in bm.faces:
        n=f.normal; ax=max(range(3),key=lambda k:abs(n[k])); a,c=[(1,2),(0,2),(0,1)][ax]
        pa=[l.vert.co[a] for l in f.loops]; pc=[l.vert.co[c] for l in f.loops]
        a0,a1,c0,c1=min(pa),max(pa),min(pc),max(pc)
        for l in f.loops:
            if tile: u=(l.vert.co[a]*2.0)%1.0; v=(l.vert.co[c]*2.0)%1.0
            else: u=(l.vert.co[a]-a0)/max(a1-a0,1e-6); v=(l.vert.co[c]-c0)/max(c1-c0,1e-6)
            l[uv].uv=(ox+(0.02+0.96*u)*0.25,oy+(0.02+0.96*v)*0.25)
    bm.to_mesh(m); bm.free()
def link(name,m,loc,rot,reg,tile):
    o=bpy.data.objects.new(name,m); bpy.context.scene.collection.objects.link(o)
    o.location=loc; o.rotation_euler=[math.radians(a) for a in rot]
    o.data.materials.append(mat); parts.append(o); uvmap(m,reg,tile); return o
def box(name,loc,size,rot=(0,0,0),reg=0,tile=True,bev=0.015):
    m=bpy.data.meshes.new(name); bm=bmesh.new()
    bmesh.ops.create_cube(bm,size=1); bmesh.ops.scale(bm,vec=size,verts=bm.verts)
    if bev>0: bmesh.ops.bevel(bm,geom=bm.edges[:],offset=min(bev,min(size)*0.4),segments=1,affect='EDGES')
    bm.to_mesh(m); bm.free(); return link(name,m,loc,rot,reg,tile)
def cyl(name,loc,r,length,reg=0,seg=8,axis='Y'):
    m=bpy.data.meshes.new(name); bm=bmesh.new()
    bmesh.ops.create_cone(bm,cap_ends=True,segments=seg,radius1=r,radius2=r,depth=length)
    if axis!='Z':
        bmesh.ops.rotate(bm,verts=bm.verts,cent=(0,0,0),matrix=Matrix.Rotation(math.radians(90),3,'X' if axis=='Y' else 'Y'))
    bm.to_mesh(m); bm.free(); return link(name,m,loc,(0,0,0),reg,True)
def extrude_poly(name,verts3,move,reg,tile=True,bev=0.0):
    m=bpy.data.meshes.new(name); bm=bmesh.new()
    f=bm.faces.new([bm.verts.new(v) for v in verts3])
    r=bmesh.ops.extrude_face_region(bm,geom=[f])
    bmesh.ops.translate(bm,vec=move,verts=[e for e in r['geom'] if isinstance(e,bmesh.types.BMVert)])
    bmesh.ops.recalc_face_normals(bm,faces=bm.faces[:])
    if bev>0: bmesh.ops.bevel(bm,geom=bm.edges[:],offset=bev,segments=1,affect='EDGES')
    bm.to_mesh(m); bm.free(); return link(name,m,(0,0,0),(0,0,0),reg,tile)
def join(name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts: o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.object.join(); g=bpy.context.object; g.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True); return g
def export(path): bpy.ops.export_scene.gltf(filepath=path,export_format='GLB')
def renders(prefix,ctr,cams,res=600):
    s=bpy.context.scene
    bpy.ops.object.light_add(type='SUN',location=(4,-2,3)); sun=bpy.context.object; sun.data.energy=4
    sun.rotation_euler=(Vector(ctr)-sun.location).to_track_quat('-Z','Y').to_euler()
    s.world=bpy.data.worlds.new('w'); s.world.color=(0.6,0.6,0.6)
    s.render.resolution_x=res; s.render.resolution_y=res
    for i,p in enumerate(cams):
        bpy.ops.object.camera_add(location=p); c=bpy.context.object
        c.rotation_euler=(Vector(ctr)-c.location).to_track_quat('-Z','Y').to_euler()
        s.camera=c; s.render.filepath=OUT+f'{prefix}{i}.png'; bpy.ops.render.render(write_still=True)
