from pathlib import Path
import numpy as np, subprocess,json
from scipy.io import wavfile
r=Path(__file__).resolve().parents[1];w=r/'authoring/work';w.mkdir(parents=True,exist_ok=True);out=r/'audio/sfx/objectives';out.mkdir(parents=True,exist_ok=True)
sr=32000
for name,seconds,notes in [('bomb_planted_alert',.85,[(0,440),(.22,660),(.44,880)]),('bomb_defuse_start',.65,[(0,800),(.19,600),(.38,400)]),('bomb_armed_tick',.09,[(0,1050)])]:
 t=np.arange(int(sr*seconds))/sr;a=np.zeros(len(t))
 for start,hz in notes:
  q=t-start;env=np.where(q>=0,np.exp(-np.maximum(q,0)*20)*(1-np.exp(-np.maximum(q,0)*500)),0);a+=np.sin(2*np.pi*hz*q)*env*.25
 a=np.tanh(a);wav=w/(name+'.wav');wavfile.write(wav,sr,(a*32767).astype(np.int16));subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-c:a','libvorbis','-q:a','4',str(out/(name+'.ogg'))],check=True)
p=r/'data/audio_manifest.json';d=json.loads(p.read_text())
for name in ['bomb_planted_alert','bomb_defuse_start','bomb_armed_tick']:
 d['sounds'][name]={'files':['res://audio/sfx/objectives/'+name+'.ogg'],'bus':'SFX_Player','volume_db':-13 if name=='bomb_armed_tick' else -8,'pitch_range':[1,1],'spatial':False,'voice_limit':2,'priority':85}
p.write_text(json.dumps(d,indent=2)+'\n')
(r/'audio/LICENSE.txt').open('a').write('\nV20 update objective arming/defuse/tick tones: original procedural synthesis for Ancient Nest, no third-party samples.\n')
