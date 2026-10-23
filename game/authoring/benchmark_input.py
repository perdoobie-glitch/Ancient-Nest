from pathlib import Path
import subprocess,os,time,json,ctypes,statistics,argparse
parser=argparse.ArgumentParser(description="Linux X11 synthetic-event benchmark; not hardware latency.")
parser.add_argument("--output",type=Path,default=Path.cwd()/"work/input-benchmark")
parser.add_argument("--display",default=os.environ.get("DISPLAY",":99"))
args=parser.parse_args()
project=Path(__file__).resolve().parent.parent
w=args.output.resolve();w.mkdir(parents=True,exist_ok=True)
for p in [w/'bench-ready', *w.glob('bench-done-*')]:p.unlink(missing_ok=True)
env=os.environ.copy();env.update(DISPLAY=args.display,XDG_DATA_HOME=str(w/'input-bench'))
f=open(w/'input-bench.log','w');proc=subprocess.Popen(['godot','--path',str(project),'--audio-driver','Dummy','--script',str(project/'tests/input_accumulation_benchmark.gd'),'--',str(w)],env=env,stdout=f,stderr=subprocess.STDOUT)
x=ctypes.CDLL('libX11.so.6');xt=ctypes.CDLL('libXtst.so.6');x.XOpenDisplay.restype=ctypes.c_void_p;x.XOpenDisplay.argtypes=[ctypes.c_char_p];d=x.XOpenDisplay(args.display.encode())
if not d:raise RuntimeError('Cannot open the requested X11 display')
x.XFlush.argtypes=[ctypes.c_void_p];xt.XTestFakeRelativeMotionEvent.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_ulong]
injected=[]
for i in range(4):
 end=time.monotonic()+25
 while time.monotonic()<end:
  if (w/'bench-ready').exists() and (w/'bench-ready').read_text()==str(i):break
  time.sleep(.01)
 else:proc.kill();raise RuntimeError('Benchmark did not become ready')
 stamps=[];next_at=time.monotonic()
 for j in range(400):
  stamps.append(time.time_ns()//1000);xt.XTestFakeRelativeMotionEvent(d,1,0,0);x.XFlush(d)
  next_at+=.002;time.sleep(max(0,next_at-time.monotonic()))
 injected.append(stamps);(w/f'bench-done-{i}').write_text('done')
proc.wait(timeout=25);f.close();(w/'bench-injected.json').write_text(json.dumps(injected))
received=json.loads((w/'bench-received.json').read_text());out=[]
def p95(v):return sorted(v)[int(.95*(len(v)-1))] if v else None
for r,sent in zip(received,injected):
 lag=[];count=0;draw_lag=[];total_lag=[]
 for cb in r['callbacks']:
  dx=round(cb['dx'])
  if dx<=0:continue
  start=count;count+=dx
  draws=[t for t in r['draws'] if t>=cb['at_us']]
  # A merged callback represents every count in its batch, not just the latest.
  for timestamp in sent[start:min(count,len(sent))]:
   lag.append((cb['at_us']-timestamp)/1000)
   if draws:
    draw_lag.append((draws[0]-cb['at_us'])/1000)
    total_lag.append((draws[0]-timestamp)/1000)
 out.append({'accumulated':r['accumulated'],'injected_events':len(sent),'callbacks':len(r['callbacks']),'received_counts':count,'draws':len(r['draws']),'all_injection_to_callback_median_ms':statistics.median(lag) if lag else None,'all_injection_to_callback_p95_ms':p95(lag),'callback_to_frame_post_draw_median_ms':statistics.median(draw_lag) if draw_lag else None,'callback_to_frame_post_draw_p95_ms':p95(draw_lag),'injection_to_frame_post_draw_median_ms':statistics.median(total_lag) if total_lag else None,'injection_to_frame_post_draw_p95_ms':p95(total_lag)})
(w/'input-benchmark-summary.json').write_text(json.dumps(out,indent=2));print(json.dumps(out,indent=2))
