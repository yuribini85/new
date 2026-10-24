#!/usr/bin/env python3
"""Gera arte/ui/pintura/digitos_<familia>.png: os algarismos 0-9 do número de
corrida da pintura, lado a lado em células iguais, numa das cinco famílias
(pacote de identidades das equipes): bloco (Block Racing), condensado (Tall
Condensed), estencil (Stencil Industrial), pincel (Rough Hand-painted) e serifa
(Badge Serif). Canal R = o algarismo; canal G = o contorno (o algarismo
engordado); o shader da lataria (faixas.gdshaderinc) pinta cada um com a sua
cor. Fontes: as do jogo (ui/fontes) e as Liberation (tools/fontes, OFL).
Requer Pillow."""
import pathlib
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAIZ = pathlib.Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "arte/ui/pintura"
CELULA = (128, 192)
CONTORNO = 13  # px de engorda do contorno
FAMILIAS = {
    "condensado": (RAIZ / "ui/fontes/BarlowCondensed-SemiBold.ttf", 200),
    "bloco": (RAIZ / "ui/fontes/RacingSansOne-Regular.ttf", 150),
    "estencil": (RAIZ / "tools/fontes/LiberationSans-Bold.ttf", 158),
    "pincel": (RAIZ / "ui/fontes/RacingSansOne-Regular.ttf", 150),
    "serifa": (RAIZ / "tools/fontes/LiberationSerif-Bold.ttf", 168),
}


def algarismos(fonte: ImageFont.FreeTypeFont) -> Image.Image:
    r = Image.new("L", (CELULA[0] * 10, CELULA[1]), 0)
    d = ImageDraw.Draw(r)
    for k in range(10):
        caixa = d.textbbox((0, 0), str(k), font=fonte)
        w, h = caixa[2] - caixa[0], caixa[3] - caixa[1]
        escala = min(1.0, (CELULA[0] - 2 * CONTORNO - 4) / w)  # cabe na célula (uniforme)
        if escala < 1.0:
            cel = Image.new("L", (w + 8, h + 8), 0)
            ImageDraw.Draw(cel).text((4 - caixa[0], 4 - caixa[1]), str(k), font=fonte, fill=255)
            cel = cel.resize((round(cel.width * escala), round(cel.height * escala)), Image.LANCZOS)
            r.paste(cel, (k * CELULA[0] + (CELULA[0] - cel.width) // 2, (CELULA[1] - cel.height) // 2))
        else:
            d.text((k * CELULA[0] + (CELULA[0] - w) / 2 - caixa[0], (CELULA[1] - h) / 2 - caixa[1]),
                   str(k), font=fonte, fill=255)
    return r


def estencil(r: Image.Image) -> Image.Image:
    """Pontes do estêncil: dois cortes horizontais em cada algarismo."""
    d = ImageDraw.Draw(r)
    for y in (0.37, 0.63):
        yy = int(CELULA[1] * y)
        d.rectangle([0, yy - 4, r.width, yy + 4], fill=0)
    return r


def pincel(r: Image.Image) -> Image.Image:
    """Borda irregular de pintura à mão: ruído na borda e uma leve inclinação por algarismo."""
    rng = random.Random(7)
    saida = Image.new("L", r.size, 0)
    for k in range(10):
        cel = r.crop((k * CELULA[0], 0, (k + 1) * CELULA[0], CELULA[1]))
        cel = cel.rotate(rng.uniform(-4, 4), resample=Image.BICUBIC)
        ruido = Image.effect_noise(cel.size, 140).filter(ImageFilter.GaussianBlur(2.2))
        borda = cel.filter(ImageFilter.GaussianBlur(4.5))
        cel = Image.eval(Image.blend(borda, ruido, 0.5), lambda v: 255 if v > 112 else 0)
        # pinceladas: riscos finos sem tinta atravessando o algarismo
        d = ImageDraw.Draw(cel)
        for _ in range(3):
            y = rng.randint(30, CELULA[1] - 30)
            d.line([(0, y), (CELULA[0], y + rng.randint(-10, 10))], fill=0, width=2)
        saida.paste(cel, (k * CELULA[0], 0))
    return saida


def main() -> None:
    SAIDA.mkdir(parents=True, exist_ok=True)
    for nome, (arquivo, tamanho) in FAMILIAS.items():
        r = algarismos(ImageFont.truetype(str(arquivo), tamanho))
        if nome == "estencil":
            r = estencil(r)
        elif nome == "pincel":
            r = pincel(r)
        g = r.filter(ImageFilter.MaxFilter(2 * CONTORNO + 1)).filter(ImageFilter.GaussianBlur(1.2))
        r = r.filter(ImageFilter.GaussianBlur(0.8))
        Image.merge("RGB", (r, g, Image.new("L", r.size, 0))).save(SAIDA / f"digitos_{nome}.png")
        print(f"arte/ui/pintura/digitos_{nome}.png")


if __name__ == "__main__":
    main()
