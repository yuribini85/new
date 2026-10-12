#!/usr/bin/env python3
"""Põe no lugar as imagens do pedido dos rivais (tools/pacote_arte_grid.py).
Lê a pasta com os PNGs nos nomes pedidos (dirigente_<equipe>.png,
generico_NN.png) e grava cada um no destino, recortado no formato e escalado
por inteiro (nunca esticado). Fundo magenta chapado (#FF00FF) vira
transparente. Do genérico (corpo inteiro), o retrato sai recortado do corpo:
da cabeça à cintura, centrado na cabeça, como nos genéricos 01–08.
Uso: python3 tools/importar_arte_grid.py <pasta>
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pacote_arte_grid import RAIZ, TAM_PILOTO, pedidos  # noqa: E402


def recortar(img, larg, alt, topo=False):
    """Recorta para a proporção larg:alt (centro; de cima, se `topo`) e escala inteira."""
    w, h = img.size
    alvo = larg / alt
    if w / h > alvo:
        nw = round(h * alvo)
        img = img.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    elif w / h < alvo:
        nh = round(w / alvo)
        y = 0 if topo else (h - nh) // 2
        img = img.crop((0, y, w, y + nh))
    return img.resize((larg, alt), Image.LANCZOS)


def sem_magenta(img):
    img = img.convert("RGBA")
    px = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            if r > 200 and b > 200 and g < 80:
                px[x, y] = (0, 0, 0, 0)
    return img


def retrato_do_corpo(corpo, larg, alt):
    """Retrato larg:alt do corpo inteiro: do alto da cabeça até ~36% da figura,
    centrado na cabeça (o meio das linhas de cima), escalado por inteiro."""
    x0, y0, x1, y1 = corpo.split()[3].getbbox()
    h = round((y1 - y0) * 0.36)
    w = round(h * larg / alt)
    topo = corpo.crop((x0, y0, x1, y0 + max(1, (y1 - y0) // 12))).split()[3].getbbox()
    cx = x0 + (topo[0] + topo[2]) // 2 if topo else (x0 + x1) // 2
    caixa = (cx - w // 2, max(0, y0 - 5), cx - w // 2 + w, max(0, y0 - 5) + h)
    return corpo.crop(caixa).resize((larg, alt), Image.LANCZOS)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    pasta = Path(sys.argv[1])
    for p in pedidos():
        f = pasta / p["arquivo_pedido"]
        if not f.exists():
            print(f"falta  {p['arquivo_pedido']}")
            continue
        img = Image.open(f)
        img = recortar(sem_magenta(img), p["largura_px"], p["altura_px"], topo=True)
        destino = RAIZ / p["destino"]
        destino.parent.mkdir(parents=True, exist_ok=True)
        img.save(destino)
        print(f"ok     {p['destino']}")
        if p.get("destino_retrato"):
            r = RAIZ / p["destino_retrato"]
            retrato_do_corpo(img, *TAM_PILOTO).save(r)
            print(f"ok     {p['destino_retrato']}")


if __name__ == "__main__":
    main()
