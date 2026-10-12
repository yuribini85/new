#!/usr/bin/env python3
"""Gera arte/ui/pintura/digitos.png: os algarismos 0-9 do número de corrida da
pintura (fonte condensada do jogo), lado a lado em células iguais. Canal R = o
algarismo; canal G = o contorno (o algarismo engordado); o shader da lataria
(faixas.gdshaderinc) pinta cada um com a sua cor. Requer Pillow."""
import pathlib

from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAIZ = pathlib.Path(__file__).resolve().parent.parent
FONTE = RAIZ / "ui/fontes/BarlowCondensed-SemiBold.ttf"
SAIDA = RAIZ / "arte/ui/pintura/digitos.png"
CELULA = (128, 192)
CONTORNO = 13  # px de engorda do contorno


def main() -> None:
    fonte = ImageFont.truetype(str(FONTE), 200)
    r = Image.new("L", (CELULA[0] * 10, CELULA[1]), 0)
    d = ImageDraw.Draw(r)
    for k in range(10):
        caixa = d.textbbox((0, 0), str(k), font=fonte)
        w, h = caixa[2] - caixa[0], caixa[3] - caixa[1]
        x = k * CELULA[0] + (CELULA[0] - w) / 2 - caixa[0]
        y = (CELULA[1] - h) / 2 - caixa[1]
        d.text((x, y), str(k), font=fonte, fill=255)
    g = r.filter(ImageFilter.MaxFilter(2 * CONTORNO + 1)).filter(ImageFilter.GaussianBlur(1.2))
    r = r.filter(ImageFilter.GaussianBlur(0.8))
    SAIDA.parent.mkdir(parents=True, exist_ok=True)
    Image.merge("RGB", (r, g, Image.new("L", r.size, 0))).save(SAIDA)
    print(SAIDA.relative_to(RAIZ))


if __name__ == "__main__":
    main()
