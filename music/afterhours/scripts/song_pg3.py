# Full arrangement: glide-guitar wall + Mellotron/sampler flute lead (F6) + alarm interlude + guide vocal for the FNAF lyrics
import numpy as np, wave, sys, librosa
from scipy.signal import butter, sosfilt, fftconvolve
SR=44100; SLOW=0.8; BPM=100/SLOW; beat=60/BPM; s16=beat/4; SLOT=8*beat   # a slot = 2 bars = one chord = one lyric line
SECTIONS=[('I',4),('V',8),('P',4),('C',8),('X',4),('V',8),('P',4),('C',8),('B',4),('F',8),('O',4)]   # verses are 8 lines
slots=[(name,k) for name,n in SECTIONS for k in range(n)]; NS=len(slots)
TR=-12*np.log2(SLOW); N=int(NS*SLOT*SR)+SR*4; rng=np.random.default_rng(9); tt=np.arange(N)/SR
hz=lambda m:440*2**((m+TR-69)/12)
lp=lambda x,fc,o=2: sosfilt(butter(o,fc,'low',fs=SR,output='sos'),x)
hp=lambda x,fc,o=2: sosfilt(butter(o,fc,'high',fs=SR,output='sos'),x)
bp=lambda x,lo,hi: sosfilt(butter(2,[lo,hi],'band',fs=SR,output='sos'),x)
norm=lambda x: x/(np.abs(x).max()+1e-12)
def mixn(*xs):
    o=np.zeros(max(len(x) for x in xs))
    for x in xs: o[:len(x)]+=x
    return o
def put(bus,x,t0,g=1.):
    a=int(t0*SR); x=x[:max(0,N-a)]; bus[a:a+len(x)]+=x*g
# ---------------- harmony
AB,EB,FM,DB=(44,4),(39,4),(41,3),(37,4)          # (bass root, third above the guitar root: 4 major / 3 minor)
def chord(name,k): return [DB,EB,FM,EB][k%4] if name=='B' else [AB,EB,FM,DB][k%4]
# per-sample root (with a slide into each chord) and third
root=np.zeros(N); third=np.zeros(N); prev=44
for i,(name,k) in enumerate(slots):
    r,th=chord(name,k); a=int(i*SLOT*SR); z=int((i+1)*SLOT*SR); g=int(.15*SR)
    root[a:a+g]=np.linspace(prev,r,g); root[a+g:z]=r; third[a:z]=th; prev=r
root[z:]=prev; third[z:]=third[z-1]
def env_by_slot(vals,smooth=.08):   # per-slot gains -> smooth per-sample envelope
    e=np.zeros(N)
    for i,(name,k) in enumerate(slots): e[int(i*SLOT*SR):int((i+1)*SLOT*SR)]=vals(name,k)
    w=int(smooth*SR); return np.convolve(e,np.ones(w)/w,'same')
# ---------------- Pastel Ghost backing: Juno-style pads, chillwave arp, synth bass, drum machine (+ kick times for sidechain)
def saw(curve,cents=0.): return 2*(np.cumsum(hz(curve+cents/100))/SR%1)-1
def vdelay(x,d): return np.interp(np.arange(len(x))-d*SR,np.arange(len(x)),x,left=0)
PAD={'I':1,'V':.7,'P':.8,'C':1.15,'X':1,'B':.7,'F':1.25,'O':.9}   # verses lighter so choruses lift
pe=env_by_slot(lambda n,k: PAD[n],.35)                                     # slow swell into each section
major=(third==4)
pad=0
for iv in (0,7,12,14):                                                     # root, 5th, octave, 9th (add9 shimmer)
    pad=pad+sum(saw(root+24+iv,c) for c in (-12,0,12))
