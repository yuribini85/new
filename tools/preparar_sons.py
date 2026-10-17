#!/usr/bin/env python3
"""Corta os sons gravados e grava os .ogg do jogo em arte/sons/. Fontes (todas
de uso comercial sem atribuição; detalhes em arte/sons/LICENCA.md):
  GDC Game Audio Bundle 2026, parte 9 (Sonniss, royalty-free);
  Mixkit (Mixkit Sound Effects Free License), arquivos mixkit_<id>.mp3;
  Kenney (CC0), arquivos kenney_<nome>.ogg.

Os originais ficam fora do repositório; passe a pasta onde estão, com os nomes
curtos abaixo:

    python3 tools/preparar_sons.py <pasta com impacto.wav, mixkit_462.mp3, ...>

Laços (oficina, torcida, motor_grave) fecham com uma emenda cruzada: o fim do
trecho é misturado ao começo, para repetir sem estalo (emenda de até 1,5 s,
15% do trecho). Mono, 44,1 kHz (tocam em celular; o estéreo dobraria o
tamanho sem diferença no alto-falante).
"""
import subprocess
import sys
from pathlib import Path

import numpy as np

TAXA = 44100
DESTINO = Path(__file__).resolve().parent.parent / "arte" / "sons"

# nome no jogo: (arquivo, início s, fim s, laço, ganho dB)
CORTES = {
    "impacto": ("impacto.wav", 0.0, 1.8, False, 2.0),
    "raspagem": ("raspagem.wav", 0.3, 3.4, False, 0.0),
    "porta_abre": ("porta.wav", 0.05, 0.9, False, 4.0),
    "porta": ("porta.wav", 1.75, 2.55, False, 0.0),
    "oficina": ("oficina.wav", 2.0, 26.0, True, 6.0),
    # SoundBits, Mad Mustang Mercury: V8 em marcha lenta, estável até 2,5 s.
    "motor_grave": ("mustang.wav", 0.0, 2.2, True, 8.0),
    # Mixkit: "Fast car drive by" (ultrapassagem).
    "passagem": ("mixkit_1538.mp3", 0.3, 2.6, False, 0.0),
    # Mixkit: "Huge crowd cheering victory" (torcida da reta final).
    "torcida": ("mixkit_462.mp3", 1.0, 7.5, True, 0.0),
    # Mixkit: "Stadium joy shouting crowd" (chegada).
    "comemoracao": ("mixkit_3022.mp3", 0.0, 14.0, False, 0.0),
    # Mixkit: "Car explosion debris" (explosão na arena).
    "explosao": ("mixkit_1562.mp3", 0.0, 7.5, False, 0.0),
    # Mixkit: "Garage pneumatic screwer" (peça instalada).
    "parafusadeira": ("mixkit_817.mp3", 0.0, 0.9, False, 0.0),
    # Kenney Interface Sounds: error_003 (aviso de falha).
    "erro": ("kenney_error_003.ogg", 0.0, 0.53, False, 0.0),
    # SoundBits, Vox Hominis: piloto correndo depois de sair do carro.
    "ofegante": ("ofegante.wav", 0.0, 4.5, False, 0.0),
}
EMENDA_S = 1.5
BORDA_S = 0.01


def ler(caminho: Path) -> np.ndarray:
    bruto = subprocess.run(["ffmpeg", "-v", "error", "-i", str(caminho), "-ac", "1", "-ar",
                            str(TAXA), "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(bruto, np.float32).astype(np.float64)


def cortar(x: np.ndarray, ini: float, fim: float, laco: bool) -> np.ndarray:
    a, b = int(ini * TAXA), int(fim * TAXA)
    if laco:
        e = int(min(EMENDA_S, (fim - ini) * 0.15) * TAXA)
        trecho = x[a:b + e].copy()
        rampa = np.linspace(0.0, 1.0, e)
        # O começo recebe o que vem depois do fim, entrando enquanto ele sai.
        trecho[:e] = trecho[:e] * rampa + trecho[-e:] * (1.0 - rampa)
        return trecho[:-e]
    trecho = x[a:b].copy()
    n = int(BORDA_S * TAXA)
    trecho[:n] *= np.linspace(0.0, 1.0, n)
    cauda = min(len(trecho) // 4, int(0.15 * TAXA))
    trecho[-cauda:] *= np.linspace(1.0, 0.0, cauda)
    return trecho


def gravar(nome: str, y: np.ndarray) -> None:
    pico = np.abs(y).max()
    if pico > 0.98:
        y = y * (0.98 / pico)
    saida = DESTINO / (nome + ".ogg")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(TAXA), "-ac", "1",
                    "-i", "-", "-c:a", "libvorbis", "-q:a", "3", str(saida)],
                   input=y.astype(np.float32).tobytes(), check=True)
    print("%-11s %5.1f s  %6.1f KB" % (nome, len(y) / TAXA, saida.stat().st_size / 1024))


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    pasta = Path(sys.argv[1])
    lidos = {}
    for nome, (arq, ini, fim, laco, ganho) in CORTES.items():
        if arq not in lidos:
            lidos[arq] = ler(pasta / arq)
        gravar(nome, cortar(lidos[arq], ini, fim, laco) * 10 ** (ganho / 20.0))


if __name__ == "__main__":
    main()
