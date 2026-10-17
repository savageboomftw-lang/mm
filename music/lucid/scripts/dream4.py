# "dreams / sleep" song in the style of Iris: tuned sub booms on every beat, a low drone, falling "dives", glassy bell melody, airy pads
import numpy as np, wave, sys, librosa
from scipy.signal import butter, sosfilt, fftconvolve
SR=44100; SLOW=.85; BPM=108/SLOW; beat=60/BPM; s16=beat/4; BAR=4*beat; SLOT=2*BAR   # slot = 2 bars = one chord
SECTIONS=[('I',4),('V',8),('C',8),('B',2),('V',8),('C',8),('B',2),('C',8),('O',4)]   # third chorus for a bigger ending                    # in slots
slots=[(n,k) for n,c in SECTIONS for k in range(c)]; NS=len(slots)
TR=-12*np.log2(SLOW); N=int(NS*SLOT*SR)+SR*6; rng=np.random.default_rng(21); tt=np.arange(N)/SR
hz=lambda m:440*2**((np.asarray(m)+TR-69)/12)
lp=lambda x,fc,o=2: sosfilt(butter(o,fc,'low',fs=SR,output='sos'),x,axis=0)
hp=lambda x,fc,o=2: sosfilt(butter(o,fc,'high',fs=SR,output='sos'),x,axis=0)
bp=lambda x,lo,hi: sosfilt(butter(2,[lo,hi],'band',fs=SR,output='sos'),x,axis=0)
norm=lambda x: x/(np.abs(x).max()+1e-12)
def put(bus,x,t0,g=1.):
    a=int(t0*SR); x=x[:max(0,N-a)]; bus[a:a+len(x)]+=x*g
saw=lambda curve,c=0.: 2*(np.cumsum(hz(curve+c/100))/SR%1)-1
def vdelay(x,d): return np.interp(np.arange(len(x))-d*SR,np.arange(len(x)),x,left=0)
# chords: (root, third, colour tone above the root+24 voicing)
PROG=[(37,4,11),(39,4,9),(36,3,10),(41,3,14)]          # Dbmaj7, Eb6, Cm7, Fm9: the bittersweet lift
chord=lambda i: PROG[slots[i][1]%4]
root=np.zeros(N); third=np.zeros(N); colour=np.zeros(N); prev=41
for i in range(NS):
    r,th,co=chord(i); a=int(i*SLOT*SR); z=int((i+1)*SLOT*SR); g=int(.12*SR)
    root[a:a+g]=np.linspace(prev,r,g); root[a+g:z]=r; third[a:z]=th; colour[a:z]=co; prev=r
root[z:]=prev; third[z:]=third[z-1]; colour[z:]=colour[z-1]
def env_by_slot(f,sm=.3):
    e=np.zeros(N)
    for i,(n,k) in enumerate(slots): e[int(i*SLOT*SR):int((i+1)*SLOT*SR)]=f(n,k)
    w=int(sm*SR); return np.convolve(e,np.ones(w)/w,'same')
# dives: the pads fall an octave over the last 2 bars of a section (and over the whole outro) - "falling asleep"
dive=np.zeros(N)
for i,(n,k) in enumerate(slots):
    last=(i==NS-1) or slots[i+1][1]==0
    if n=='O': a=int(i*SLOT*SR); L=int(SLOT*SR); dive[a:a+L]=np.linspace(-12*k/4,-12*(k+1)/4,L)
    elif last and n in 'VC': a=int((i*SLOT+BAR)*SR); L=int(BAR*SR); dive[a:a+L]=np.linspace(0,-12,L)
