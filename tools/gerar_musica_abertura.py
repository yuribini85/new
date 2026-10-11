#!/usr/bin/env python3
"""Compõe a música da abertura (arte/sons/abertura.ogg) em código, no tempo de
arte/abertura/roteiro.json: a música é própria do jogo (nenhuma amostra de fora).

Ré menor. Chuva e um zumbido grave na largada; um batimento que acelera e
cordas que sobem até a batida; no acidente, tudo corta: estrondo grave e um
zumbido de ouvido; depois, um piano triste sobre a chuva enquanto o outro carro
cruza a linha; no logo, um golpe grave e um acorde aberto que se apaga.

Uso: python3 tools/gerar_musica_abertura.py   (precisa de numpy e ffmpeg)
"""
from __future__ import annotations

import json
import pathlib
import subprocess
import tempfile
import wave

import numpy as np

RAIZ = pathlib.Path(__file__).resolve().parent.parent
ROTEIRO = RAIZ / "arte/abertura/roteiro.json"
SAIDA = RAIZ / "arte/sons/abertura.ogg"
TAXA = 44100

rng = np.random.default_rng(7)


def nota(n: str) -> float:
    """Frequência da nota ("D3", "Bb2", "F#4")."""
    nomes = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
             "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}
    nome, oitava = n[:-1], int(n[-1])
    semitons = nomes[nome] + 12 * (oitava + 1) - 69
    return 440.0 * 2 ** (semitons / 12)


def tempo(dur: float) -> np.ndarray:
    return np.arange(int(dur * TAXA)) / TAXA


def passa_baixa(x: np.ndarray, corte) -> np.ndarray:
    """Filtro de um polo; `corte` (Hz) pode variar amostra a amostra."""
    corte = np.broadcast_to(np.asarray(corte, dtype=float), x.shape)
    a = np.exp(-2 * np.pi * corte / TAXA)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a[i]) * x[i] + a[i] * acc
        y[i] = acc
    return y


def envelope(n: int, ataque: float, soltura: float) -> np.ndarray:
    e = np.ones(n)
    a = min(int(ataque * TAXA), n)
    s = min(int(soltura * TAXA), n - a)
    if a > 0:
        e[:a] = np.linspace(0, 1, a)
    if s > 0:
        e[n - s:] *= np.linspace(1, 0, s)
    return e


def serra(f: float, t: np.ndarray) -> np.ndarray:
    return 2 * ((f * t) % 1.0) - 1


def cordas(notas: list[str], dur: float, corte0: float, corte1: float, vol: float) -> np.ndarray:
    """Pad de cordas: serras levemente desafinadas, filtradas, abrindo o filtro."""
    t = tempo(dur)
    x = np.zeros_like(t)
    for n in notas:
        f = nota(n)
        for d in (-0.004, 0.0, 0.0037):
            x += serra(f * (1 + d), t + rng.random())
    x /= 3 * len(notas)
    x = passa_baixa(x, np.linspace(corte0, corte1, len(t)))
    x = passa_baixa(x, np.linspace(corte0, corte1, len(t)) * 1.5)
    return x * envelope(len(t), dur * 0.35, dur * 0.3) * vol


def batimento(vol: float) -> np.ndarray:
    """Um "tum-tum" grave de coração."""
    def bumbo(f0: float, dur: float, v: float) -> np.ndarray:
        t = tempo(dur)
        f = f0 * np.exp(-t * 9) + 38
        fase = 2 * np.pi * np.cumsum(f) / TAXA
        return np.sin(fase) * np.exp(-t * 11) * v
    a = bumbo(95, 0.35, 1.0)
    b = bumbo(80, 0.35, 0.7)
    x = np.zeros(int(0.55 * TAXA))
    x[:len(a)] += a
    x[int(0.2 * TAXA):int(0.2 * TAXA) + len(b)] += b
    return x * vol


def piano(n: str, dur: float, vol: float) -> np.ndarray:
    """Nota de piano simples: harmônicos com queda exponencial."""
    t = tempo(dur)
    f = nota(n)
    x = sum(np.sin(2 * np.pi * f * k * t) * (0.6 ** (k - 1)) * np.exp(-t * (1.6 + k * 0.9)) for k in range(1, 6))
    ataque = int(0.005 * TAXA)
    x[:ataque] *= np.linspace(0, 1, ataque)
    return x * vol


def chuva(dur: float, vol: float) -> np.ndarray:
    ruido = rng.normal(0, 1, int(dur * TAXA))
    x = passa_baixa(ruido, 3200) - passa_baixa(ruido, 400)
    gotas = (rng.random(len(x)) > 0.9993) * rng.normal(0, 3, len(x))
    x += passa_baixa(gotas, 2500)
    return x * vol


def estrondo(dur: float, vol: float) -> np.ndarray:
    t = tempo(dur)
    f = 70 * np.exp(-t * 3) + 32
    grave = np.sin(2 * np.pi * np.cumsum(f) / TAXA) * np.exp(-t * 1.6)
    ruido = passa_baixa(rng.normal(0, 1, len(t)), 900) * np.exp(-t * 6) * 3
    return (grave + ruido) * vol


def colar(trilha: np.ndarray, som: np.ndarray, ini: float) -> None:
    i = int(ini * TAXA)
    fim = min(len(trilha), i + len(som))
    if fim > i:
        trilha[i:fim] += som[:fim - i]


