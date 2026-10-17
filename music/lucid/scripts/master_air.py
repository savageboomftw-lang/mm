# master: soften 2-6 kHz, loudness to -14 LUFS (streaming level), look-ahead peak limiter at about -1 dBFS
import numpy as np, soundfile as sf, pyloudnorm as pyln, sys
from scipy.signal import butter, sosfilt
x,SR=sf.read(sys.argv[1]); x=np.atleast_2d(x.T).T
x=x+.25*sosfilt(butter(2,6000,"high",fs=SR,output="sos"),x,axis=0)   # a little air instead of the 2-6 kHz trim
meter=pyln.Meter(SR); x=pyln.normalize.loudness(x,meter.integrated_loudness(x),-14.0)
ceil=10**(-1/20); la=int(.005*SR)
peak=np.max(np.abs(x),1); peak=np.maximum.accumulate(np.lib.stride_tricks.sliding_window_view(np.pad(peak,(0,la)),la+1).max(1)[None,:],0)[0]
g=np.minimum(1,ceil/np.maximum(peak,1e-9))
rel=np.exp(-1/(.08*SR)); gs=np.empty_like(g); cur=1.
for i,v in enumerate(g): cur=v if v<cur else v+(cur-v)*rel; gs[i]=cur   # instant attack (look-ahead), 80 ms release
x=np.clip(x*gs[:,None],-ceil,ceil)
sf.write(sys.argv[2],x,SR,subtype='PCM_16')
print('loudness %.1f LUFS, peak %.2f dBFS, limiting on %.1f%% of samples'%(meter.integrated_loudness(x),20*np.log10(np.abs(x).max()),100*np.mean(gs<.999)))