dive[int(NS*SLOT*SR):]=-12
# pads: airy, detuned, chorused; they follow the dive
PAD={'I':.8,'V':.7,'C':1,'B':.9,'O':.9}
pe=env_by_slot(lambda n,k: PAD[n],.5)
pad=sum(saw(root+24+iv+dive,c) for iv in (0,7,12) for c in (-12,0,12))+sum(saw(root+24+third+dive,c)+.7*saw(root+24+colour+dive,c) for c in (-9,9))
cut=2400*np.exp(dive/12*1.2)                                          # filter closes as it dives
pad=(lp(pad,900)+(lp(pad,2400)-lp(pad,900))*(.55+.45*np.sin(2*np.pi*tt/10.0)))*pe;   # slow inhale/exhale
pad=pad; pad=np.where(dive<0,lp(pad,700)*(1-np.exp(dive/12*1.5))+pad*np.exp(dive/12*1.5),pad)
pads=np.stack([pad+.7*vdelay(pad,.008+.003*np.sin(2*np.pi*.4*tt)),pad+.7*vdelay(pad,.011+.003*np.sin(2*np.pi*.4*tt+2))],1)
# drone: a low F held under everything
drone=(np.sin(2*np.pi*np.cumsum(hz(np.full(N,29.)))/SR)+.4*lp(saw(np.full(N,41.)),300))*np.clip(tt/6,0,1)
# sub booms on every beat: tuned to the chord root, pitch drops into the note, long ring
booms=np.zeros(N); boom_t=[]
for i,(n,k) in enumerate(slots):
    if n in 'IO' or n=='B': continue
    r=chord(i)[0]
    for q in range(8):
        L=int(.7*SR); t_=np.arange(L)/SR; bend=2**(10*np.exp(-t_/.035)/12); bend2=2**(3*np.exp(-t_/.06)/12)
        sub=np.sin(2*np.pi*np.cumsum(hz(r-12)*bend)/SR)*np.exp(-t_*3.2)
        pl=sum(g*(2*(np.cumsum(hz(r+iv)*bend2)/SR%1)-1) for iv,g in ((0,1),(7,.7),(12,.6),(12+chord(i)[1],.4)))   # plucked chord on top of the sub
        pl=lp(pl,2500)*np.exp(-t_*14)+lp(pl,450)*np.exp(-t_*4)                                                   # bright click that darkens as it rings
        b_=np.tanh(1.6*sub)+.35*pl/np.abs(pl).max()
        put(booms,b_,i*SLOT+q*beat,(1 if q%2==0 else .85)*(.8 if n=='V' else 1)); boom_t.append(i*SLOT+q*beat)
# soft drums: rim/clap on 2 and 4 (only on 4 in verses), quiet 8th hats, shaker in choruses
dr=np.zeros(N); t=np.arange(int(.4*SR))/SR
clap=lambda: bp(rng.standard_normal(len(t)),900,5000)*np.exp(-t*30)+.4*np.sin(2*np.pi*hz(70)*t)*np.exp(-t*40)
for i,(n,k) in enumerate(slots):
    if n not in 'VC': continue
    for b in range(2):
        t0=i*SLOT+b*BAR
        for q in ((3,) if n=='V' else (1,3)): put(dr,clap(),t0+q*beat+rng.normal(0,.004),.6)
        for e8 in range(8): put(dr,hp(rng.standard_normal(int(.08*SR)),7000)*np.exp(-np.arange(int(.08*SR))/SR*50),t0+e8*beat/2+(.18*s16 if e8%2 else 0),.12 if n=='V' else .18)
        if n=='C':
            for x16 in range(16): put(dr,bp(rng.standard_normal(int(.06*SR)),5000,10000)*np.exp(-np.arange(int(.06*SR))/SR*50),t0+x16*s16,.1 if x16%2 else .16)
# glassy bell melody: long held notes, intro and choruses (and softly in the outro)
MEL={0:[(0,4,84),(4,4,80)],1:[(0,4,82),(4,4,79)],2:[(0,4,79),(4,4,75)],3:[(0,4,80),(4,4,77)]}   # long bell tones (intro, verses, outro)   # (beat, beats, midi) per chord
def bell(m,d):
    L=int((d+3)*SR); t_=np.arange(L)/SR; f=hz(m); idx=2.2*np.exp(-t_*2.5)+.3
    return (np.sin(2*np.pi*f*t_+idx*np.sin(2*np.pi*f*3.5*t_))+.3*np.sin(2*np.pi*f*2*t_))*np.minimum(1,t_/.003)*np.exp(-t_*.7)