pad=pad+sum(saw(root+24+third,c) for c in (-12,0,12))+.6*sum(saw(root+24+np.where(major,11,10),c) for c in (-8,8))   # 3rd + maj7/min7
pad=lp(pad,2200)*pe
pads=np.stack([pad+.7*vdelay(pad,.007+.003*np.sin(2*np.pi*.5*tt)),pad+.7*vdelay(pad,.009+.003*np.sin(2*np.pi*.5*tt+2))],1)   # Juno chorus
# arp: 16th-note pluck up and down the chord, ping-pong delay
ARP={'I':.6,'V':.3,'P':.45,'C':.8,'X':.8,'B':0,'F':.9,'O':.6}
arp=np.zeros(N); pat=[0,1,2,3,4,3,2,1]
for i,(name,k) in enumerate(slots):
    if ARP[name]==0 or (name=='I' and k==0): continue
    r,th=chord(name,k); tones=[r+36,r+36+th,r+43,r+48,r+48+th]
    for x16 in range(32):
        m=tones[pat[x16%8]]; L=int(.22*SR); tq=np.arange(L)/SR
        p_=2*np.pi*hz(m)*tq; note=(np.sin(p_)+.4*np.sin(2*p_)+.15*np.sign(np.sin(p_)))*np.exp(-tq*14)
        gapslot=name in 'VP' and k%2==1
        put(arp,note,i*SLOT+x16*s16,ARP[name]*(2.2 if gapslot else 1)*(1 if x16%4==0 else .7))   # arp swells up between sung lines
arp=lp(arp,3200); d=int(.75*beat*SR); arps=np.stack([arp,arp],1)   # rounder arp
for k_ in range(1,4): arps[d*k_:,k_%2]+=lp(arp,4000-700*k_)[:-d*k_]*.45**k_
# synth bass: bouncing octaves on 8ths, round square/saw through a low-pass
bass=np.zeros(N); BP=[0,0,12,0,0,12,0,12]
for i,(name,k) in enumerate(slots):
    if (name=='I' and k==0): continue
    r=chord(name,k)[0]
    for e8 in range(16):
        if name=='B' and e8%4: continue                                   # bridge: just quarter-note pulses
        m=r+BP[e8%8]; L=int(beat/2*.85*SR); tq=np.arange(L)/SR; ph_=np.cumsum(np.full(L,hz(m)))/SR%1
        o_=np.where(ph_<.5,1.,-1.)+.5*(2*ph_-1); x=(lp(o_,600)+.35*lp(o_,2500)*np.exp(-tq*25))*np.minimum(1,tq/.004)*np.exp(-tq*3)   # bright attack fading into a round body
        put(bass,x,i*SLOT+e8*beat/2,(.75 if name in 'OB' else 1))
bass=bass+.8*np.sin(2*np.pi*np.cumsum(hz(root))/SR)*env_by_slot(lambda n,k: 0 if (n=='I' and k==0) else (.4 if n=='B' else 1))
# chorus lift: an extra octave-up pad and a high sparkle line, only in the choruses
lift_env=env_by_slot(lambda n,k: 1 if n in 'CF' else 0,.3)
lift=lp(sum(saw(root+36+iv,c) for iv in (0,7) for c in (-10,10)),3000)
sp_=lambda mm: (lambda p_: np.sin(p_)+.25*np.sin(2*p_))(2*np.pi*np.cumsum(hz(mm))/SR)
sparkle=(sp_(root+48+third)+.7*sp_(root+55))*(.75+.25*np.sin(2*np.pi*3*tt))   # gentle tremolo
liftst=np.stack([lift+.5*sparkle,vdelay(lift,.012)+.5*vdelay(sparkle,.02)],1)*lift_env[:,None]
# filter sweep: pads and arp open up across each pre-chorus
sweep=np.zeros(N)
for i,(name,k) in enumerate(slots):
    if name=='P': a_=int(i*SLOT*SR); sweep[a_:a_+int(SLOT*SR)]=np.linspace(k/4,(k+1)/4,int(SLOT*SR))
    elif name!='P': pass
dark=lambda x: np.stack([lp(x[:,c],600) for c in (0,1)],1)
pads=np.where((sweep>0)[:,None],dark(pads)*(1-sweep[:,None])+pads*sweep[:,None],pads)
arps=np.where((sweep>0)[:,None],dark(arps)*(1-sweep[:,None])+arps*sweep[:,None],arps)
# drum machine: punchy kick, clap+snare with gated reverb, crisp hats, open hat on the off-beats
dr=np.zeros(N); kick_times=[]; t=np.arange(int(.5*SR))/SR
kick=np.sin(2*np.pi*np.cumsum(45+140*np.exp(-t*40))/SR)*np.exp(-t*7)+.15*hp(rng.standard_normal(len(t)),3000)*np.exp(-t*200)
def clap():
    L=int(.35*SR); c=np.zeros(L); nz=bp(rng.standard_normal(L),900,5000)
    for o in (0,.01,.02): i_=int(o*SR); c[i_:]+=nz[:L-i_]*np.exp(-np.arange(L-i_)/SR*60)
    gate=np.where(np.arange(L)<int(.18*SR),1.,0.); verb=bp(rng.standard_normal(L),600,6000)*.5*gate*np.exp(-np.arange(L)/SR*4)   # gated reverb
    return c+.6*np.sin(2*np.pi*190*np.arange(L)/SR)*np.exp(-np.arange(L)/SR*30)+verb
