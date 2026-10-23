from pathlib import Path
import subprocess,os,time,json
BASE=Path(__file__).resolve().parent
if (BASE/'project/project.godot').exists():ROOT=BASE;PROJECT=ROOT/'project'
else:PROJECT=BASE.parent;ROOT=PROJECT.parent/'player-host-qa-work'
OUT=ROOT/'results/capacity-10';OUT.mkdir(parents=True,exist_ok=True);processes=[]
for f in OUT.glob('client*.json'):f.unlink()
(OUT/'RESULT.json').unlink(missing_ok=True)
def states():
 result={}
 for i in range(10):
  try:result[i]=json.loads((OUT/f'client{i}.json').read_text())
  except (ValueError,OSError):pass
 return result

def wait(predicate,seconds):
 until=time.monotonic()+seconds
 while time.monotonic()<until:
  s=states()
  if predicate(s):return s
  time.sleep(.25)
 raise AssertionError(str(states()))
try:
 for i in range(10):
  if i==9:
   wait(lambda s:len(s)==9 and all(x['phase']=='queue' and x['actors']==0 for x in s.values()),35);print('PASS nine humans stay queued in ten-player playlist without bots',flush=True)
  env=os.environ.copy();env['XDG_DATA_HOME']=str(OUT/f'user{i}')
  log=(OUT/f'client{i}.log').open('w')
  p=subprocess.Popen(['godot','--headless','--path',str(PROJECT),'--script','tests/hybrid/client.gd','--','--qa-hybrid-client','--hub','ws://127.0.0.1:18080/v1/matchmaking','--playlist','bomb_defuse_5v5','--name',f'Capacity{i}','--status',str(OUT/f'client{i}.json')],stdout=log,stderr=subprocess.STDOUT,env=env);log.close();processes.append(p);time.sleep(.15)
 s=wait(lambda s:len(s)==10 and all(x['running'] and not x['frozen'] and x['actors']==10 for x in s.values()),100)
 assert sum(x['authority'] for x in s.values())==1
 print('PASS ten real native Godot clients, one elected player host, all ten loaded, ten actors',flush=True)
 time.sleep(min(15,max(0,float(os.environ.get('NEST_QA_HOLD_SECONDS','0')))))
 (OUT/'RESULT.json').write_text(json.dumps({'pass':True,'clients':10,'authorities':1,'actors_each':10,'transport':'native WebRTC','scope':'local Cloudflare runtime and loopback routes'},indent=2))
finally:
 for p in processes:
  if p.poll() is None:p.terminate()
 for p in processes:
  try:p.wait(timeout=8)
  except subprocess.TimeoutExpired:p.kill();p.wait()