bells=np.zeros(N)
for i,(n,k) in enumerate(slots):
    if n not in 'IVO': continue
    for st,ln,m in MEL[k%4]: put(bells,bell(m,ln*beat),i*SLOT+st*beat,.6 if n=='V' else .9)
# chorus hook: soft wide synth lead with a catchy "long-short-up" rhythm, gliding between notes
HOOK={0:[(0,.5,72),(.5,2.5,84),(3,1,82),(4,1,80),(5,3,77)],           # Db: pickup, octave leap up, sigh down
      1:[(0,.5,75),(.5,2.5,87),(3,1,85),(4,1,84),(5,3,82)],           # Eb: same shape a step higher
      2:[(0,.5,79),(.5,1.5,84),(2,1,86),(3,1,84),(4,2,82),(6,2,79)],  # Cm: leans on the 9th (D) before falling
      3:[(0,3,89),(3,1,87),(4,1,84),(5,1,80),(6,2,79)]}               # Fm9: the climax, then floats down unresolved
leadc=np.full(N,np.nan); leadg=np.zeros(N)
for i,(n,k) in enumerate(slots):
    if n not in 'CO': continue
    for st,ln,m in HOOK[k%4]:
        a=int((i*SLOT+st*beat)*SR); z=int((i*SLOT+(st+ln)*beat)*SR); leadc[a:z]=m; leadg[a:z]=.8 if n=='O' else 1
cur=np.nan; lc=np.empty(N)
for j in range(0,N,64):                                            # portamento: glide ~60 ms toward each new note
    tgt=leadc[j]
    if not np.isnan(tgt): cur=tgt if np.isnan(cur) else cur+(tgt-cur)*.45
    lc[j:j+64]=cur if not np.isnan(cur) else 0
vib=.22*np.sin(2*np.pi*5.2*tt)*np.clip(np.convolve(leadg,np.ones(int(.5*SR))/int(.5*SR),'same')*1.5-.5,0,1)   # vibrato blooms on held notes
ge=np.convolve(leadg,np.ones(int(.06*SR))/int(.06*SR),'same')   # softer, sung attack
lead=(lp(sum(saw(lc+vib,c) for c in (-10,0,10)),2800)+.8*np.sin(2*np.pi*np.cumsum(hz(lc+vib))/SR)+.15*bp(rng.standard_normal(N),1500,7000))*ge*(lc>0)   # warm saws + pure tone + breath
leads=np.stack([lead+.6*vdelay(lead,.012),lead+.6*vdelay(lead,.018)],1)
# 16th-note arpeggio sparkle (verses lighter, choruses full)
arp=np.zeros(N); pat=[0,1,2,3,4,3,2,1]
for i,(n,k) in enumerate(slots):
    if n not in 'VCO': continue
    r,th,co=chord(i); tones=[r+36,r+36+th,r+43,r+48,r+36+co]
    for x16 in range(32):
        m=tones[pat[x16%8]]; L=int(.2*SR); tq=np.arange(L)/SR; p_=2*np.pi*hz(m)*tq
        put(arp,(np.sin(p_)+.35*np.sin(2*p_))*np.exp(-tq*16),i*SLOT+x16*s16,(.45 if n=='V' else 1)*(1 if x16%4==0 else .7))
