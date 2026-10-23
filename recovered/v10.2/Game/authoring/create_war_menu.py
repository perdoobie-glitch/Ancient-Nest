"""Original Ancient Nest v16 score: The Siege Awakens.
Rendered with FluidSynth + TimGM6mb (GPL-2); this score, rendered track and
procedural percussion/voices are distributed under GPL-2. No sampled songs.
Run: python authoring/create_war_menu.py (numpy, scipy, libfluidsynth, ffmpeg).
"""
from pathlib import Path
import ctypes as C, numpy as np, subprocess, json, wave
from scipy.signal import butter,sosfilt
r=Path(__file__).resolve().parent.parent
sr=44100;bpm=132;beat=60/bpm;bars=48;duration=bars*4*beat;tail=4;N=round(duration*sr)
rng=np.random.default_rng(160);events=[]
def note(ch,key,start,length,vel=80):
 events.extend([(round(start*sr),1,ch,key,vel),(round((start+length)*sr),0,ch,key,0)])
roots=[38,38,34,36,43,34,33,38]
# Channels: double bass, celli, strings L/R, horns, trombones, choir, timpani.
programs={0:43,1:42,2:48,3:49,4:60,5:57,6:52,7:47,8:61}
for bar in range(bars):
 t=bar*4*beat;root=roots[bar%8];phase=0 if bar<8 else 1 if bar<16 else 2 if bar<32 else 1 if bar<40 else 3
 chord=[root,root+7,root+15] if bar%8 not in [6] else [root,root+7,root+16]
 note(0,root-12,t,beat*3.8,84)
 for step in range(8):
  # Repeated low strings provide a rhythmic pulse without a synthetic bass lead.
  n=root+[0,7,12,7,0,7,10,7][step]
  note(1,n,t+step*.5*beat,beat*.36,65+phase*9+(8 if step%2==0 else 0))
 if bar>=4:
  for n in chord:note(3,n+12,t,beat*3.7,48+phase*7)
 if phase>=1:
  for step in range(16):
   n=root+24+[0,7,12,7,3,7,10,7][step%8]
   note(2,n,t+step*.25*beat,beat*.18,54+phase*7+(6 if step%4==0 else 0))
 if phase>=2:
  motif=[[0,7,10,12],[14,12,10,7],[3,7,10,7],[5,7,2,0]][bar%4]
  for step,d in enumerate(motif):note(4,root+24+d,t+step*beat,beat*.82,85+phase*5)
  for n in chord[:2]:note(5,n,t,beat*(1.6 if bar%2==0 else .85),85)
  for n in chord:note(6,n+12,t,beat*3.8,48)
 elif bar>=8:
  for n in chord:note(6,n+12,t,beat*3.8,42)
  if bar%2==0:
   for n in chord[:2]:note(4,n+12,t,beat*2.8,65)
 if phase==3:
  for n in chord:note(8,n+12,t+2*beat,beat*1.5,75)
 for step in [0,2,3.5] if phase<2 else [0,1.5,2,3,3.5]:
  note(7,root-2+(12 if step==3.5 else 0),t+step*beat,beat*.45,95 if step==0 else 70)
# Render the orchestral instrument stems through FluidSynth, no audio device.
f=C.CDLL('libfluidsynth.so.3')
def bind(name,restype,args):
 fn=getattr(f,name);fn.restype=restype;fn.argtypes=args;return fn
ptr=C.c_void_p;I=C.c_int;F=C.c_float;D=C.c_double;S=C.c_char_p
settings=bind('new_fluid_settings',ptr,[])()
bind('fluid_settings_setnum',I,[ptr,S,D])(settings,b'synth.sample-rate',sr)
f.fluid_settings_setnum(settings,b'synth.gain',.43)
f.fluid_settings_setnum(settings,b'synth.reverb.room-size',.78)
f.fluid_settings_setnum(settings,b'synth.reverb.damp',.4)
f.fluid_settings_setnum(settings,b'synth.reverb.level',.24)
synth=bind('new_fluid_synth',ptr,[ptr])(settings)
bind('fluid_synth_sfload',I,[ptr,S,I])(synth,str(r/'authoring/soundfonts/TimGM6mb.sf2').encode(),1)
program=bind('fluid_synth_program_change',I,[ptr,I,I]);cc=bind('fluid_synth_cc',I,[ptr,I,I,I])
for ch,p in programs.items():
 program(synth,ch,p);cc(synth,ch,10,{0:62,1:45,2:26,3:100,4:83,5:45,6:64,7:70,8:90}[ch]);cc(synth,ch,91,45)
on=bind('fluid_synth_noteon',I,[ptr,I,I,I]);off=bind('fluid_synth_noteoff',I,[ptr,I,I])
write=bind('fluid_synth_write_float',I,[ptr,I,ptr,I,I,ptr,I,I]);mix=np.zeros((N+sr*tail,2),np.float32);cursor=0
for sample,kind,ch,key,vel in sorted(events):
 sample=min(sample,len(mix))
 if sample>cursor:
  out=np.zeros((sample-cursor,2),np.float32);write(synth,len(out),out.ctypes.data,0,2,out.ctypes.data,1,2);mix[cursor:sample]=out;cursor=sample
 if kind:on(synth,ch,key,vel)
 else:off(synth,ch,key)
if cursor<len(mix):
 out=np.zeros((len(mix)-cursor,2),np.float32);write(synth,len(out),out.ctypes.data,0,2,out.ctypes.data,1,2);mix[cursor:]=out
