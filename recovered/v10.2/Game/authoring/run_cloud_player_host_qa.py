import subprocess,time,os,json,sys,pathlib,signal
BASE=pathlib.Path(__file__).resolve().parent
if (BASE/'project/project.godot').exists():ROOT=BASE;PROJECT=ROOT/'project'
else:
 PROJECT=BASE.parent;ROOT=PROJECT.parent/'v40-qa-work';ROOT.mkdir(exist_ok=True)
case=sys.argv[1] if len(sys.argv)>1 else 'peer'
BINARY=os.environ.get('NEST_QA_BINARY','')
CLIENT_CMD=[BINARY,'--headless'] if BINARY else ['godot','--headless','--path',str(PROJECT),'--script','tests/hybrid/client.gd']
WORKER_CMD=os.environ.get('NEST_QA_WORKER_COMMAND',f'godot --headless --path {PROJECT} --script tests/hybrid/worker.gd')
OUT=ROOT/'results'/case
OUT.mkdir(parents=True,exist_ok=True)
for pattern in ("client*.json","fire-*","finish"):
 for stale in OUT.glob(pattern):stale.unlink()
processes=[]
def launch(cmd,name,env=None):
 f=open(OUT/(name+'.log'),'w');p=subprocess.Popen(cmd,stdout=f,stderr=subprocess.STDOUT,env=env);f.close();processes.append(p);return p
def states():
 result={}
 for i in range(6):
  try:result[i]=json.loads((OUT/f'client{i}.json').read_text())
  except (OSError,ValueError):pass
 return result
def wait(test,seconds=100):
 deadline=time.time()+seconds
 while time.time()<deadline:
  s=states()
  if test(s):return s
  time.sleep(.25)
 raise RuntimeError('Timeout: '+json.dumps(states()))
try:
 print('Using separately running Cloudflare runtime',flush=True)
 clients={}
 for i in range(6):
  if i==5:
   wait(lambda s:len(s)==5 and all(x['phase']=='queue' and x['actors']==0 for x in s.values()),30)
   print('PASS five humans stay queued; no starting bots',flush=True)
  env=os.environ.copy();env['NEST_QA_VERBOSE']='1';env['NEST_QA_FIXTURE_SCRIPT']=str(PROJECT/'tests/hybrid/fixture.gd');env['XDG_DATA_HOME']=str(OUT/f'user{i}')
  clients[i]=launch(CLIENT_CMD+['--','--qa-hybrid-client','--hub','ws://127.0.0.1:18080/v1/matchmaking','--name',f'Human{i}','--status',str(OUT/f'client{i}.json')],f'client{i}',env)
  time.sleep(.15)
 s=wait(lambda s:len(s)==6 and all(x['running'] and not x['frozen'] and x['actors']==6 for x in s.values()))
 if case=='dedicated':assert not any(x['authority'] for x in s.values()),'Dedicated allocation unexpectedly fell back'
 print('PASS six real headless Godot clients, authenticated DTLS admission, all-player load barrier, six actors; case',case,flush=True)
 initial_epoch=max(x['epoch'] for x in s.values());
 (OUT/'fixture').write_text('apply')
 wait(lambda s:len(s)==6 and all(x.get('health')==17 and x.get('ammo',[0])[0]==11 and x['scores']==[7,5] for x in s.values()))
 time.sleep(4)
 wait(lambda s:all(x['checkpoint'] for x in s.values()))
 print('PASS quorum checkpoint committed',flush=True)
 killed_at=time.monotonic()
 host=next((i for i,x in s.items() if x['authority']),None)
 if case in ('peer','offline'):
  assert host is not None
  clients[host].kill();clients[host].wait()
 else:
  # Find only this test's dynamically allocated dedicated child.
  pid_text=subprocess.check_output(['pgrep','-P',str(hub.pid)],text=True).split();assert pid_text
  os.kill(int(pid_text[0]),signal.SIGKILL);host=-1
 s=wait(lambda s:all(x['running'] and not x['frozen'] and x['epoch']>initial_epoch and x['actors']==6 for i,x in s.items() if i!=host),100)
 survivors=[x for i,x in s.items() if i!=host];assert sum(x['authority'] for x in survivors)==1
 print('Measured local migration pause: %.2f seconds'%(time.monotonic()-killed_at),flush=True)
 print('PASS killed authority process, elected one surviving player-host, restored same six-slot match and resumed at new epoch',flush=True)
 time.sleep(3)
 s=states();assert all(x.get('health')==17 and x.get('ammo',[0])[0]==11 and x['scores']==[7,5] for i,x in s.items() if i!=host),s
 assert all(x.get('sequence',0)>2 for i,x in s.items() if i!=host and not x['authority']),s
 print('PASS post-migration health, ammunition, score and client commands preserved',flush=True)
 if case in ('peer','offline'):
  (OUT/f'client{host}.json').unlink()
  env=os.environ.copy();env['NEST_QA_VERBOSE']='1';env['NEST_QA_FIXTURE_SCRIPT']=str(PROJECT/'tests/hybrid/fixture.gd');env['XDG_DATA_HOME']=str(OUT/f'user{host}')
  clients[host]=launch(CLIENT_CMD+['--','--qa-hybrid-client','--hub','ws://127.0.0.1:18080/v1/matchmaking','--name',f'Human{host}','--status',str(OUT/f'client{host}.json')],f'rejoin{host}',env)
  s=wait(lambda s:len(s)==6 and all(x['running'] and not x['frozen'] and x['epoch']>initial_epoch and x.get('health')==17 and x.get('ammo',[0])[0]==11 for x in s.values()),60)
  assert sum(x['authority'] for x in s.values())==1
  print('PASS departed host rejoins its original identity and state; no duplicate player',flush=True)
 shooter=next(i for i,x in s.items() if not x['authority']);slot=str(s[shooter]['slot'])
 (OUT/f'fire-Human{shooter}').write_text('one shot')
 s=wait(lambda s:any(x['authority'] and x['roster_state'].get(slot,{}).get('ammo',[0])[0]==10 and x['roster_state'].get(slot,{}).get('shots',0)>=1 for x in s.values()),20)
 print('PASS remote firing after migration reaches new authority and spends exactly one round',flush=True)
 if case=='peer':
  (OUT/'finish').write_text('finish')
  wait(lambda s:len(s)==6 and all(not x['running'] and x['phase'] in ('queue','probing','voting') for x in s.values()),65)
  print('PASS completed match returns six humans to a fresh queue/vote without stale authority',flush=True)
 (OUT/'RESULT.txt').write_text('PASS: six real Godot clients, DTLS authentication/load barrier, quorum checkpoint, authority kill, migration and resume. Local loopback only.\n')
except Exception as e:
 print('FAIL',e,flush=True);sys.exit(1)
finally:
 # Clean up any dedicated child before terminating its orchestrator.
 if 'hub' in locals() and hub.poll() is None:
  found=subprocess.run(['pgrep','-P',str(hub.pid)],capture_output=True,text=True)
  for child in found.stdout.split():
   try:os.kill(int(child),signal.SIGTERM)
   except ProcessLookupError:pass
 for p in processes:
  if p.poll() is None:p.terminate()
 for p in processes:
  try:p.wait(timeout=8)
  except subprocess.TimeoutExpired:p.kill();p.wait()
