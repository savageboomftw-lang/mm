# drop the recorded verse into the instrumental, one sung line per lyric slot, with light genre-style vocal processing
import numpy as np, librosa, wave, sys
from scipy.signal import butter, sosfilt, fftconvolve
SR=44100; SLOT=8*60/100; rng=np.random.default_rng(2)
inst,_=librosa.load(sys.argv[6] if len(sys.argv)>6 else 'full_song_instrumental.wav',sr=SR,mono=False); inst=inst.T
# every sung line from every take: (take file, line start, line end in the take, song slot)
TAKES={'verse':'rec2/v_pastel.wav','chorus':'rec3/v_pastel.wav'}
V=[5.92,9.96,16.72,20.24,26.55,31.67]; VE=V[1:]+[36.0]           # take 2: verse 1 + pre-chorus
C=[3.19,9.03,15.98,21.68]; CE=C[1:]+[24.4]                          # take 3: chorus (reused for all three choruses)
LINES=[('verse',p,e,s_) for p,e,s_ in zip(V,VE,[4,6,8,10,12,14])]
for c0 in (16,40,52): LINES+=[('chorus',p,e,c0+2*j) for j,(p,e) in enumerate(zip(C,CE))]
SLOTS=[l[3] for l in LINES]
hp=lambda x,fc: sosfilt(butter(2,fc,'high',fs=SR,output='sos'),x)
lp=lambda x,fc: sosfilt(butter(2,fc,'low',fs=SR,output='sos'),x)
src={k:librosa.load(f,sr=SR,mono=True)[0] for k,f in TAKES.items()}
vtrack=np.zeros(len(inst))
for take,p0,p1,slot in LINES:
    seg=src[take][int((p0-.15)*SR):int((p1-.1)*SR)]
    seg=hp(seg,90)*np.minimum(1,np.arange(len(seg))/(.02*SR))*np.minimum(1,(len(seg)-np.arange(len(seg)))/(.08*SR))
    seg=seg/np.sqrt(np.mean(seg[np.abs(seg)>np.abs(seg).max()*.05]**2))   # even out line-to-line level
    a=int((slot*SLOT-.15)*SR); seg=seg[:len(vtrack)-a]; vtrack[a:a+len(seg)]+=seg
