# Uso: python3 tools/gerar_musica_crt.py arte/sons/musica_box.ogg
# Laço provisório de música do Chrome Racing Team: funk lo-fi de garagem,
# 90 BPM, 8 compassos (ii-V-I-VI em Ré menor/Dó), gerado do zero.
import numpy as np, subprocess, sys
SR=44100; BPM=90; BAT=60/BPM; COMP=4*BAT; N_COMP=8
T=N_COMP*COMP; n=int(T*SR); L=np.zeros(n); R=np.zeros(n)
rng=np.random.default_rng(7)
def hz(m): return 440*2**((m-69)/12)
def env(dur,a=0.005,d=0.3,s=0.4,r=0.2,total=None):
    total=total or dur+r; t=np.arange(int(total*SR))/SR
    e=np.where(t<a,t/a,np.where(t<a+d,1-(1-s)*(t-a)/d,s))
    e=np.where(t>dur,e*np.clip(1-(t-dur)/r,0,1),e); return e
def add(_,x,t0,pan=0.0,g=1.0):  # soma em L e R (estéreo pelo pan)
    i=int(t0*SR)%n; k=len(x)
    for b,gg in ((L,(1-pan)*g),(R,(1+pan)*g)):
        fim=min(i+k,n); b[i:fim]+=x[:fim-i]*gg
        if i+k>n: b[:i+k-n]+=x[fim-i:]*gg  # emenda: a cauda volta ao começo
def epiano(m,dur,vel=0.25):
    e=env(dur,0.004,0.6,0.25,0.35); t=np.arange(len(e))/SR; f=hz(m)
    x=np.sin(2*np.pi*f*t)+0.35*np.sin(2*np.pi*2*f*t)*np.exp(-t*6)+0.12*np.sin(2*np.pi*3*f*t)*np.exp(-t*9)
    return vel*x*e*(1+0.15*np.sin(2*np.pi*4.5*t))
def baixo(m,dur,vel=0.5):
    e=env(dur,0.003,0.15,0.6,0.06); t=np.arange(len(e))/SR; f=hz(m)
    x=np.sin(2*np.pi*f*t)+0.3*np.sin(2*np.pi*2*f*t); return vel*np.tanh(1.6*x)*e
def bumbo():
    t=np.arange(int(0.35*SR))/SR; f=50+90*np.exp(-t*30)
    return 0.9*np.sin(2*np.pi*np.cumsum(f)/SR)*np.exp(-t*9)
def caixa():
    t=np.arange(int(0.22*SR))/SR; r=rng.standard_normal(len(t))
    r=np.convolve(r,[1,-0.6],'same'); return 0.35*(r*np.exp(-t*22)+0.6*np.sin(2*np.pi*190*t)*np.exp(-t*30))
def chimbal(ab=False):
    t=np.arange(int((0.12 if ab else 0.04)*SR))/SR; r=rng.standard_normal(len(t))
    r=r-np.convolve(r,np.ones(4)/4,'same'); return 0.12*r*np.exp(-t*(18 if ab else 70))
acordes=[(50,[62,65,69,72,76]),(43,[59,62,65,69,71]),(48,[60,64,67,71,74]),(45,[61,64,67,70,73])]  # Dm9 G13 Cmaj9 A7(b9)
sw=0.08*BAT  # suingue
for c in range(N_COMP):
    t0=c*COMP; raiz,notas=acordes[c%4]
    # piano: acorde no 1 e "empurrado" no 2e
    for j,m in enumerate(notas):
        x=epiano(m,1.1*BAT,0.11); add(L,x,t0+j*0.008,pan=-0.2+0.1*j)
        x=epiano(m,0.6*BAT,0.07); add(L,x,t0+2.5*BAT+sw+j*0.006,pan=0.15-0.08*j)
    # baixo sincopado
    for (b,m,d) in [(0,raiz,0.7),(0.75,raiz,0.2),(1.5,raiz+12,0.3),(2,raiz+7,0.6),(3,raiz+5,0.3),(3.5,raiz+7,0.4)]:
        add(L,baixo(m,d*BAT,0.42),t0+b*BAT+(sw if b%1 else 0))
    # bateria
    for b in (0,1.75,2.5): add(L,bumbo(),t0+b*BAT+(sw if b%1 else 0),g=0.8)
    for b in (1,3): add(L,caixa(),t0+b*BAT,g=0.7)
    for k in range(8):
        add(L,chimbal(k==7),t0+k*0.5*BAT+(sw if k%2 else 0),pan=0.3,g=0.8 if k%2==0 else 0.55)
# chiado de vinil
ch=rng.standard_normal(n)*0.004; pops=rng.random(n)<0.00006; ch[pops]+=rng.standard_normal(pops.sum())*0.25
L+=ch; R+=ch
x=np.stack([L,R],1); x=np.tanh(1.2*x); x*=0.5/np.max(np.abs(x))  # pico -6 dB
pcm=(x*32767).astype(np.int16).tobytes()
out=sys.argv[1]
subprocess.run(['ffmpeg','-y','-v','error','-f','s16le','-ar',str(SR),'-ac','2','-i','-','-c:a','libvorbis','-q:a','4',out],input=pcm,check=True)
print("ok",T)
