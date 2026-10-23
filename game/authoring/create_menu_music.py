"""Original Ancient Nest menu composition: Sanctuary at Dawn.
A 50.5-second D-minor/Dorian ambient loop, 76 BPM, with plucked strings,
a soft wordless choir, reed melody and restrained hand-drum accents.
No source recordings, copied melodies or runtime synthesis dependencies.
"""
from pathlib import Path
import numpy as np,wave,subprocess,json
ROOT=Path(__file__).resolve().parent.parent;SR=22050;BEAT=60/76;DURATION=64*BEAT;N=int(DURATION*SR);rng=np.random.default_rng(7014);mix=np.zeros((N,2))
def hz(midi):return 440*2**((midi-69)/12)
def put(signal,start,gain,pan=0):
 index=int(start*SR)%N;signal=np.asarray(signal)*gain
 stereo=np.column_stack([signal*np.sqrt((1-pan)/2),signal*np.sqrt((1+pan)/2)])
 # Circular placement retains all late reverb tails across the loop seam.
 for begin in range(0,len(signal),N):
  part=stereo[begin:begin+N];split=min(len(part),N-index);mix[index:index+split]+=part[:split]
  if split<len(part):mix[:len(part)-split]+=part[split:]
def pluck(midi,length=2.6):
 t=np.arange(int(SR*length))/SR;f=hz(midi);sig=np.zeros(len(t))
 for h in range(1,9):sig+=np.sin(2*np.pi*f*h*t+.03*h)*np.exp(-t*(1.2+.32*h))/h**1.7
 return sig*(1-np.exp(-t*120))
def pad(midi,length):
 t=np.arange(int(SR*length))/SR;f=hz(midi);sig=np.zeros(len(t))
 for h in range(1,25):
  formant=.18+np.exp(-((f*h-750)/280)**2)+.6*np.exp(-((f*h-1200)/450)**2)
  sig+=np.sin(2*np.pi*f*h*t+.018*h*np.sin(2*np.pi*.43*t))/h**1.35*formant
 env=np.minimum(t/.9,1)*np.minimum((length-t)/1.7,1);return sig*np.maximum(env,0)*.32
def reed(midi,length):
 t=np.arange(int(SR*length))/SR;f=hz(midi);phase=2*np.pi*f*t+.055*np.sin(2*np.pi*4.4*t)
 sig=np.sin(phase)+.2*np.sin(phase*2)+.08*np.sin(phase*3)
 env=(1-np.exp(-t*8))*np.minimum((length-t)/.55,1);return sig*np.maximum(env,0)
chords=[[50,57,60,64],[46,53,57,62],[48,55,62,64],[43,50,57,58]]
melody=[(0,74,1.6),(2.5,77,1.1),(4,81,1.9),(7,79,1.7),(10,76,1.5),(12.5,77,1.2),(15,74,2.6),(19,72,1.8),(22,74,2.5),(26,69,2.2),(30,72,2.4),(35,74,2.7),(39,77,1.6),(43,76,1.7),(47,74,2.8),(53,72,2.2),(57,69,1.7)]
for block in range(8):
 chord=chords[block%4];start=block*8*BEAT
 for i,note in enumerate(chord):put(pad(note,8*BEAT+1.8),start,.13,[-.55,-.18,.18,.55][i])
 for step in range(8):
  note=chord[(step*3+block)%4]+12
  put(pluck(note),start+step*BEAT,.07,(-.45 if step%2==0 else .45))
 for beat in [0,4]:
  t=np.arange(int(.65*SR))/SR;drum=np.sin(2*np.pi*(65*t-16*t*t))*np.exp(-t*12)
  put(drum,start+beat*BEAT,.055,0)
for onset,note,beats in melody:put(reed(note,beats*BEAT),onset*BEAT,.065,.12)
# A quiet diffuse echo gives distance without a long loud wash.
for delay,gain in [(int(.23*SR),.14),(int(.47*SR),.09),(int(.79*SR),.05)]:mix+=np.roll(mix[:,::-1],delay,axis=0)*gain
mix=np.tanh(mix*1.25);mix*=.72/max(abs(mix).max(),.001)
# Blend the seam across a short shoulder, preserving the underlying progression.
fade=int(.15*SR);tail=mix[-fade:].copy();head=mix[:fade].copy();blend=np.linspace(0,1,fade)[:,None];mix[-fade:]=tail*(1-blend)+head*blend;mix[0]=mix[-1]
source=ROOT/'audio/source/menu_music_original.wav'
with wave.open(str(source),'wb') as w:w.setnchannels(2);w.setsampwidth(2);w.setframerate(SR);w.writeframes((mix*32767).astype('<i2').tobytes())
out=ROOT/'audio/music/menu_music.ogg';out.parent.mkdir(exist_ok=True)
subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-ar','44100','-c:a','libvorbis','-q:a','5',str(out)],check=True)
(ROOT/'data/menu_music_score.json').write_text(json.dumps({'title':'Sanctuary at Dawn','bpm':76,'duration_seconds':DURATION,'chords_midi':chords,'melody_beat_midi_duration':melody,'rights':'Original Ancient Nest composition; no borrowed recordings or melody.'},indent=2)+'\n')
print('Composed original stereo menu loop',round(DURATION,2),'seconds',out.stat().st_size,'bytes')
