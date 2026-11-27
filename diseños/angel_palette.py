# Paleta angelical (escudo y espada).
random.seed(5)
IV,GD,SV,GDK,SKY,FE,LTH,STEEL,WOOD,HOLLOW=range(10)
def _ivory(x,y): b=0.93+0.05*random.random(); return (b,b*0.95,b*0.86)
def _gold(x,y): b=0.86+0.08*random.random(); return (b,b*0.70,b*0.20)
def _silver(x,y): b=0.62+0.18*random.random(); return (b*0.95,b*0.97,b)
def _gold_dk(x,y): b=0.45+0.12*random.random(); return (b,b*0.62,b*0.18)
def _sky(x,y):
    d=((x-16)**2+(y-16)**2)**0.5/16; return (0.55+0.45*(1-d),0.8+0.2*(1-d),1.0)
def _feather(x,y):
    if 15<=x<=16: return (0.86,0.74,0.45)
    b=0.96+0.04*random.random()
    if (y+abs(x-16))%8==0: b-=0.07
    return (b,b,b*0.95)
def _leather(x,y): b=0.30+0.1*random.random(); return (b,b*0.62,b*0.40)
def _steel(x,y): b=0.35+0.1*random.random(); return (b,b,b*1.05)
def _wood(x,y):
    plank=x//8; b=0.42+0.06*((plank*37)%5)/5+0.05*random.random()
    if x%8==0: b=0.16
    if (y+plank*7)%11==0: b-=0.06
    return (b,b*0.68,b*0.42)
for i,fn in enumerate([_ivory,_gold,_silver,_gold_dk,_sky,_feather,_leather,_steel,_wood,lambda x,y:(0.10,0.09,0.09)]): region(i,fn)
mat=make_material('AngelMat')