def compor(r: dict) -> np.ndarray:
    total = float(r["fim"]) + 0.5
    batida = float(r["batida"])
    logo = float(r["logo"])
    fim_planos = max(float(p["ini"]) + float(p["dur"]) for p in r["planos"])
    m = np.zeros(int(total * TAXA))
    # Chuva do começo até o logo (some na batida e volta).
    ch = chuva(fim_planos + 0.5, 0.05)
    ch *= envelope(len(ch), 2.5, 1.0)
    i_b = int(batida * TAXA)
    ch[i_b:i_b + int(0.6 * TAXA)] *= np.linspace(0.1, 1.0, int(0.6 * TAXA))
    colar(m, ch, 0.0)
    # Zumbido grave (Ré) até a batida, crescendo.
    t = tempo(batida)
    drone = (np.sin(2 * np.pi * nota("D1") * t) + 0.6 * np.sin(2 * np.pi * nota("D2") * t + 0.3)) \
        * np.linspace(0.05, 0.22, len(t)) * envelope(len(t), 3.0, 0.02)
    colar(m, drone, 0.0)
    # Cordas: Dm, Bb, Gm, A (tensão), abrindo e crescendo até a batida.
    acordes = [(["D3", "F3", "A3"], 3.0, 4.6), (["Bb2", "D3", "F3"], 7.4, 3.8), (["G2", "Bb2", "D3"], 11.0, 3.4),
               (["A2", "C#3", "E3", "A3"], 14.2, batida - 14.2)]
    for k, (ns, ini, dur) in enumerate(acordes):
        x = cordas(ns, dur + 0.6, 300 + k * 250, 700 + k * 600, 0.10 + k * 0.05)
        if ini + dur >= batida - 0.01:
            corta = int((batida - ini) * TAXA)
            x[corta:] = 0
        colar(m, x, ini)
    # Trêmulo agudo de tensão na reta final.
    t = tempo(batida - 11.0)
    trem = np.sin(2 * np.pi * nota("A4") * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t)) \
        * np.linspace(0.0, 0.06, len(t))
    colar(m, trem, 11.0)
    # Batimento: começa em 4 s, acelera de 1,1 s para 0,5 s entre batidas.
    ts = 4.0
    while ts < batida - 0.3:
        frac = (ts - 4.0) / (batida - 4.0)
        colar(m, batimento(0.35 + 0.35 * frac), ts)
        ts += 1.1 - 0.6 * frac
    # Batida: silêncio seco (tudo acima já corta) e o estrondo; depois o zumbido.
    colar(m, estrondo(3.5, 0.9), batida)
    t = tempo(4.0)
    zumbido = np.sin(2 * np.pi * 2100 * t) * np.exp(-t * 0.8) * 0.025
    colar(m, zumbido, batida + 0.1)
    # Depois: piano triste sobre um pad baixo (Dm, Bb, F, A sus).
    t0 = batida + 3.0
    pads = [(["D3", "F3", "A3"], 0.0), (["Bb2", "D3", "F3"], 3.2), (["F2", "A2", "C3"], 6.4), (["A2", "D3", "E3"], 9.6)]
    for ns, d in pads:
        if t0 + d < logo - 0.5:
            colar(m, cordas(ns, 3.8, 350, 500, 0.07), t0 + d)
    melodia = [("A4", 0.0), ("F4", 0.8), ("E4", 1.6), ("D4", 2.6), ("F4", 4.0), ("E4", 4.8), ("C4", 5.6),
               ("D4", 6.8), ("A3", 8.2), ("D4", 9.6), ("E4", 10.4), ("D4", 11.2)]
    for n, d in melodia:
        if t0 + d < logo - 1.0:
            colar(m, piano(n, 2.5, 0.16), t0 + d)
    # Logo: golpe grave e o acorde aberto (Ré com nona), que se apaga até o fim.
    colar(m, estrondo(4.0, 0.7), logo)
    dur_logo = total - logo
    acorde = cordas(["D2", "A2", "D3", "E3", "A3", "D4"], dur_logo, 900, 2600, 0.6)
    acorde *= envelope(len(acorde), 0.08, dur_logo * 0.75)
    colar(m, acorde, logo)
    for n, d in [("D5", 0.0), ("A4", 0.4), ("E5", 0.8)]:
        colar(m, piano(n, 4.0, 0.12), logo + 0.1 + d)
    # Fim: o último meio segundo some.
    m[-int(0.5 * TAXA):] *= np.linspace(1, 0, int(0.5 * TAXA))
    return m


def main() -> int:
    r = json.loads(ROTEIRO.read_text(encoding="utf-8"))
    mono = compor(r)
    # Compressão suave: os golpes não esmagam o resto (tanh limita os picos).
    mono /= max(np.abs(mono).max(), 1e-6)
    mono = np.tanh(4.0 * mono) / np.tanh(4.0) * 0.92
    # Estéreo leve: a direita atrasada 12 ms (largura sem mudar o centro).
    d = int(0.012 * TAXA)
    dir_ = np.concatenate([np.zeros(d), mono[:-d]])
    est = np.stack([mono, 0.85 * dir_ + 0.15 * mono], axis=1)
    pcm = (np.clip(est, -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = pathlib.Path(tmp) / "abertura.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(TAXA)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "4",
                        str(SAIDA)], check=True)
    print(f"{SAIDA.relative_to(RAIZ)}: {len(mono) / TAXA:.1f} s, {SAIDA.stat().st_size // 1024} KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
