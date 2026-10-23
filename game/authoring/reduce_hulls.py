"""Convert Blender's shared body surfaces to compact convex damage hulls.
Run create_characters.py in Blender first, then this with Python + numpy + scipy.
"""
from pathlib import Path
import json,numpy as np
from scipy.spatial import ConvexHull
root=Path(__file__).resolve().parent.parent
for faction in ['Naki','Annu']:
 raw=json.loads((root/'authoring'/f'{faction}_damage_raw.json').read_text());regions=[]
 # Uniform direction sampling retains visible silhouette extrema; no overall box.
 n=128;i=np.arange(n);y=1-2*(i+.5)/n;a=i*np.pi*(3-np.sqrt(5));r=np.sqrt(1-y*y)
 dirs=np.vstack([np.column_stack([r*np.cos(a),y,r*np.sin(a)]),np.eye(3),-np.eye(3)])
 for bone,vertices in raw.items():
  pts=np.unique(np.round(vertices,6),axis=0)
  selected=pts[np.unique(np.argmax(pts@dirs.T,axis=0))]
  hull=ConvexHull(selected);selected=selected[hull.vertices]
  center=(selected.min(axis=0)+selected.max(axis=0))/2;selected=selected-center
  hull=ConvexHull(selected)
  planes=np.unique(np.round(hull.equations,6),axis=0)
  region='head' if bone=='head' else 'arm' if bone.startswith(('upperarm','forearm','hand')) else 'leg' if bone.startswith(('thigh','calf','foot')) else 'torso'
  regions.append({'bone':bone,'region':region,'position':center.round(6).tolist(),'points':selected.round(6).tolist(),'planes':planes.tolist(),'minimum':selected.min(axis=0).round(6).tolist(),'maximum':selected.max(axis=0).round(6).tolist()})
 # Preserve head-first/chest-second ordering used by tools/tests, without relying on this in gameplay.
 order={'head':0,'chest':1,'spine_01':2,'pelvis':3,'neck':4}
 regions.sort(key=lambda q:(order.get(q['bone'],5),q['bone']))
 out=root/'data'/f'{faction.lower()}_hitboxes.json'
 out.write_text(json.dumps({'schema_version':1,'source':f'models/{faction}.glb','exclude':['cape','scarf','insignia','headset microphone'],'regions':regions},separators=(',',':'))+'\n')
 print(faction,len(regions),'hulls,',sum(len(q['points']) for q in regions),'vertices,',sum(len(q['planes']) for q in regions),'planes')
