"""Reproduce six-client matchmaking in source or a separately exported QA build.
python authoring/run_matchmaking_qa.py --case normal --output /tmp/nest-qa
python authoring/run_matchmaking_qa.py --binary /path/to/QA.x86_64 --case timeout
Only one run may use UDP 17957 at a time. All processes get isolated user data.
"""
from pathlib import Path
import argparse,os,subprocess,time,json,re
p=argparse.ArgumentParser();p.add_argument('--case',choices=['normal','timeout','stalled-rejoin','registration-timeout','results-rejoin'],default='normal');p.add_argument('--output',type=Path,default=Path('work/matchmaking-qa'));p.add_argument('--binary',type=Path);p.add_argument('--engine',default='godot');p.add_argument('--verbose',action='store_true');p.add_argument('--mode',type=int,choices=[0,2,3,4],default=2);p.add_argument('--map',type=int,choices=[0,1],default=1);args=p.parse_args()
project=Path(__file__).resolve().parent.parent
out=args.output.resolve();out.mkdir(parents=True,exist_ok=True);sync=out/'sync';sync.mkdir(exist_ok=True)
for f in sync.iterdir():
 if f.is_file():f.unlink()
flags=[] if args.case=='normal' else ['--'+args.case]
flags += ['--vote-mode='+str(args.mode),'--vote-map='+str(args.map)]
procs=[];files=[]
def launch(role):
 env=os.environ.copy();env['XDG_DATA_HOME']=str(out/'users'/role);env['ANCIENT_NEST_QA_SYNC']=str(sync)
 command=([str(args.binary.resolve()),'--headless','--audio-driver','Dummy','--','--qa-matchmaking-network',*flags,role] if args.binary else [args.engine,*(['--verbose'] if args.verbose and role=='client0' else []),'--headless','--audio-driver','Dummy','--path',str(project),'--script','res://tests/network_matchmaking_v35.gd','--',*flags,role])
 f=(out/(role+'.log')).open('w');files.append(f)
 child=subprocess.Popen(command,env=env,stdout=f,stderr=subprocess.STDOUT);procs.append((role,child))
def gate(name,seconds=35):
 limit=time.monotonic()+seconds
 while not (sync/name).exists():
  if any(child.poll() not in [None,0] for _,child in procs):raise RuntimeError('Process failed before '+name)
  if time.monotonic()>limit:raise TimeoutError('Timed out waiting for '+name)
  time.sleep(.05)
rows=[];failure=None
try:
 launch('server');gate('server-ready')
 if args.case=='registration-timeout':launch('client0')
 else:
  for i in range(5):launch('client'+str(i));time.sleep(.15)
  gate('five-checked');launch('client5')
  if args.case!='timeout':gate('match-live');launch('intruder')
 for role,child in procs:
  code=child.wait(timeout=100);rows.append({'role':role,'exit':code})
except Exception as error:failure=str(error)
finally:
 for _,child in procs:
  if child.poll() is None:child.terminate();child.wait(timeout=5)
 for f in files:f.close()
checks=0;errors=[];shutdown_warnings=[]
for role,_ in procs:
 text=(out/(role+'.log')).read_text(errors='replace');checks+=len(re.findall(r'^PASS',text,re.M))
 for line in text.splitlines():
  if line.startswith('SCRIPT ERROR:') or line.startswith('ERROR:'):
   # Retained resources in fixture shutdown are tracked separately, not hidden.
   (shutdown_warnings if 'resources still in use at exit' in line else errors).append({'role':role,'message':line})
report={'engine':'Godot 4.6.3','case':args.case,'mode':args.mode,'map':args.map,'build':'standalone release QA' if args.binary else 'source/editor engine','participants':('one dedicated server + one real automated ENet client; application registration deliberately unresponsive' if args.case=='registration-timeout' else 'one dedicated server + six real automated ENet client processes; seventh rejected connection where applicable; not six human testers'),'network':'loopback; no injected latency, jitter, or loss','results':rows,'checks':checks,'errors':errors,'shutdown_warnings':shutdown_warnings,'runner_failure':failure}
(out/'results.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
raise SystemExit(1 if failure or errors or any(row['exit']!=0 for row in rows) else 0)