bind('delete_fluid_synth',None,[ptr])(synth);bind('delete_fluid_settings',None,[ptr])(settings)
# Fold orchestral release/reverb into the next loop rather than truncate it.
mix[:sr*tail]+=mix[N:];mix=mix[:N]
def put(x,t,g,pan=0):
 i=round(t*sr)%N;st=x[:,None]*np.array([np.sqrt((1-pan)/2),np.sqrt((1+pan)/2)])[None,:]*g
 for offset in range(0,len(st),N):
  v=st[offset:offset+N];n=min(len(v),N-i);mix[i:i+n]+=v[:n]
  if n<len(v):mix[:len(v)-n]+=v[n:]
  i=0
def drum(size=1):
 t=np.arange(round(sr*1.1))/sr;freq=43*size+58*size*np.exp(-t*34)
 phase=np.cumsum(freq)*2*np.pi/sr
 body=(np.sin(phase)+.32*np.sin(phase*1.57)+.13*np.sin(phase*2.31))*np.exp(-t*(4.8+size))
 attack=sosfilt(butter(2,[90,2600],btype='bandpass',fs=sr,output='sos'),rng.normal(size=len(t)))*np.exp(-t*65)*.9
 return np.tanh((body+attack)*1.2)*(1-np.exp(-t*900))
def shout(length=1.6,register=0):
 # Original voiced/noise battle cry: glottal harmonics, changing vowel formants,
 # breath and gravel. Synthetic voices, no performers or borrowed voice clips.
 t=np.arange(round(length*sr))/sr;x=np.zeros(len(t));env=np.sin(np.pi*t/length)**.7
 for voice in range(5):
  f0=(132+register*14+voice*7)*(1+.11*np.sin(2*np.pi*5.5*t+voice)+.3*np.exp(-t*5))
  ph=2*np.pi*np.cumsum(f0)/sr;v=np.zeros(len(t))
  for h in range(1,42):
   hz=f0*h
   gain=(np.exp(-((hz-780)/220)**2)+.65*np.exp(-((hz-1280)/280)**2)+.3*np.exp(-((hz-2650)/500)**2))/h**.45
   v+=np.sin(ph*h+voice*.9)*gain
  v+=sosfilt(butter(2,[550,3500],btype='bandpass',fs=sr,output='sos'),rng.normal(size=len(t)))*.25
  x+=np.tanh(v*1.5)*env/5
 return x*.8
for bar in range(bars):
 t=bar*4*beat;busy=bar>=16 and not 32<=bar<40
 hits=[(0,1),(.75,.4),(1.5,.7),(2,.9),(2.75,.45),(3.5,.75)] if busy else [(0,1),(1.5,.55),(2,.8),(3.5,.55)]
 for j,(step,gain) in enumerate(hits):put(drum(.85 if j%2==0 else 1.3),t+step*beat,.40*gain,(-.25 if j%2 else .25))
 # Low ensemble rolls and metallic swells into each eight-bar phrase.
 if bar%8==7:
  for step in range(8):put(drum(1.5),t+(2+step*.25)*beat,.05+.013*step,(-.5 if step%2 else .5))
  tt=np.arange(round(sr*1.2))/sr;noise=rng.normal(size=len(tt));cym=sosfilt(butter(2,3000,btype='highpass',fs=sr,output='sos'),noise)*np.sin(np.pi*tt/1.2)**2
  put(cym,t+3*beat,.055)
for bar in [6,14,22,30,38,44]:
 put(shout(1.45,bar%3),bar*4*beat+beat,.13,-.4)
 put(shout(1.7,1),(bar*4+1.3)*beat,.11,.4)
# Short hall reflections retain drum attack; stereo reverb tail wraps musically.
for delay,gain in [(.071,.10),(.137,.075),(.243,.05),(.411,.025)]:mix+=np.roll(mix[:,::-1],round(delay*sr),axis=0)*gain
mix=np.tanh(mix*1.15);mix*=.82/max(float(np.max(abs(mix))),1e-5)
# 8 ms edge taper prevents clicks without a long drop in menu intensity.
edge=round(.008*sr);mix[:edge]*=np.linspace(0,1,edge)[:,None];mix[-edge:]*=np.linspace(1,0,edge)[:,None]
path=r/'audio/music/menu_theme.wav'
with wave.open(str(path),'wb') as w:w.setnchannels(2);w.setsampwidth(2);w.setframerate(sr);w.writeframes((mix*32767).astype('<i2').tobytes())
subprocess.run(['ffmpeg','-y','-loglevel','error','-i',str(path),'-af','loudnorm=I=-16:TP=-1.5:LRA=8','-ar','44100','-c:a','libvorbis','-q:a','6',str(path.with_suffix('.ogg'))],check=True)
path.unlink()
meta={'title':'The Siege Awakens','version':16,'bpm':bpm,'seconds':duration,'key':'D minor','arrangement':'War drums, timpani, celli ostinato, strings, horns, trombones, choir and synthetic battle cries','soundfont':'TimGM6mb by Tim Brechbill and David Bolton','license':'GPL-2.0-only; see audio/licenses/MenuTheme-GPL-2.txt','source':'authoring/create_war_menu.py; authoring/soundfonts/TimGM6mb.sf2','borrowed_songs':False,'synthetic_battle_cries':True}
(r/'data/menu_music_v16.json').write_text(json.dumps(meta,indent=2));print(json.dumps(meta),flush=True)
