"""Rebuild v0.6 sampled combat audio from the included licensed source clips.
Requires NumPy and FFmpeg. Neural announcements are already rendered source WAVs;
there is no speech model, audio synthesis or network dependency in the game.
"""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import json,subprocess,hashlib,wave,tempfile,sys
import numpy as np
ROOT=Path(__file__).resolve().parent.parent
MANIFEST=json.loads((ROOT/'data/audio_manifest.json').read_text())
RECIPES=json.loads((ROOT/'data/audio_recipes.json').read_text());SR=RECIPES['sample_rate']
CACHE={}
for recipe in RECIPES['sounds'].values():
 for path in recipe.get('sources',[recipe['source']])+([recipe['second']] if recipe.get('second') else []):
  if path in CACHE:continue
  with wave.open(str(ROOT/path.removeprefix('res://')),'rb') as w:CACHE[path]=np.frombuffer(w.readframes(w.getnframes()),'<i2').astype(np.float64)/32768

def render(job):
 sound_id,entry,path,index=job;spec=RECIPES['sounds'][sound_id];sources=spec.get('sources',[spec['source']]);source=sources[index%len(sources)];x=CACHE[source]
 rate=float(spec.get('rate',1))*(1+(index%3-1)*.008 if not sound_id.startswith('announcer') else 1)
 start=int(spec.get('offset',0)*SR);count=min(int(spec['duration']*SR),int((len(x)-start)/rate));positions=start+np.arange(count)*rate
 sig=np.interp(positions,np.arange(len(x)),x)
 if spec.get('second'):
  other=CACHE[spec['second']];samples=np.interp(np.arange(count)*rate,np.arange(len(other)),other,right=0);sig+=samples*.35
 cutoff=spec.get('lowpass',0)
 if cutoff:
  freq=np.fft.rfftfreq(len(sig),1/SR);sig=np.fft.irfft(np.fft.rfft(sig)/(1+(freq/cutoff)**4),n=len(sig))
 # Soft compression retains the report's transient without source overs.
 sig=np.tanh(sig*1.3);sig*=float(spec.get('gain',.85))*.93/max(.01,abs(sig).max())
 fade=min(int(.012*SR),len(sig)//4);sig[:min(35,len(sig))]*=np.linspace(0,1,min(35,len(sig)))
 if entry.get('loop',False):
  # Match first and final samples with a short crossfade for continuous loops.
  tail=sig[-fade:].copy();head=sig[:fade].copy();blend=np.linspace(0,1,fade);seam=tail*(1-blend)+head*blend;sig[-fade:]=seam;sig[0]=sig[-1]
 else:sig[-fade:]*=np.linspace(1,0,fade)
 target=ROOT/path.removeprefix('res://');target.parent.mkdir(parents=True,exist_ok=True)
 with tempfile.NamedTemporaryFile(suffix='.wav') as tmp:
  with wave.open(tmp.name,'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes((sig*32767).astype('<i2').tobytes())
  subprocess.run(['ffmpeg','-v','error','-y','-i',tmp.name,'-ac','1' if entry.get('spatial',MANIFEST['defaults']['spatial']) else '2','-c:a','libvorbis','-q:a','4',str(target)],check=True)
 return target.stat().st_size
jobs=[(key,entry,path,index) for key,entry in MANIFEST['sounds'].items() if key in RECIPES['sounds'] and (len(sys.argv)==1 or key in sys.argv[1:]) for index,path in enumerate(entry.get('files',[]))]
with ThreadPoolExecutor(max_workers=6) as pool: sizes=list(pool.map(render,jobs))
print('Rendered',len(sizes),'replacement Ogg files,',sum(sizes),'bytes',flush=True)
