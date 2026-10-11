#!/usr/bin/env python3
"""Prepara a arte de um piloto a partir do PNG RGBA de corpo inteiro entregue,
no padrão dos rivais (arte/pilotos/):
  corpo/<id>.webp   corpo inteiro 600 × 900 (2:3), escala uniforme, fundo transparente
  <id>.png          retrato 240 × 280: cabeça e ombros recortados do corpo, sobre o
                    fundo em degradê quente dos outros retratos
Escala sempre uniforme: o corpo de outra proporção é escalado pela altura e
recortado dos lados; o retrato é um recorte do corpo, nunca esticado.

Uso: python3 tools/preparar_piloto.py <arquivo.png> <id> [<arquivo.png> <id>...]
Requer Pillow.
"""
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFilter

RAIZ = pathlib.Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "arte/pilotos"
CORPO = (600, 900)
RETRATO = (240, 280)
ALFA_ZERO = 16  # abaixo disso a franja some
ALFA_CHEIO = 245  # acima disso o pixel é opaco
# Degradê dos retratos (amostrado dos rivais): luz quente no alto, cantos escuros.
LUZ = (150, 92, 58)
SOMBRA = (20, 13, 9)


def limpar(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    a = im.getchannel("A").point(lambda v: 0 if v < ALFA_ZERO else (255 if v >= ALFA_CHEIO else v))
    im.putalpha(a)
    return im


def corpo(im: Image.Image) -> Image.Image:
    """Escala uniforme pela altura; recorta os lados em volta da figura."""
    k = CORPO[1] / im.height
    im = im.resize((round(im.width * k), CORPO[1]), Image.LANCZOS)
    if im.width == CORPO[0]:
        return im
    caixa = im.getchannel("A").getbbox() or (0, 0, im.width, im.height)
    centro = (caixa[0] + caixa[2]) / 2
    quadro = Image.new("RGBA", CORPO, (0, 0, 0, 0))
    if im.width > CORPO[0]:
        x0 = int(min(max(centro - CORPO[0] / 2, 0), im.width - CORPO[0]))
        quadro.alpha_composite(im.crop((x0, 0, x0 + CORPO[0], CORPO[1])))
    else:
        quadro.alpha_composite(im, ((CORPO[0] - im.width) // 2, 0))
    return quadro


def fundo() -> Image.Image:
    f = Image.new("RGB", RETRATO, SOMBRA)
    luz = Image.new("L", RETRATO, 0)
    d = ImageDraw.Draw(luz)
    w, h = RETRATO
    d.ellipse((w * 0.05, -h * 0.35, w * 0.95, h * 0.75), fill=255)
    luz = luz.filter(ImageFilter.GaussianBlur(w * 0.18))
    return Image.composite(Image.new("RGB", RETRATO, LUZ), f, luz)


def retrato(c: Image.Image) -> Image.Image:
    """Cabeça e ombros: do topo da figura, largura de 46% do corpo, 240:280."""
    caixa = c.getchannel("A").getbbox()
    largura = int(CORPO[0] * 0.46)
    altura = round(largura * RETRATO[1] / RETRATO[0])
    topo = max(caixa[1] - int(altura * 0.06), 0)
    # Centro da cabeça: meio da faixa opaca um pouco abaixo do topo.
    linha = c.getchannel("A").crop((0, caixa[1] + 20, c.width, caixa[1] + 21))
    xs = [x for x in range(c.width) if linha.getpixel((x, 0)) > 128]
    cx = (min(xs) + max(xs)) // 2 if xs else c.width // 2
    x0 = min(max(cx - largura // 2, 0), c.width - largura)
    rosto = c.crop((x0, topo, x0 + largura, topo + altura)).resize(RETRATO, Image.LANCZOS)
    r = fundo().convert("RGBA")
    r.alpha_composite(rosto)
    return r.convert("RGB")


def main(args: list[str]) -> int:
    if len(args) < 2 or len(args) % 2:
        print(__doc__)
        return 1
    (SAIDA / "corpo").mkdir(parents=True, exist_ok=True)
    for arquivo, ident in zip(args[::2], args[1::2]):
        c = corpo(limpar(Image.open(arquivo)))
        c.save(SAIDA / "corpo" / f"{ident}.webp", "WEBP", quality=90, method=6)
        retrato(c).save(SAIDA / f"{ident}.png")
        print(f"{ident}: corpo {c.size}, retrato {RETRATO}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
