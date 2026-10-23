"""Exercise the unmodified exported dedicated server with six real ENet clients.
Usage: python authoring/run_production_server_qa.py --server-binary /path/server.x86_64 --output /tmp/production-qa
Optional --client-binary selects a separately exported QA launcher.
"""
from pathlib import Path
import subprocess,os,time,argparse,json,re
p=argparse.ArgumentParser();p.add_argument('--server-binary',type=Path,required=True);p.add_argument('--client-binary',type=Path);p.add_argument('--output',type=Path,required=True);args=p.parse_args()
project=Path(__file__).resolve().parent.parent;out=args.output.resolve();out.mkdir(parents=True,exist_ok=True);sync=out/'sync';sync.mkdir(exist_ok=True)
for f in sync.iterdir():f.unlink()
children=[];files=[];failure=None;rows=[]
def launch(role,command):
 env=os.environ.copy();env.pop('DISPLAY',None);env['XDG_DATA_HOME']=str(out/'users'/role);env['ANCIENT_NEST_QA_SYNC']=str(sync)
 f=(out/(role+'.log')).open('w');files.append(f);child=subprocess.Popen(command,env=env,stdout=f,stderr=subprocess.STDOUT);children.append((role,child));return child
try:
 server=launch('server',[str(args.server_binary.resolve()),'--headless','--audio-driver','Dummy','--','--port','17960','--bind','127.0.0.1'])
 deadline=time.monotonic()+30
 while 'listening UDP 17960' not in (out/'server.log').read_text():
  if server.poll() is not None:raise RuntimeError('Dedicated server exited before listening')
  if time.monotonic()>deadline:raise TimeoutError('Dedicated server did not announce readiness')
  time.sleep(.1)
 for i in range(6):
  cmd=([str(args.client_binary.resolve()),'--headless','--audio-driver','Dummy','--','--qa-production-server',str(i)] if args.client_binary else ['godot','--headless','--audio-driver','Dummy','--path',str(project),'--script','res://tests/network_production_server.gd','--',str(i)])
  launch('client'+str(i),cmd);time.sleep(.15)
 for role,child in children[1:]:rows.append({'role':role,'exit':child.wait(timeout=110)})
except Exception as error:failure=str(error)
finally:
 for _,child in children:
  if child.poll() is None:child.terminate();child.wait(timeout=5)
 for f in files:f.close()
errors=[];checks=0
for role,_ in children:
 text=(out/(role+'.log')).read_text(errors='replace');checks+=len(re.findall(r'^PASS',text,re.M))
 errors.extend({'role':role,'message':line} for line in text.splitlines() if line.startswith(('ERROR:','SCRIPT ERROR:')))
report={'participants':'unmodified standalone Linux dedicated server + six real automated ENet clients','client_build':'standalone release QA' if args.client_binary else 'source/editor engine','network':'loopback, no injected impairment','checks':checks,'results':rows,'errors':errors,'runner_failure':failure,'server_shutdown':'SIGTERM after checks; not a graceful-shutdown test'}
(out/'results.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2));raise SystemExit(1 if failure or errors or any(x['exit'] for x in rows) else 0)
