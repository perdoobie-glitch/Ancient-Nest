"""Original v15 composition, Siege of the Nest. 128 BPM D minor loop."""
from pathlib import Path
import numpy as np,wave,subprocess,json
root=Path(__file__).resolve().parent.parent;sr=22050;beat=60/128;duration=64*beat;n=int(duration*sr);mix=np.zeros((n,2));rng=np.random.default_rng(150)
def put(x,t,g,pan=0):
 i=int(t*sr)%n;x=x*g;st=np.column_stack([x*np.sqrt((1-pan)/2),x*np.sqrt((1+pan)/2)]);split=min(len(x),n-i);mix[i:i+split]+=st[:split]
 if split<len(x):mix[:len(x)-split]+=st[split:]
def note(m,length,kind='bass'):
 t=np.arange(int(sr*length))/sr;f=440*2**((m-69)/12);x=np.sin(2*np.pi*f*t)+.25*np.sin(4*np.pi*f*t)+.10*np.sin(6*np.pi*f*t);env=(1-np.exp(-t*100))*np.minimum((length-t)/.07,1)
 if kind=='brass':x=sum(np.sin(2*np.pi*f*h*t)/h**1.3 for h in range(1,9));env=(1-np.exp(-t*18))*np.minimum((length-t)/.2,1)
 return x*np.maximum(0,env)
roots=[38,34,41,36]
for bar in range(16):
 base=roots[(bar//2)%4];start=bar*4*beat
 for step in range(8):put(note(base+(12 if step%4==3 else 0),beat*.43),start+step*beat/2,.18)
 for degree in [0,7,15]:put(note(base+12+degree,beat*3.7,'brass'),start,.055,degree/30-.25)
 for step in range(4):
  t=np.arange(int(sr*.3))/sr;kick=np.sin(2*np.pi*(58*t-28*t*t))*np.exp(-t*16);put(kick,start+step*beat,.3)
  if step%2:put(rng.normal(0,1,int(sr*.16))*np.exp(-np.arange(int(sr*.16))/sr*30),start+step*beat,.07)
 for step in range(8):put(rng.normal(0,1,int(sr*.04))*np.exp(-np.arange(int(sr*.04))/sr*130),start+step*beat/2,.022,(-.5 if step%2 else .5))
 if bar>=4:
  for step,degree in enumerate([0,7,10,7,3,7,12,10]):put(note(base+24+degree,beat*.45,'brass'),start+step*beat/2,.035,.2)
for delay,g in [(.13,.08),(.29,.05)]:mix+=np.roll(mix,int(sr*delay),axis=0)*g
mix=np.tanh(mix);mix*=.8/max(abs(mix).max(),.001)
path=root/'audio/music/menu_theme.wav'
with wave.open(str(path),'wb') as f:f.setnchannels(2);f.setsampwidth(2);f.setframerate(sr);f.writeframes((mix*32767).astype('<i2').tobytes())
subprocess.run(['ffmpeg','-y','-loglevel','error','-i',str(path),'-c:a','libvorbis','-q:a','5',str(path.with_suffix('.ogg'))],check=True);path.unlink()
(root/'data/menu_music_v15.json').write_text(json.dumps({'title':'Siege of the Nest','composer':'Original Ancient Nest composition','bpm':128,'seconds':duration,'key':'D minor','synthesized':True,'borrowed_recordings':False},indent=2))
