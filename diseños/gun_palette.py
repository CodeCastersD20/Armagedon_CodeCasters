# Paleta de armas de fuego (estilo handcannon): carbón granate, placas grises con ribete rojo.
random.seed(11)
D_,PL,GR,BK,RD,DC,BR,D2=range(8)
_blk={}
def _j(v,a): return max(0,v+(random.random()-0.5)*a)
def _dark(x,y):
    k=(x//4,y//4)
    if k not in _blk: _blk[k]=random.random()
    b=0.07+0.07*_blk[k]
    return (_j(b*1.35,0.02),_j(b*0.95,0.02),_j(b*0.95,0.02))
def _plate(x,y):
    b=0.55+0.12*random.random()
    if x in(0,31) or y in(0,31): return (0.50,0.10,0.10)
    if x in(1,30) or y in(1,30): return (0.30,0.25,0.25)
    return (b,b*0.97,b*0.97)
def _grip(x,y): b=0.30+0.12*random.random(); return (b,b*0.33,b*0.28)
_glyph=[[random.random()>0.5 for _ in range(7)] for _ in range(7)]
for i in range(7): _glyph[0][i]=_glyph[6][i]=_glyph[i][0]=_glyph[i][6]=True
def _decal(x,y):
    gx,gy=(x-6)//3,(y-6)//3
    if 0<=gx<7 and 0<=gy<7 and _glyph[gy][gx] and 6<=x<27 and 6<=y<27: return (0.62,0.62,0.62)
    return _dark(x,y)
def _dark2(x,y):
    b=0.16+0.05*random.random()
    if x%16==0 or y%16==0: b=0.04
    return (b*1.2,b*0.9,b*0.9)
for i,fn in enumerate([_dark,_plate,_grip,lambda x,y:(0.025,0.022,0.022),lambda x,y:(_j(0.62,0.08),0.07,0.07),
                       _decal,lambda x,y:(0.85,0.42,0.08) if y>6 else (0.8,0.7,0.3),_dark2]): region(i,fn)
mat=make_material('ShotgunMat')