hat=lambda o=False: .5*lp(hp(rng.standard_normal(int(.3*SR)),6000),9000)*np.exp(-np.arange(int(.3*SR))/SR*(10 if o else 45))   # softer, darker hats
def kput(t0,g):
    put(dr,kick,t0,g); kick_times.append((t0,g))
cnt={}; occ=[]                                    # which occurrence of its section each slot belongs to
for name,k in slots:
    if k==0: cnt[name]=cnt.get(name,0)+1
    occ.append(cnt[name])
jit=lambda: rng.normal(0,.004); vel=lambda: 1+rng.normal(0,.08)   # human timing and velocity
SWING=.22*s16
crash=lambda: hp(rng.standard_normal(int(2.5*SR)),3500)*np.exp(-np.arange(int(2.5*SR))/SR*1.6)
for i,(name,k) in enumerate(slots):
    if name in ('B','O') or (name=='I' and k==0): continue
    if name=='V' and occ[i]==1 and k<4: continue                    # verse 1 opens without drums
    if name in 'CF' and k==0: put(dr,crash(),i*SLOT,.45)              # crash as the chorus hits
    for b in range(2):
        t0=i*SLOT+b*4*beat; bar=k*2+b; last=(k==(7 if name in 'VCF' else 3)) and b==1
        if name=='P':
            for q in range(4): kput(t0+q*beat+jit(),.9*vel())
            for e8 in range(8): put(dr,hat(),t0+e8*beat/2+jit(),.35*vel())
            if k==3 and b==1:
                for r_ in range(14): put(dr,clap(),t0+r_*s16,.1+.04*r_)   # roll stops 2 sixteenths early: the gap
            continue
        lvl=(.6 if k<4 else .7) if name=='V' else 1
        for q in (0,1.5,2): kput(t0+q*beat+jit(),lvl*(1 if q!=1.5 else .7)*vel())
        if bar%4==3: kput(t0+3.75*beat,.35*lvl)                       # ghost kick every 4th bar
        for q in (1,3): put(dr,clap(),t0+q*beat+jit(),.85*lvl*vel())
        if bar%2==1: put(dr,clap(),t0+7*s16+jit(),.12*lvl)              # ghost clap
        for x16 in range(16):
            if bar%4==3 and x16>=14: continue                          # hat skip at the end of every 4th bar...
            put(dr,hat(),t0+x16*s16+(SWING if x16%2 else 0)+jit(),(.35 if x16%2==0 else .2)*lvl*vel())
        if bar%4==3: put(dr,hat(True),t0+14*s16,.35*lvl)               # ...replaced by an open hat
        for q in range(4): put(dr,hat(True),t0+q*beat+beat/2+SWING+jit(),.25*lvl*vel())
        if last and name!='V':
            for r_ in range(4): put(dr,clap(),t0+(12+r_)*s16,.25+.12*r_)
# gap fillers between sung lines (odd verse / pre-chorus slots): a soft synth swell, shaker, tom fill into the next line
swell=np.zeros(N); shaker=np.zeros(N)
toms=[(lambda f: np.sin(2*np.pi*np.cumsum(f*(1+.6*np.exp(-np.arange(int(.35*SR))/SR*25)))/SR)*np.exp(-np.arange(int(.35*SR))/SR*9))(f) for f in (180,140,110)]
for i,(name,k) in enumerate(slots):
    if not (name in 'VP' and k%2==1): continue
    r,th=chord(name,k); L=int(SLOT*SR); tq=np.arange(L)/SR
    sw=sum(np.sin(2*np.pi*hz(m)*tq)+.3*np.sin(4*np.pi*hz(m)*tq) for m in (r+36,r+36+th,r+43,r+48))*np.sin(np.pi*tq/tq[-1])**2
    put(swell,sw,i*SLOT)
    for x16 in range(32): put(shaker,bp(rng.standard_normal(int(.07*SR)),5000,10000)*np.exp(-np.arange(int(.07*SR))/SR*45),i*SLOT+x16*s16+(SWING if x16%2 else 0),.35 if x16%4==2 else .2)
    for j,tm_ in enumerate(toms): put(dr,tm_,i*SLOT+(28+j)*s16,.6)
