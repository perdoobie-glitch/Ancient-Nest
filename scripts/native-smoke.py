"""Two native Godot clients against a loopback-only guest test coordinator. Not WAN certification."""
from pathlib import Path
import subprocess, tempfile, os, time, json
ROOT=Path(__file__).resolve().parents[1]
def main():
    with tempfile.TemporaryDirectory(prefix='ancient-native-') as directory:
        out=Path(directory); processes=[]; logs=[]
        env=os.environ.copy();env['NEST_CF_STATE']=str(out/'master');env['NEST_QA_SHARED_CPU']='1'
        def start(args,name,environment):
            log=(out/(name+'.log')).open('w');logs.append(log)
            p=subprocess.Popen(args,cwd=ROOT,env=environment,stdout=log,stderr=subprocess.STDOUT);processes.append(p);return p
        try:
            start(['node','matchmaking/tests/local-server.mjs'],'server',env)
            deadline=time.monotonic()+30
            while 'READY' not in (out/'server.log').read_text():
                if processes[0].poll() is not None or time.monotonic()>deadline:raise RuntimeError('Local coordinator did not start: '+(out/'server.log').read_text()[-2000:])
                time.sleep(.2)
            for i in range(2):
                e=env.copy();e['XDG_DATA_HOME']=str(out/('user'+str(i)))
                # Godot Windows user data isolation for QA; keep live user settings untouched.
                e['APPDATA']=str(out/('appdata'+str(i)))
                start([os.environ.get('GODOT_BIN','godot'),'--headless','--path',str(ROOT/'game'),'--script','res://tests/hybrid/client.gd','--','--qa-hybrid-client','--hub','ws://127.0.0.1:18080/v1/matchmaking','--playlist','duel_1v1','--name','Test'+str(i),'--status',str(out/(str(i)+'.json'))],str(i),e)
            deadline=time.monotonic()+100;states=[]
            while time.monotonic()<deadline:
                try:states=[json.loads((out/(str(i)+'.json')).read_text()) for i in range(2)]
                except (OSError,ValueError):time.sleep(.3);continue
                if all(s['running'] and not s['frozen'] and s['actors']==2 for s in states):
                    assert sum(bool(s['authority']) for s in states)==1
                    print(json.dumps({'passed':True,'clients':2,'one_host':True,'scope':'local native WebRTC, guest QA only','states':states}));return
                if any(p.poll() is not None for p in processes):break
                time.sleep(.3)
            for i in range(2):print((out/(str(i)+'.log')).read_text()[-3000:])
            raise RuntimeError('Native connection failed: '+json.dumps(states))
        finally:
            for p in processes:
                if p.poll() is None:p.terminate()
            for p in processes:
                try:p.wait(timeout=10)
                except subprocess.TimeoutExpired:p.kill();p.wait()
            for log in logs:log.close()
if __name__=='__main__':main()
