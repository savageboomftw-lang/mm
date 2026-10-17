# gentle pitch correction by varispeed: pull each voiced frame ~60% toward the nearest A-flat-major note, smoothed over ~80 ms
# shortcut: varispeed nudges each line's length by a few % (<~0.1 s drift); upgrade to PSOLA if exact timing inside lines matters
import numpy as np, librosa, soundfile as sf, sys
SR=44100; STRENGTH=float(sys.argv[3]) if len(sys.argv)>3 else .6; SCALE=np.array([8,10,0,1,3,5,7])          # Ab Bb C Db Eb F G
PHRASES=[5.92,9.96,16.72,20.24,26.55,31.67]   # take 2 line starts
x,_=librosa.load(sys.argv[1],sr=SR,mono=True); H=256
def nearest(mm):
    base=np.floor(mm/12)*12; c=base[:,None]+np.concatenate([SCALE-12,SCALE,SCALE+12])[None,:]
    return c[np.arange(len(mm)),np.argmin(np.abs(c-mm[:,None]),1)]
f0,v,_=librosa.pyin(x,fmin=70,fmax=900,sr=SR,frame_length=2048,hop_length=H)
m=librosa.hz_to_midi(np.where(v,f0,1.))
corr=np.where(v,STRENGTH*(nearest(m)-m),0.); k=max(1,int((float(sys.argv[4]) if len(sys.argv)>4 else .08)*SR/H)); corr=np.convolve(corr,np.ones(k)/k,'same')
rate=2**(np.interp(np.arange(len(x)),np.arange(len(corr))*H,corr)/12)   # per-sample playback speed
y=x.copy(); bounds=[int((p-.15)*SR) for p in PHRASES]+[len(x)]
for a,b in zip(bounds[:-1],bounds[1:]):        # restart the read head at every line so line starts stay put
    pos=a+np.cumsum(rate[a:b])-rate[a]; pos=pos[pos<b-1]
    seg=np.interp(pos,np.arange(len(x)),x); y[a:b]=0; y[a:a+len(seg)]=seg
sf.write(sys.argv[2],y,SR)
def off(sig):
    f,vv,_=librosa.pyin(sig,fmin=70,fmax=900,sr=SR,frame_length=2048,hop_length=1024); mm=librosa.hz_to_midi(f[vv])
    return np.median(np.abs(nearest(mm)-mm))*100
print('median distance from the key: before %.0f cents, after %.0f cents'%(off(x),off(y)))
