from pathlib import Path
import math,random,wave,struct,subprocess,json
w=Path('/workspace/work/v19');base=w/'project/audio/sfx/weapons';rate=22050
for kind in ['plasma_br','plasma_auto']:
 folder=base/kind;folder.mkdir(parents=True,exist_ok=True)
 for index,name in enumerate(['shot_1','shot_2','shot_3','shot_distant','dry_fire','reload']):
  rng=random.Random(1900+index);duration=.20 if name.startswith('shot') else .12 if name=='dry_fire' else .70;frames=[];phase=0
  for i in range(int(rate*duration)):
   t=i/rate;x=t/duration;env=min(1,t/.004)*math.exp(-x*(6 if name.startswith('shot') else 3))
   hz=(1300 if kind=='plasma_br' else 1700)*(1-.65*x)*(1+index*.015)
   if name=='reload':hz=240+900*x;env=math.sin(math.pi*x)**2*.5
   if name=='dry_fire':hz=180;env*=.25
   phase+=2*math.pi*hz/rate
   sample=(math.sin(phase)*.6+math.sin(phase*.503)*.2+rng.uniform(-1,1)*.06)*env*.45
   frames.append(struct.pack('<h',int(max(-1,min(1,sample))*32767)))
  tmp=w/(kind+'-'+name+'.wav')
  with wave.open(str(tmp),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes(b''.join(frames))
  subprocess.run(['ffmpeg','-loglevel','error','-y','-i',str(tmp),'-c:a','libvorbis','-q:a','3',str(folder/(name+'.ogg'))],check=True)
print('Original plasma sounds generated')