# reverse-cymbal riser ending at a 2-sixteenth silence right before every chorus
gap=np.ones(N); riser=np.zeros(N)
for i in range(1,len(slots)):
    if slots[i][0] in 'CF' and slots[i][1]==0:
        g1=int((i*SLOT-2*s16)*SR); g2=int(i*SLOT*SR); f_=int(.004*SR)
        gap[g1:g2]=0; gap[g1-f_:g1]=np.linspace(1,0,f_); gap[g2:g2+f_]=np.linspace(0,1,f_)
        L=int(4*beat*SR); rc=hp(rng.standard_normal(L),3000)*np.exp(-np.arange(L)/SR*1.6); rc=rc[::-1]
        put(riser,rc,(i*SLOT-2*s16)-L/SR,.5)
# sidechain: pads, arp and bass dip ~40% on each kick and breathe back over ~180 ms
duck=np.ones(N)
for t0,g in kick_times:
    a_=int(t0*SR); L=int(.35*SR); seg=1-.4*g*np.exp(-np.arange(L)/SR/.18); duck[a_:a_+L]=np.minimum(duck[a_:a_+L],seg[:max(0,N-a_)])
# ---------------- flute: Mellotron/sampler patch (flute + oboe + female vocal sample + feedback), and the alarm variant
def flute(m,d):
    t=np.arange(int((d+.5)*SR))/SR; f=hz(m)*2**(.22*np.sin(2*np.pi*5.2*t)*np.clip((t-.12)/.3,0,1)/12); p_=2*np.pi*np.cumsum(f)/SR
    x=np.sin(p_)+.18*np.sin(2*p_)+.05*np.sin(3*p_)+.07*bp(rng.standard_normal(len(t)),1500,6000)
    return x*np.minimum(1,t/.04)*np.where(t<d,1,np.exp(-(t-d)*9))
def oboe_(m,d):
    t=np.arange(int((d+.4)*SR))/SR; ph_=np.cumsum(np.full(len(t),hz(m)))/SR%1
    p_=np.where(ph_<.2,1.,-.25); return norm(bp(p_,900,1700)+.3*lp(p_,700))*np.minimum(1,t/.03)*np.where(t<d,1,np.exp(-(t-d)*8))
def formant_voice(m,d,F,breath=.5,att=.12):
    t=np.arange(int((d+.4)*SR))/SR; f=hz(m)*2**(.18*np.sin(2*np.pi*5.5*t)*np.minimum(1,t/.4)/12)
    src=2*(np.cumsum(f)/SR%1)-1+breath*rng.standard_normal(len(t))
    return sum(g*bp(src,fc*.9,fc*1.1) for fc,g in F)*np.minimum(1,t/att)*np.where(t<d,1,np.exp(-(t-d)*6))
FEMALE_AH=((850,1),(1220,.6),(2810,.3),(3600,.12)); OOH=((350,1),(800,.45),(2600,.12))
BASE=76
def sampled(gen,m,d):
    r=2**((m-BASE)/12); x=gen(BASE,d*r); return np.interp(np.arange(0,len(x),r),np.arange(len(x)),x)
def mtron_note(m,d):
    t_=np.arange(int((d+.6)*SR))/SR
    lay=[.5*norm(sampled(flute,m,d)),.3*norm(sampled(oboe_,m,d)),.35*norm(sampled(lambda mm,dd: formant_voice(mm,dd,FEMALE_AH),m,d))]
    if d>=beat:
        fb=np.tanh(2*(np.sin(2*np.pi*hz(m+12)*t_)+.3*np.sin(2*np.pi*hz(m+24)*t_)))
        lay.append(.3*fb*np.clip((t_-.15)/max(d*.7,.1),0,1)*np.where(t_<d,1,np.exp(-(t_-d)*4)))
    x=mixn(*lay)[:len(t_)]; x=np.pad(x,(0,len(t_)-len(x)))
    return x*np.minimum(1,t_/.05)*np.where(t_<d,1,np.exp(-(t_-d)*14))
