from pathlib import Path
import numpy as np
from scipy.io import wavfile
import subprocess
r=Path(__file__).resolve().parents[1];w=r/'authoring/work';w.mkdir(parents=True,exist_ok=True);dest=r/'audio/ambience';dest.mkdir(parents=True,exist_ok=True)
sr=32000;n=sr*18;rng=np.random.default_rng(191)
freq=np.fft.rfftfreq(n,1/sr)
# Periodic shaped broadband rush: low rolling water and soft fine spray.
channels=[]
for j in range(2):
 spectrum=rng.normal(size=len(freq))+1j*rng.normal(size=len(freq))
 shape=(np.maximum(freq,30)/500)**(-.48)*(1-np.exp(-(freq/80)**2))*np.exp(-(freq/6500)**2)
 water=np.fft.irfft(spectrum*shape,n)
 t=np.arange(n)/sr
 water*=.87+.08*np.sin(2*np.pi*5*t/18+j*.5)+.05*np.sin(2*np.pi*13*t/18+j)
 channels.append(water)
a=np.array(channels).T;a=a/np.max(np.abs(a))*.75
wav=w/'waterfall.wav';wavfile.write(wav,sr,(a*32767).astype(np.int16))
subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-c:a','libvorbis','-q:a','4',str(dest/'waterfall.ogg')],check=True)