vtrack=np.tanh(.35*vtrack)                                    # gentle compression
import sys
DUCK=float(sys.argv[5]) if len(sys.argv)>5 else .3
FX=sys.argv[1]; N=len(vtrack); tt=np.arange(N)/SR; beat=60/100
bp=lambda x,lo,hi: sosfilt(butter(2,[lo,hi],'band',fs=SR,output='sos'),x)
def vdelay(x,d): return np.interp(np.arange(len(x))-d*SR,np.arange(len(x)),x,left=0)
def octave_up(x,G=4096):
    y=np.zeros(len(x)); w=np.hanning(G)
    for i in range(0,len(x)-2*G,G//4): y[i:i+G]+=x[i:i+2*G:2]*w
    return y
def reverb(x,secs,decay,bright,seed):
    r=np.random.default_rng(seed); L=int(secs*SR); ir=lp(r.standard_normal(L),bright)*np.exp(-np.arange(L)/SR*decay); ir[:int(.03*SR)]=0
    return fftconvolve(x,ir)[:len(x)]
n=lambda x: x/(np.abs(x).max()+1e-12)
x=vtrack
if FX=='dream':        # chorus, dotted-8th ping-pong echo, long dark reverb, faint octave-up shimmer
    L_=x+.5*vdelay(x,.012+.003*np.sin(2*np.pi*.5*tt)); R_=x+.5*vdelay(x,.016+.003*np.sin(2*np.pi*.5*tt+2))
    dry=np.stack([L_,R_],1); d=int(.75*beat*SR); echo=np.zeros_like(dry); e=x.copy()
    for k in range(1,5): e=lp(e,5000)*.45; echo[d*k:,k%2]+=e[:-d*k]
    sh=lp(octave_up(x),8000)
    wet=np.stack([reverb(x+.4*sh,4,1.2,4500,c) for c in (0,1)],1)
    v=n(dry)+.5*n(echo)+.6*n(wet); LEVEL=.75
elif FX=='shoegaze':   # detuned double + tape wobble, reverse-reverb swells, big dark wash, buried
    w=lambda ph: vdelay(x,.008+.0012*np.sin(2*np.pi*.7*tt+ph)+.0002*np.sin(2*np.pi*6*tt+ph))
    dry=np.stack([w(0)+.7*w(2),w(1)+.7*w(3)],1)
    rr=np.stack([reverb(x[::-1],2,2.5,5000,c)[::-1] for c in (0,1)],1)       # swells that rise into each word
    wet=np.stack([reverb(dry[:,c],5,.9,3500,c+5) for c in (0,1)],1)
    v=np.stack([lp(c_,5000) for c_ in (n(dry)+.35*n(rr)+.85*n(wet)).T],1); LEVEL=.6
elif FX=='clear':      # dry voice clear and centred; all the effects on a send that ducks while singing and blooms in gaps
    dry1=hp(x,120); dry1=dry1+3*bp(dry1,2000,5000)                          # consonant presence
    env=np.convolve(np.abs(x),np.ones(int(.05*SR))/int(.05*SR),'same'); env=env/env.max()
    sing=np.clip(env*6,0,1)                                                  # 1 while singing, 0 in gaps
    w=lambda ph: vdelay(x,.008+.0012*np.sin(2*np.pi*.7*tt+ph)+.0002*np.sin(2*np.pi*6*tt+ph))
    dbl=np.stack([w(0),w(2)],1)                                              # detuned doubles, hard L/R
    rr=np.stack([reverb(x[::-1],2,2.5,5000,c)[::-1] for c in (0,1)],1)      # reverse swells into words
    d=int(.75*beat*SR); echo=np.zeros((N,2)); e=x.copy()
    for k in range(1,5): e=lp(e,5000)*.45; echo[d*k:,k%2]+=e[:-d*k]          # dotted-8th ping-pong
    sh=lp(octave_up(x),8000)
    pre=int(.08*SR); big=np.stack([np.concatenate([np.zeros(pre),reverb(x+.4*sh,4,1.1,4500,c)[:-pre]]) for c in (0,1)],1)  # 80 ms pre-delay
    send=.35*n(dbl)+.3*n(rr)+.45*n(echo)+.8*n(big)
    send*=(1-DUCK*sing)[:,None]                                              # duck under the words (DUCK from argv[5])
    plate=np.stack([reverb(dry1,.9,6,7000,c+11) for c in (0,1)],1)            # short plate on the main voice: space without smear
    wv=np.stack([reverb(wtrack,2.5,1.5,8000,21),reverb(wtrack,2.5,1.5,8000,22)],1)   # whispers float in the reverb, left and right
    wv=wv*np.array([[1.2,.6]])   # lean left
    v=np.stack([n(dry1)]*2,1)+.35*n(plate)+.9*n(send); LEVEL=.7   # whispers removed at the user's request
    # carve a pocket in the music (1.5-4.5 kHz, about -4 dB) only while singing
    a0=int(4*SLOT*SR); m_=np.zeros(len(inst)); m_[:N]=sing
    band=np.stack([bp(inst[:,c],1500,4500) for c in (0,1)],1); inst=inst-.85*band*m_[:,None]
elif FX=='bathroom':   # heard through the bathroom door: tiled-room reflections, boxy resonance, muffled top, a little wash
    x=vdelay(x,.004+.0015*np.sin(2*np.pi*.45*tt))                              # gentle cassette warble on the whole vocal
    room=x.copy()
    for ms,g in ((7,.6),(11,.5),(17,.45),(23,.35),(31,.3),(43,.22)):         # tight early reflections off tiles
        d_=int(ms/1000*SR); room[d_:]+=g*x[:-d_]*(1 if ms%2 else -1)
    room=room+.8*reverb(room,.9,5.5,9000,31)                                   # short, dense, bright tile ring
    room=room+.6*bp(room,300,550)                                              # small-room boxiness
    door=lp(lp(room,2500),2500)                                                # door half open: 4th-order low-pass at 2.5 kHz
    # 1) the door swings open in the choruses (slots 16-23, 40-47, 52-59): clear, full and a little louder
    opened=np.zeros(N)
    for c0,c1 in ((16,24),(40,48),(52,60)): opened[int(c0*SLOT*SR):int(c1*SLOT*SR)]=1
    w_=int(.4*SR); opened=np.convolve(opened,np.ones(w_)/w_,'same')
    # chorus (door open), Pastel Ghost style: airy and breathy, then a detuned double-tracked cloud and shimmer reverb (added below)
    clear=hp(x,120)+.5*bp(x,2000,5000)+.9*hp(hp(x,6000),6000)+.2*reverb(x,1.2,4,8000,33)   # presence + lots of air
    door=n(door)*(1-opened)+1.2*n(clear)*opened
    cl=lambda ph,rate,base: vdelay(clear,base+.003*np.sin(2*np.pi*rate*tt+ph))           # each copy drifts in pitch and time
    cloud=np.stack([cl(0,.31,.014)+cl(2,.43,.022),cl(1,.37,.017)+cl(3,.29,.026)],1)*opened[:,None]
    big=np.stack([reverb(clear,5,.8,6000,c+60) for c in (0,1)],1)
    shimmer=np.stack([lp(octave_up(big[:,c]),8000) for c in (0,1)],1)
    pump=np.ones(N)                                                                    # chillwave pump: the wash breathes with the kick
    for bar in range(int(N/SR/(4*beat))+1):
        for kb in (0,1.5,2):
            k0=int((bar*4+kb)*beat*SR); L_=int(.4*SR)
            if k0<N: pump[k0:k0+L_]=np.minimum(pump[k0:k0+L_],(1-.4*np.exp(-np.arange(L_)/SR/.18))[:N-k0])
    bloom=(n(big)+.35*n(shimmer))*(opened*pump)[:,None]
    # 4) reverse swell rising into the first word of every line
    rs=np.zeros(N)
    for sl in SLOTS:
        a_=int((sl*SLOT-.15)*SR); first=x[a_:a_+int(.6*SR)]
        sw=reverb(np.concatenate([first,np.zeros(int(2*SR))]),2,2.2,6000,50)[::-1]; sw=lp(sw,2500)
        b_=max(0,a_-len(sw)+int(.05*SR)); rs[b_:b_+len(sw)]+=sw[:N-b_][:a_+int(.05*SR)-b_]
    # 2) tape echo: dotted-8th repeats, darker and wobblier each time, mostly heard in the gaps
    d_=int(.75*beat*SR); echo=np.zeros((N,2)); e=door.copy()
    for k in range(1,5):
        e=lp(e,2600-400*k)*.5; e=vdelay(e,.002*np.sin(2*np.pi*.5*tt+k)+.002); echo[d_*k:,k%2]+=e[:-d_*k]
    sing=np.clip(np.convolve(np.abs(x),np.ones(int(.05*SR))/int(.05*SR),'same')/np.abs(x).max()*6,0,1)
    echo*=(1-.5*sing)[:,None]
    wash=np.stack([reverb(door,4,1.1,3000,c+40) for c in (0,1)],1)
    v=np.stack([n(door)]*2,1)+.35*n(wash)+1.0*n(echo)+.3*np.stack([n(rs)]*2,1)+.6*n(cloud)+.55*n(bloom); LEVEL=.7
elif FX=='animatronic':  # intercom band + drive, ring-mod buzz, bit-crush, warped-tape pitch wobble
    y=vdelay(x,.01+.004*np.sin(2*np.pi*.6*tt))                                 # ~±15 cent warble
    y=np.tanh(2.5*n(bp(y,400,3200)))
    y=.75*y+.25*y*np.sin(2*np.pi*110*tt)*1.6                                   # robotic ring mod
    y=.8*y+.2*np.repeat(np.round(y[::6]*16)/16,6)[:N]                          # light bit-crush
    dry=np.stack([y,vdelay(y,.015)],1); wet=np.stack([reverb(y,1.6,3.5,6000,c) for c in (0,1)],1)
    v=n(dry)+.3*n(wet); LEVEL=.85
# level: vocal RMS ~ 85% of the music RMS over the verse + pre-chorus
a,b=int(4*SLOT*SR),int(16*SLOT*SR); rms=lambda x: np.sqrt(np.mean(x**2))
LEVEL=float(sys.argv[3]) if len(sys.argv)>3 else LEVEL
v*=LEVEL*rms(inst[a:b])/rms(v[a:b])
_b=lambda z: sosfilt(butter(4,[1000,4000],'band',fs=SR,output='sos'),z.mean(1))
print('speech-band voice vs music during verse: %+.1f dB'%(10*np.log10(np.mean(_b(v[a:b])**2)/np.mean(_b(inst[a:b])**2))))
out=inst+v; end=len(out)                              # excerpt: intro, verse 1, pre-chorus, start of the chorus
out=out[:end]
out=out/np.abs(out).max()*.95
w=wave.open(sys.argv[4] if len(sys.argv)>4 else f'verse_vox_{FX}.wav','wb'); w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((out*32767).astype('<i2').tobytes()); w.close()
print('excerpt',round(end/SR,1),'s')
