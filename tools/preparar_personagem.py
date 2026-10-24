#!/usr/bin/env python3
"""Prepara a arte de um personagem do diálogo (corpo inteiro e poses) a partir dos
PNG RGBA entregues: limpa a transparência (franja quase invisível some, o quase
opaco vira opaco), põe cada pose no quadro 2:3 do diálogo com escala uniforme
(sem esticar; a pose de outro tamanho é escalada inteira pela altura e recortada
dos lados) e grava em webp; do rosto da pose base sai o retrato quadrado.

Uso: python3 tools/preparar_personagem.py <pasta> <id> base=<arquivo> <pose>=<arquivo>...
  ex.: ... entrega/Mara_Hayes mara_hayes base=01_neutra_frontal.png gesto=02_bracos_cruzados.png
Saída: arte/personagens/corpo/<id>.webp, corpo/<id>_<pose>.webp e <id>.png (retrato).
Requer Pillow.
"""
import pathlib
import sys

from PIL import Image

RAIZ = pathlib.Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "arte/personagens"
QUADRO = (1024, 1536)  # 2:3, o quadro do corpo no diálogo
RETRATO = 512
ALFA_ZERO = 16  # abaixo disso a franja some
ALFA_CHEIO = 245  # acima disso o pixel é opaco


def limpar(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    a = im.getchannel("A").point(lambda v: 0 if v < ALFA_ZERO else (255 if v >= ALFA_CHEIO else v))
    im.putalpha(a)
    return im


def no_quadro(im: Image.Image) -> Image.Image:
    """Escala uniforme pela altura do quadro; recorta os lados em volta da figura."""
    if im.size == QUADRO:
        return im
    k = QUADRO[1] / im.height
    im = im.resize((round(im.width * k), QUADRO[1]), Image.LANCZOS)
    caixa = im.getchannel("A").getbbox() or (0, 0, im.width, im.height)
    centro = (caixa[0] + caixa[2]) / 2
    x0 = int(min(max(centro - QUADRO[0] / 2, 0), max(im.width - QUADRO[0], 0)))
    quadro = Image.new("RGBA", QUADRO, (0, 0, 0, 0))
    quadro.alpha_composite(im.crop((x0, 0, x0 + min(QUADRO[0], im.width), QUADRO[1])),
                           ((QUADRO[0] - min(QUADRO[0], im.width)) // 2, 0))
    return quadro


def retrato(im: Image.Image) -> Image.Image:
    """Rosto: quadrado do topo da figura, a 40% da largura do quadro."""
    caixa = im.getchannel("A").getbbox()
    lado = int(QUADRO[0] * 0.42)
    topo = max(caixa[1], 0) + int(lado * 0.08)
    linha = im.getchannel("A").crop((0, topo + lado // 2, im.width, topo + lado // 2 + 1))
    xs = [x for x in range(im.width) if linha.getpixel((x, 0)) > 128]
    cx = (min(xs) + max(xs)) // 2 if xs else im.width // 2
    return im.crop((cx - lado // 2, topo, cx + lado // 2, topo + lado)).resize((RETRATO, RETRATO), Image.LANCZOS)


def main(args: list[str]) -> int:
    if len(args) < 3:
        print(__doc__)
        return 1
    pasta, ident = pathlib.Path(args[0]), args[1]
    (SAIDA / "corpo").mkdir(parents=True, exist_ok=True)
    for par in args[2:]:
        pose, arquivo = par.split("=", 1)
        im = no_quadro(limpar(Image.open(pasta / arquivo)))
        nome = ident if pose == "base" else f"{ident}_{pose}"
        im.save(SAIDA / "corpo" / f"{nome}.webp", quality=90, method=6)
        if pose == "base":
            retrato(im).save(SAIDA / f"{ident}.png", optimize=True)
        print(f"{nome}: {arquivo}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
