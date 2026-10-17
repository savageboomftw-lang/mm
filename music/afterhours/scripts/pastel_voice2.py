# Pastel Ghost-style voice: soft glassy vocoder + whisper layer + airy octave-up ghost + gentle tune + lo-fi tape
import numpy as np, librosa, soundfile as sf
from scipy.signal import butter, sosfilt
SR=44100; H=256; rng=np.random.default_rng(6)
x,_=librosa.load('rec2/src_tuned.wav',sr=SR,mono=True)               # gentle (60%) correction, not the hard snap
bp=lambda z,lo,hi: sosfilt(butter(2,[lo,hi],'band',fs=SR,output='sos'),z)
lp=lambda z,fc: sosfilt(butter(2,fc,'low',fs=SR,output='sos'),z)
n=lambda z: z/(np.abs(z).max()+1e-12)
SCALE=[8,10,0,1,3,5,7]
f0,v,_=librosa.pyin(x,fmin=70,fmax=900,sr=SR,frame_length=2048,hop_length=H)
m=np.round(librosa.hz_to_midi(np.where(v,f0,1.)))
deg=np.array([SCALE.index(int(p)%12) if int(p)%12 in SCALE else 0 for p in m])
step=lambda k: np.array([(SCALE[(d+k)%7]-SCALE[d])%12 for d in deg])
ps=lambda a: np.interp(np.arange(len(x)),np.arange(len(a))*H,a)
root=ps(np.where(v,m,0.)); voiced=ps(v.astype(float))
hzf=lambda mm: 440*2**((mm-69)/12)*(mm>0)
def glass(f):   # sine + a little 2nd/3rd harmonic: soft, glassy, no buzz
    p=2*np.pi*np.cumsum(f)/SR; return np.sin(p)+.3*np.sin(2*p)+.12*np.sin(3*p)
edges=np.geomspace(100,8000,21)
def vocode(carrier,env_hz):
    o=np.zeros(len(x))
    for lo,hi in zip(edges[:-1],edges[1:]): o+=bp(carrier,lo,hi)*np.maximum(lp(np.abs(bp(x,lo,hi)),env_hz),0)
    return n(o)
chord=(glass(hzf(root))+.7*glass(hzf(root+ps(step(2))))+.6*glass(hzf(root+ps(step(4))))+.5*glass(hzf(root+12)))*voiced
soft_voc=vocode(chord,8)                                             # slow envelope: floats between syllables
whisper=vocode(rng.standard_normal(len(x)),25)                      # the words re-made from breath
y=.45*soft_voc+.3*whisper+.45*n(x)                          # real voice keeps the words readable
tt=np.arange(len(y))/SR; y=np.interp(np.arange(len(y))-(.004+.0012*np.sin(2*np.pi*.5*tt))*SR,np.arange(len(y)),y,left=0)  # tape wow
y=np.tanh(1.2*n(lp(y,7500)))                                         # soft top end + gentle saturation
sf.write('rec2/v_pastel.wav',n(y),SR)
sf.write('rec2/whisper.wav',whisper,SR)   # used for the whispered echoes in the gaps