def ebow(m,d):
    t=np.arange(int((d+.4)*SR))/SR; f=hz(m-.3*np.exp(-t/.06))*2**(.1*np.sin(2*np.pi*4.5*t)/12)
    x=sum(2*(np.cumsum(f*2**(c/1200))/SR%1)-1 for c in (-4,4)); return np.tanh(1.5*bp(x,400,3500))*np.minimum(1,t/.12)*np.where(t<d,1,np.exp(-(t-d)*7))
def hybrid(m,d):
    f_=flute(m,d); t=np.arange(len(f_))/SR
    return mixn(norm(f_),.7*norm(ebow(m,d)),.35*norm(formant_voice(m-12,d,OOH,.4,.15)),.4*norm(f_)*np.minimum(1,t/max(d*.8,.05))**2)
def alarm_note(m,d,full):
    t_=np.arange(int((d+.5)*SR))/SR
    if full and d>=3*s16:
        hi=(np.floor(t_*3)%2==1); x=np.where(hi,np.pad(hybrid(m+5,d),(0,len(t_)))[:len(t_)],np.pad(hybrid(m,d),(0,len(t_)))[:len(t_)])
    else: x=np.pad(hybrid(m,d),(0,len(t_)))[:len(t_)]
    if d>=3*s16: x=np.interp(np.arange(len(x))-(.015+.012*np.sin(2*np.pi*1.2*t_-np.pi/2))*SR,np.arange(len(x)),x,left=0)
    a=.5 if full else .25; x=(1-a)*x+a*x*np.sin(2*np.pi*hz(m)*1.41*t_)*1.5
    if full:
        sq=np.sign(np.sin(2*np.pi*hz(m)*t_))*np.minimum(1,t_/.01)*np.where(t_<d,1,np.exp(-(t_-d)*12)); x=x+.25*norm(lp(sq,5000))*np.abs(x).max()
    if d<=2*s16 or full:
        g=(np.sin(2*np.pi*t_/(s16/2))>-.2).astype(float); x=x*np.convolve(g,np.ones(64)/64,'same')
    return x
def epiano(m,d):  # FM electric piano (DX-style): 1:1 FM with a decaying index, a bell "tine" on the attack, slight chorus
    L=int((d+1.2)*SR); t=np.arange(L)/SR; f=hz(m); out_=0
    for det,g in ((0,1),(7,.6)):
        ff=f*2**(det/1200); idx=2.5*np.exp(-t*7)+.5
        out_=out_+g*np.sin(2*np.pi*ff*t+idx*np.sin(2*np.pi*ff*t))
    out_=out_+.15*np.sin(2*np.pi*min(14*f,18000)*t)*np.exp(-t*45)          # tine
    return out_*np.minimum(1,t/.002)*np.exp(-t*1.1)*np.where(t<d,1,np.exp(-(t-d)*3.5))   # piano-like decay, soft release
def pastel_keys(m,d):  # soft Rhodes-like keys: low FM index, no bell tine, three detuned voices, slow attack-free roll-off
    L=int((d+1.5)*SR); t=np.arange(L)/SR; f=hz(m); o_=0
    for det in (-9,0,9):
        ff=f*2**(det/1200); idx=.9*np.exp(-t*5)+.25
        o_=o_+np.sin(2*np.pi*ff*t+idx*np.sin(2*np.pi*ff*t))+.2*np.sin(2*np.pi*ff*.5*t)   # a touch of sub-octave warmth
    return lp(o_,2000)*np.minimum(1,t/.006)*np.exp(-t*.9)*np.where(t<d,1,np.exp(-(t-d)*2.5))