d_=int(.75*beat*SR); pan_=.5+.4*np.sin(2*np.pi*tt/14.0); arps=np.stack([arp*(1-pan_)*2,arp*pan_*2],1)   # slow auto-pan
for k_ in range(1,4): arps[d_*k_:,k_%2]+=lp(arp,4000-700*k_)[:-d_*k_]*.45**k_
# "aah" choir in the choruses
ce=env_by_slot(lambda n,k: 1 if n=='C' else 0,.6)
def aah(curve):
    src_=2*(np.cumsum(hz(curve)*2**(.15*np.sin(2*np.pi*5*tt)/12))/SR%1)-1+.3*rng.standard_normal(N)
    return sum(g*bp(src_,fc*.9,fc*1.1) for fc,g in ((850,1),(1220,.6),(2810,.25)))
choir=(aah(root+36+third)+.8*aah(root+43)+.6*aah(root+48))*ce
strings=lp(sum(saw(root+24+iv,c) for iv in (12,19,24) for c in (-7,7))+sum(saw(root+36+third,c) for c in (-7,7)),1800)*env_by_slot(lambda n,k: 1 if n=='C' else 0,1.5)
# build and release: snare roll + reverse cymbal into each chorus, crash and open hats in the choruses
crash=lambda: hp(rng.standard_normal(int(2.5*SR)),3500)*np.exp(-np.arange(int(2.5*SR))/SR*1.6)
riser=np.zeros(N)
for i,(n,k) in enumerate(slots):
    if n=='C' and k==0:
        for r_ in range(16): put(dr,clap(),i*SLOT-BAR+r_*s16,.08+.04*r_)
        L=int(2*BAR*SR); rc=hp(rng.standard_normal(L),3000)*np.exp(-np.arange(L)/SR*1.2); put(riser,rc[::-1],i*SLOT-2*BAR,.5)
        put(dr,crash(),i*SLOT,.6)
    if n=='C':
        for q in range(8): put(dr,hp(rng.standard_normal(int(.3*SR)),6000)*np.exp(-np.arange(int(.3*SR))/SR*10),i*SLOT+q*beat+beat/2,.2)
# sidechain pump from the booms
duck=np.ones(N)
for b0 in boom_t:
    a=int(b0*SR); L=int(.45*SR); seg=1-.45*np.exp(-np.arange(L)/SR/.2); duck[a:a+L]=np.minimum(duck[a:a+L],seg[:max(0,N-a)])
# the drop-out before the last chorus: one bar of near-silence
gap=np.ones(N)
for i,(n,k) in enumerate(slots):
    if n=='C' and k==0 and i>NS/2: a=int((i*SLOT-BAR)*SR); gap[a:int(i*SLOT*SR)]=.05
gap=np.convolve(gap,np.ones(int(.02*SR))/int(.02*SR),'same')
rswell=np.zeros(N); Lt=int(2.5*SR); irs=lp(rng.standard_normal(Lt),4000)*np.exp(-np.arange(Lt)/SR*1.8)
for i in range(1,NS):
    if slots[i][0] in 'B': continue
    r,th,co=chord(i); Lb=int(.25*SR)
    burst=sum(saw(np.full(Lb,r+iv)) for iv in (24,31,36,36+th))*np.hanning(Lb)
    sw=fftconvolve(burst,irs)[::-1]; put(rswell,lp(sw,3000),i*SLOT-len(sw)/SR)
glass=np.zeros(N); cell=[0,2,1]                                  # 3-beat loop of chord tones against the 4/4 pulse
for i,(n,k) in enumerate(slots):
    if n not in 'VC': continue
    r,th,co=chord(i); tones=[r+48,r+48+th,r+55]
    for q in range(8):
        b0=i*8+q; m=tones[cell[b0%3]]; L=int(1.2*SR); tq=np.arange(L)/SR
        put(glass,(np.sin(2*np.pi*hz(m)*tq)+.2*np.sin(2*np.pi*hz(m)*2.76*tq)*np.exp(-tq*6))*np.exp(-tq*2.2),i*SLOT+q*beat+(beat/2 if b0%3==1 else 0),.6 if n=='V' else .8)
