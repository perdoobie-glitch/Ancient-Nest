from pathlib import Path
import json,subprocess,numpy as np
root=Path(__file__).resolve().parents[1];doc=json.loads((root/'data/weapons.json').read_text());manifest=json.loads((root/'data/audio_manifest.json').read_text())
def read(path):
 return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(root/path.removeprefix('res://')),'-ar','44100','-ac','1','-f','f32le','-']),dtype='<f4').copy()
def write(path,x):
 path.parent.mkdir(parents=True,exist_ok=True)
 peak=float(abs(x).max()) if len(x) else 0
 if peak>.89:x=x*(.89/peak)
 subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar','44100','-ac','1','-i','-','-c:a','libvorbis','-q:a','4',str(path)],input=x.astype('<f4').tobytes(),check=True)
for d in doc['weapons']:
 if d.get('slot') not in ['primary','secondary']:continue
 ident=d['id'];folder=root/'audio/sfx/weapons'/ident
 for variant in range(3):
  parts=[]
  for suffix,gain in [('fire_crack',1),('fire_mechanical',.28),('fire_tail_open',.35)]:
   entry=manifest['sounds'].get(ident+'_'+suffix,{})
   if not entry.get('files'):continue
   parts.append(read(entry['files'][variant%len(entry['files'])])*gain)
  assert parts,ident
  x=np.zeros(max(map(len,parts)))
  for part in parts:x[:len(part)]+=part
  write(folder/f'shot_{variant+1}.ogg',x)
 for target,sound in [('shot_distant',ident+'_fire_distant'),('dry_fire',d['dry_sound']),('reload',d['reload_stages'][0]['id'])]:
  write(folder/(target+'.ogg'),read(manifest['sounds'][sound]['files'][0]))
print('Mixed reports for eight weapons from existing licensed gun recordings; no new external sources.')
