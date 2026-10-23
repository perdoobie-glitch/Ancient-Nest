from pathlib import Path
R=Path(__file__).resolve().parents[1]
import numpy as np
from PIL import Image, ImageFilter
D=R/'assets/savannah';rng=np.random.default_rng(901);n=512;y,x=np.mgrid[:n,:n]
def noise():
 out=np.zeros((n,n))
 for grid,weight in [(8,8),(32,4),(128,2),(512,1)]:
  a=rng.integers(0,256,(grid,grid),dtype=np.uint8);a=np.array(Image.fromarray(a).resize((n,n),Image.Resampling.BICUBIC),dtype=float)/255-.5;out+=a*weight
 return out
for name,col in [('sand',(163,134,94)),('sandstone',(136,113,85)),('ore',(70,67,59)),('timber',(76,59,42)),('metal',(72,79,77))]:
 v=noise();h=v.copy();rgb=np.array(col)+v[:,:,None]
 if name=='sandstone':
  row=y//85;xx=(x+(row%2)*128)%256;mortar=(y%85<3)|(xx<3);block=rng.normal(0,5,(7,3));v+=block[row,np.minimum(xx//86,2)];rgb=np.array(col)+v[:,:,None];rgb[mortar]=np.array([99,87,69])+v[mortar,None];h[mortar]-=9
 if name=='sand':
  wave=np.sin((y+5*np.sin(x*2*np.pi/n))*2*np.pi/32);rgb+=wave[:,:,None]*1.6;h+=wave*.8
 if name=='ore':
  strata=np.sin(y*2*np.pi*9/n+np.sin(x*2*np.pi/n)*1.2);rgb+=strata[:,:,None]*2;h+=strata*2
  # Sparse irregular veins, not luminous wallpaper.
  vein=(np.abs(strata)<.065)&(v>1.7);rgb[vein]=[131,110,60];h[vein]+=1
 if name=='timber':
  grain=np.sin((x+noise()*1.6)*2*np.pi/12);rgb+=grain[:,:,None]*3;h+=grain
 if name=='metal':rgb+=rng.normal(0,1,(n,n,1))
 Image.fromarray(np.clip(rgb,0,255).astype('uint8')).save(D/(name+'.png'))
 dy,dx=np.gradient(h);normal=np.stack((-dx,-dy,np.ones_like(h)*10),axis=-1);normal/=np.linalg.norm(normal,axis=-1)[:,:,None]
 Image.fromarray(((normal*.5+.5)*255).astype('uint8')).save(D/(name+'_normal.png'))