mtron_note=pastel_keys; hybrid=pastel_keys   # the synth piano replaces the flute everywhere (the alarm effects still apply)
# F6 hook: (start 16th, length 16ths, note) per chord; bridge chords reuse the matching shapes
F6={44:[84,84,87,87,85,84,84,80,82,82,84],39:[82,82,87,87,84,82,82,79,80,80,82],41:[84,84,89,89,87,84,84,92,82,82,84],37:[80,80,85,85,84,80,80,77,79,79,85]}   # Fm phrase: its long note jumps to Ab6 and holds; Db phrase ends higher (Db6): the cycle rises
F6T=[0,1,4,5,8,12,13,16,26,27,28]; F6L=[1,1,1,1,4,1,1,8,1,1,4]
F6LEN={41:[1,1,1,1,4,1,1,10,1,1,4]}   # Fm: the high long note holds until the last three notes
fl_m=np.zeros(N); fl_a=np.zeros(N)
# ---------------- guide vocal melody: per slot (start 8th, length 8ths, midi)
def L(ts,ls,ns): return list(zip(ts,ls,ns))
VERSE=[L(range(7),[1]*6+[4],[60,60,63,63,61,60,56]), L(range(8),[1]*7+[4],[58,58,58,63,61,60,58,55]),
       L(range(8),[1]*7+[4],[56,60,60,63,61,60,60,56]), L(range(9),[1]*8+[4],[61,61,60,58,56,58,60,61,60])]
VERSE_B=[L(range(8),[1]*7+[4],[63,63,63,65,63,61,60,63]), L(range(7),[1]*6+[4],[63,63,67,65,63,61,58]),   # lines 5-8: a step higher, building
         L(range(8),[1]*7+[4],[60,60,63,65,63,60,60,56]), L(range(8),[1]*7+[4],[61,61,60,61,65,63,61,60])]
PRE=[L(range(8),[1]*7+[3],[63,63,63,65,63,61,60,63]), L(range(6),[1]*5+[5],[63,63,65,67,65,63]),
     L(range(7),[1]*6+[4],[65,65,63,65,68,65,63]), L(range(6),[1]*5+[6],[65,65,63,61,60,61])]
CHORUS=[L([0,1,3,4,5,6,7],[1,1,1,1,1,1,4],[60,60,60,63,63,61,60]), L([0,1,3,4,5,6],[1,1,1,1,1,5],[58,58,58,63,61,60]),
        L(range(7),[1]*6+[4],[56,60,63,65,63,60,56]), L([0,1,3,4,5],[1,2,1,1,6],[65,63,61,60,56])]
BRIDGE=[L(range(7),[1]*6+[5],[61,61,60,58,60,61,65]), L(range(6),[1]*5+[5],[63,63,67,63,61,58]),
        L(range(8),[1]*7+[4],[60,60,63,65,65,63,60,56]), L(range(6),[1,1,1,1,1,8],[58,60,63,65,67,68])]
MELODY={'V':VERSE+VERSE_B,'P':PRE,'C':CHORUS,'F':CHORUS,'B':BRIDGE}
vox=np.zeros(N)
for i,(name,k) in enumerate(slots):
    t0=i*SLOT; r=chord(name,k)[0]; hook=F6[r]
    # flute
    if name in ('I','O'):
        for st,ln,m in zip(F6T,F6LEN.get(r,F6L),hook): put(fl_m,mtron_note(m,ln*s16*.95),t0+st*s16)
    elif name in ('V','P') and k%2==1:                      # empty slot between sung lines: the full hook fills it
        for st,ln,m in zip(F6T,F6LEN.get(r,F6L),hook): put(fl_m,mtron_note(m,ln*s16*.95),t0+st*s16,1.6)
        rv=mtron_note(hook[0],beat*1.5)[:int(1.5*beat*SR)][::-1]        # reverse piano: swells into the next sung line
        put(fl_m,rv*np.linspace(0,1,len(rv))**2,t0+SLOT-len(rv)/SR,1.2)
    elif name in ('V','P','C','F'):                          # the "pair echo" answers each sung line
        for st,ln,m in zip(F6T[-3:],F6L[-3:],hook[-3:]): put(fl_m,mtron_note(m,ln*s16*.95),t0+st*s16,1.15)
    elif name=='X':                                          # alarm interlude: subtle, then full
        for st,ln,m in zip(F6T,F6LEN.get(r,F6L),hook): put(fl_a,alarm_note(m,ln*s16*.95,k>=2),t0+st*s16)
    elif name=='B':                                          # alarm creeping in quietly on the long notes only
        for st,ln,m in zip(F6T,F6LEN.get(r,F6L),hook):
            if ln>=4: put(fl_a,alarm_note(m,ln*s16*.95,False),t0+st*s16,.35+.15*k)
    # guide vocal (and the final chorus flute doubling the vocal two octaves up)
    if name in MELODY:
        for st,ln,m in MELODY[name][k%len(MELODY[name])]:
            put(vox,formant_voice(m,ln*beat/2*.95,FEMALE_AH,.25,.06),t0+st*beat/2)
