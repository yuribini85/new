#!/usr/bin/env python3
"""Gera o logotipo do Chrome Racing Team (arte/idle/logo.png) com a
identidade do Chrome & Wreckage: a fonte Racing Sans One (ui/fontes) e o ocre
da interface (Aba.COR_DESTAQUE), sobre fundo transparente. "CHROME" em branco
e "RACING TEAM" em ocre, com uma faixa quadriculada embaixo.

Uso: python3 tools/gerar_logo_crt.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
FONTE = RAIZ / "ui" / "fontes" / "RacingSansOne-Regular.ttf"
SAIDA = RAIZ / "arte" / "idle" / "logo.png"
LARGURA = 1440
OCRE = (214, 162, 62, 255)
BRANCO = (242, 238, 228, 255)
SOMBRA = (0, 0, 0, 150)


def texto_largura(d, texto, fonte):
    x0, _, x1, _ = d.textbbox((0, 0), texto, font=fonte)
    return x1 - x0


def main() -> None:
    img = Image.new("RGBA", (LARGURA, 560), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f1 = ImageFont.truetype(str(FONTE), 250)
    f2 = ImageFont.truetype(str(FONTE), 150)
    y = 10
    for texto, fonte, cor in (("CHROME", f1, BRANCO), ("RACING TEAM", f2, OCRE)):
        w = texto_largura(d, texto, fonte)
        x = (LARGURA - w) // 2
        d.text((x + 8, y + 10), texto, font=fonte, fill=SOMBRA)
        d.text((x, y), texto, font=fonte, fill=cor)
        _, t, _, b = d.textbbox((x, y), texto, font=fonte)
        y = b + 24
    # Faixa quadriculada (bandeirada), duas fileiras.
    lado = 26
    n = 34
    x0 = (LARGURA - n * lado) // 2
    for linha in range(2):
        for i in range(n):
            if (i + linha) % 2 == 0:
                d.rectangle([x0 + i * lado, y + linha * lado, x0 + (i + 1) * lado - 1, y + (linha + 1) * lado - 1],
                            fill=BRANCO)
    y += 2 * lado + 8
    img = img.crop((0, 0, LARGURA, y))
    SAIDA.parent.mkdir(parents=True, exist_ok=True)
    img.save(SAIDA)
    print(f"{SAIDA.relative_to(RAIZ)}: {img.size[0]}x{img.size[1]}")


if __name__ == "__main__":
    main()
