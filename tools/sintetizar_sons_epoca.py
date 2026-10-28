#!/usr/bin/env python3
"""Sons de época sintetizados (sem amostra de terceiros): caixa registradora,
flash de magnésio e sino de bonde. Gera WAV e converte para OGG com o ffmpeg em
arte/sons/ (ver arte/sons/LICENCA.md). Uso: python3 tools/sintetizar_sons_epoca.py"""
import os, subprocess, tempfile, wave
import numpy as np

R = 44100
SAIDA = os.path.join(os.path.dirname(__file__), "..", "arte", "sons")
rng = np.random.default_rng(7)


def salvar(nome, x):
    x = x / (np.abs(x).max() + 1e-9) * 0.85
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, nome + ".wav")
        w = wave.open(wav, "wb")
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(R)
        w.writeframes((x * 32767).astype(np.int16).tobytes()); w.close()
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "5",
                        os.path.join(SAIDA, nome + ".ogg")], check=True)


def sino(f0, dur, decai, parciais):
    t = np.arange(int(R * dur)) / R
    x = np.zeros_like(t)
    for mult, amp, d in parciais:
        x += amp * np.sin(2 * np.pi * f0 * mult * t) * np.exp(-t * decai * d)
    return x * np.minimum(t / 0.002, 1)


def clique(dur=0.012, corte=1.0):
    n = int(R * dur); t = np.arange(n) / R
    return rng.standard_normal(n) * np.exp(-t * 400) * corte


def caixa_registradora():
    x = np.zeros(int(R * 1.1))
    for tt, a in [(0.0, 1.0), (0.05, 0.7), (0.09, 0.9), (0.16, 0.5)]:
        c = clique(0.015, a); s = int(tt * R); x[s:s + len(c)] += c
    gaveta = rng.standard_normal(int(R * 0.18)) * np.linspace(0.25, 0, int(R * 0.18))
    s = int(0.2 * R); x[s:s + len(gaveta)] += np.convolve(gaveta, np.ones(30) / 30, "same")
    b = sino(2350, 0.9, 6, [(1, 1, 1), (2.76, 0.5, 1.6), (5.4, 0.25, 2.4)])
    s = int(0.18 * R); x[s:s + len(b)] += 0.9 * b[:len(x) - s]
    return x


def flash():
    n = int(R * 0.8); t = np.arange(n) / R
    ruido = rng.standard_normal(n)
    grave = np.convolve(ruido, np.ones(60) / 60, "same") * np.exp(-t * 7) * 2.2
    estalo = np.zeros(n); c = clique(0.006, 2.0); estalo[:len(c)] = c
    return grave + estalo + ruido * np.exp(-t * 25) * 0.35


def sino_bonde():
    x = np.zeros(int(R * 1.4))
    for tt in [0.0, 0.22]:
        b = sino(1180, 1.1, 4, [(1, 1, 1), (2.0, 0.35, 1.4), (2.92, 0.45, 1.8), (4.16, 0.2, 2.6)])
        s = int(tt * R); x[s:s + len(b)] += b[:len(x) - s]
    return x


if __name__ == "__main__":
    salvar("caixa_registradora", caixa_registradora())
    salvar("flash", flash())
    salvar("sino", sino_bonde())