# ---------------- effect chains for the flute
def vdelay(x,d): return np.interp(np.arange(len(x))-d*SR,np.arange(len(x)),x,left=0)
fl_a=.45*np.tanh(2.2*norm(bp(fl_a,450,3200)))*np.abs(fl_m).max()                     # intercom / PA speaker, kept below the chorus level
kx=fl_m+fl_a
kx=np.interp(np.arange(N)-(.005+.002*np.sin(2*np.pi*.4*tt)+.0003*np.sin(2*np.pi*5*tt))*SR,np.arange(N),kx,left=0)   # cassette warble
kx=lp(np.tanh(1.4*norm(kx)),3200)                                                   # gentle tape saturation, top rolled off
flst=np.stack([kx+.8*vdelay(kx,.011+.004*np.sin(2*np.pi*.3*tt)),kx+.8*vdelay(kx,.015+.004*np.sin(2*np.pi*.3*tt+2.1))],1)   # wide, deep chorus   # dry patch into the big reverb - the sound of mellotron_lead_F6 (no tape flutter or delay)
# ---------------- mixdown: backing gets slowed + reverb + match EQ; flute and guide vocal are laid on top
intro_fade=np.ones(N); o0=int(([i for i,(n,k) in enumerate(slots) if n=='O'][0])*SLOT*SR); intro_fade[o0:]=np.linspace(1,0,N-o0)**1.5
# ethereal layers: a constant soft 8th-note strum pulse (the reference's engine) and a high "aah" choir pad
strum=np.zeros(N)
for i,(name,k) in enumerate(slots):
    if name=='O' or (name=='I' and k==0): continue
    r,th=chord(name,k)
    for e8 in range(16):
        L=int(.3*SR); tq=np.arange(L)/SR; x_=0
        for j,iv in enumerate((24,31,36,36+th,43)):
            x_=x_+np.roll(saw(np.full(L,r+iv),(j-2)*4),int(j*.004*SR))   # tiny strum spread across strings
        put(strum,lp(x_,1800)*np.minimum(1,tq/.004)*np.exp(-tq*9),i*SLOT+e8*beat/2+(.006 if e8%2 else 0),(1 if e8%2==0 else .7)*(.5 if name in 'VB' else 1))
CHOIR={'I':.8,'V':0,'P':.4,'C':1,'X':.6,'B':.7,'F':1.1,'O':.8}
ce=env_by_slot(lambda n,k: CHOIR[n],.6)
def aah(curve):
    src=2*(np.cumsum(hz(curve)*2**(.15*np.sin(2*np.pi*5*tt)/12))/SR%1)-1+.3*rng.standard_normal(N)
    return sum(g*bp(src,fc*.9,fc*1.1) for fc,g in ((850,1),(1220,.6),(2810,.25)))
choir=(aah(root+36+third)+.8*aah(root+43)+.6*aah(root+48))*ce
choirst=np.stack([choir,vdelay(choir,.017)],1)
# 3) reverse-reverb swell that rises into every chord change
rswell=np.zeros(N); Lt=int(2.5*SR); irs=lp(rng.standard_normal(Lt),4000)*np.exp(-np.arange(Lt)/SR*1.8)
for i in range(1,len(slots)):
    if slots[i][0]=='O': continue
    r,th=chord(*slots[i]); Lb=int(.25*SR)
    burst=sum(saw(np.full(Lb,r+iv)) for iv in (24,31,36,36+th))*np.hanning(Lb)
    sw=fftconvolve(burst,irs)[::-1]; put(rswell,lp(sw,3000),i*SLOT-len(sw)/SR)
back=((.8*norm(pads)+.45*norm(arps)+1.1*norm(liftst)+.35*np.stack([norm(swell)]*2,1)+np.stack([.5*norm(strum)]*2,1)+.3*norm(choirst)+np.stack([.9*norm(bass)]*2,1))*duck[:,None]+np.stack([1.1*norm(lp(dr,3800))+.12*norm(shaker)]*2,1))*gap[:,None]+np.stack([.5*norm(riser)+.3*norm(rswell)]*2,1)
flst=flst*gap[:,None]*(1-.6*(1-duck))[:,None]   # keys breathe with the kick too
# tape stop: the whole band winds down over 1.5 beats into the alarm interlude
for i in range(1,len(slots)):
    if slots[i][0]=='X' and slots[i][1]==0:
        z_=int(i*SLOT*SR); L=int(1.5*beat*SR); a_=z_-L; pos=a_+np.cumsum(np.linspace(1,0,L))
        for arr in (back,flst):
            seg=np.stack([np.interp(pos,np.arange(len(arr)),arr[:,c]) for c in (0,1)],1)*np.linspace(1,.2,L)[:,None]
            arr[a_:z_]=seg