back=(1.3*norm(pads)+.5*norm(arps)+np.stack([.35*norm(choir)+.35*norm(strings)]*2,1)+np.stack([.4*norm(drone)+.2*norm(glass)]*2,1))*duck[:,None]+np.stack([.75*norm(rswell)]*2,1)+np.stack([1.2*norm(booms)+.8*norm(dr)+.4*norm(riser)]*2,1)
keys=(np.stack([bells,vdelay(bells,.013)],1)+.9*norm(leads)*np.abs(bells).max())*duck[:,None]
back*=gap[:,None]; keys*=gap[:,None]
# slowed + big reverb + shimmer, match EQ to the reference, tape wobble
M=int(N/SLOW); src=np.arange(M)*SLOW
Lr=int(6*SR); ir=np.stack([lp(rng.standard_normal(Lr),5000) for _ in (0,1)])*np.exp(-np.arange(Lr)/SR*.9); ir[:,:int(.04*SR)]=0
def slowrev(x,wetg):
    x=np.stack([np.interp(src,np.arange(N),x[:,c]) for c in (0,1)],1)
    wet=np.stack([fftconvolve(x[:,c],ir[c])[:M] for c in (0,1)],1); return norm(x),norm(wet)
bd,bw=slowrev(back,1)
Lr=int(8*SR); ir=np.stack([lp(rng.standard_normal(Lr),5000) for _ in (0,1)])*np.exp(-np.arange(Lr)/SR*.7); ir[:,:int(.06*SR)]=0   # 8 s for the lead/bells
kd,kw=slowrev(keys,1)
def octave_up(x,G=4096):
    y_=np.zeros(len(x)); w_=np.hanning(G)
    for i_ in range(0,len(x)-2*G,G//4): y_[i_:i_+G]+=x[i_:i_+2*G:2]*w_
    return y_
out=bd+.9*bw+.15*norm(np.stack([lp(octave_up(bw[:,c]),7000) for c in (0,1)],1)); keysout=kd+1.1*kw+.25*norm(np.stack([lp(octave_up(kw[:,c]),8000) for c in (0,1)],1))
ref,_=librosa.load('iris/s.wav',sr=SR,mono=True)
def avg_spec(x,n=8192): return np.abs(librosa.stft(x,n_fft=n,hop_length=n//2)).mean(1)**2
fr=np.fft.rfftfreq(8192,1/SR); A=avg_spec(ref); B=avg_spec(out.mean(1))
def smooth(P):
    o=np.empty_like(P)
    for i,f in enumerate(fr): m=(fr>=f/2**(1/6))&(fr<=f*2**(1/6)); o[i]=P[m].mean() if m.any() else P[i]
    return o
gdb=np.clip(10*np.log10(smooth(A)/A.sum()/(smooth(B)/B.sum())),-12,12); gdb[fr<20]=-12
h=np.fft.irfft(10**(gdb/20)); h=np.roll(h,4096)*np.hanning(8192)
out=norm(np.stack([fftconvolve(out[:,c],h)[4096:4096+M] for c in (0,1)],1))
rms=lambda x: np.sqrt(np.mean(x[np.abs(x).sum(1)>1e-4]**2))
mix=out+keysout*(.45*rms(out)/rms(keysout))
tm=np.arange(M)/SR; mix=np.stack([np.interp(np.arange(M)-(.005+.0022*np.sin(2*np.pi*.3*tm))*SR,np.arange(M),mix[:,c],left=0) for c in (0,1)],1)
end=int((NS*SLOT/SLOW+4)*SR); mix=mix[:end]; mix[-int(4*SR):]*=np.linspace(1,0,int(4*SR))[:,None]
mix=np.tanh(norm(mix)*1.05); mix=norm(mix)*.95
w=wave.open('dream4_premaster.wav','wb'); w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((mix*32767).astype('<i2').tobytes()); w.close()
print('slots',NS,'length %.1f s'%(len(mix)/SR))