back*=intro_fade[:,None]; flst*=intro_fade[:,None]
M=int(N/SLOW); src=np.arange(M)*SLOW
env_=np.sqrt(np.convolve(back.mean(1)**2,np.ones(int(.1*SR))/int(.1*SR),'same'))+1e-6; thr=np.percentile(env_,60)
back=back*np.minimum(1,(env_/thr)**-.5)[:,None]                              # 2:1 glue compression above the median level
Lr=int(SR*6); tr=np.arange(Lr)/SR; ir=np.stack([lp(rng.standard_normal(Lr),5000) for _ in (0,1)])*np.exp(-tr*.9); ir[:,:int(.04*SR)]=0   # 6 s hall
def slowrev(x,wetg):
    x=np.stack([np.interp(src,np.arange(N),x[:,c]) for c in (0,1)],1)
    wet=np.stack([fftconvolve(x[:,c],ir[c])[:M] for c in (0,1)],1); return norm(x)+wetg*norm(wet)
def octave_up(x,G=4096):
    y_=np.zeros(len(x)); w_=np.hanning(G)
    for i_ in range(0,len(x)-2*G,G//4): y_[i_:i_+G]+=x[i_:i_+2*G:2]*w_
    return y_
out=slowrev(back,.95); flo=slowrev(flst,1.1)                                  # everything floats in a long wash
shim=np.stack([lp(octave_up(out[:,c]-norm(np.stack([np.interp(src,np.arange(N),back[:,c_]) for c_ in (0,1)],1))[:,c]),7000) for c in (0,1)],1)
out=out+.12*norm(shim)                                                         # octave-up shimmer from the reverb tail
ref,_=librosa.load('song/s.wav',sr=SR,mono=True)   # the Pastel Ghost reference
def avg_spec(x,n=8192): return np.abs(librosa.stft(x,n_fft=n,hop_length=n//2)).mean(1)**2
fr=np.fft.rfftfreq(8192,1/SR); A=avg_spec(ref); B=avg_spec(out.mean(1))
def smooth(P):
    o=np.empty_like(P)
    for i,f in enumerate(fr): m=(fr>=f/2**(1/6))&(fr<=f*2**(1/6)); o[i]=P[m].mean() if m.any() else P[i]
    return o
gdb=np.clip(10*np.log10(smooth(A)/A.sum()/(smooth(B)/B.sum())),-12,12); gdb[fr<25]=-12
h=np.fft.irfft(10**(gdb/20)); h=np.roll(h,4096)*np.hanning(8192)
out=norm(np.stack([fftconvolve(out[:,c],h)[4096:4096+M] for c in (0,1)],1))
tm=np.arange(M)/SR; out=np.stack([np.interp(np.arange(M)-(.005+.0025*np.sin(2*np.pi*.33*tm)+.00012*np.sin(2*np.pi*4.5*tm))*SR,np.arange(M),out[:,c],left=0) for c in (0,1)],1)   # lo-fi tape wow
rms=lambda x: np.sqrt(np.mean(x[np.abs(x).sum(1)>1e-4]**2))
flute_part=flo*(.65*rms(out)/rms(flo))
def write(name,x):
    x=np.tanh(norm(x)*1.05); x=norm(x)*.95
    w=wave.open(name,'wb'); w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((x*32767).astype('<i2').tobytes()); w.close()
hiss=sosfilt(butter(1,[800,9000],'band',fs=SR,output='sos'),rng.standard_normal(M))*.0025   # cassette hiss
pops=np.zeros(M); idx=rng.choice(M,int(M/SR*1.5),replace=False); pops[idx]=rng.uniform(-.03,.03,len(idx))   # faint crackle
write('pg3_premaster.wav',out+flute_part+np.stack([hiss+lp(pops,4000)]*2,1))
print('slots',NS,'length',round(M/SR,1),'s')
