#!/usr/bin/env python3
"""Gera o logotipo do Chrome Racing Team (arte/idle/logo.png) com a
identidade do Chrome & Wreckage: a fonte Racing Sans One (ui/fontes) e o ocre
da interface (Aba.COR_DESTAQUE), sobre fundo transparente. "CHROME" em branco
e "RACING TEAM" em ocre, com uma faixa quadriculada embaixo. Também os ícones
do app Android (arte/idle/icone_*.png, preset "Android Idle"): "CRT" em ocre
sobre o fundo escuro com a faixa quadriculada.

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


def icones() -> None:
    fundo = (20, 23, 28, 255)
    def quadriculado(d, lado_img, y, lado):
        n = lado_img // lado + 1
        for linha in range(2):
            for i in range(n):
                if (i + linha) % 2 == 0:
                    d.rectangle([i * lado, y + linha * lado, (i + 1) * lado - 1, y + (linha + 1) * lado - 1], fill=OCRE)

    def letras(img, lado_img, escala):
        d = ImageDraw.Draw(img)
        f = ImageFont.truetype(str(FONTE), int(lado_img * 0.42 * escala))
        w = texto_largura(d, "CRT", f)
        _, t, _, b = d.textbbox((0, 0), "CRT", font=f)
        x = (lado_img - w) // 2
        y = (lado_img - (b - t)) // 2 - t - int(lado_img * 0.04)
        d.text((x + lado_img // 60, y + lado_img // 50), "CRT", font=f, fill=SOMBRA)
        d.text((x, y), "CRT", font=f, fill=OCRE)

    # Ícone comum: fundo, faixa quadriculada embaixo e as letras.
    img = Image.new("RGBA", (192, 192), fundo)
    quadriculado(ImageDraw.Draw(img), 192, 140, 12)
    letras(img, 192, 1.0)
    img.save(SAIDA.parent / "icone_192.png")
    # Adaptativo: fundo (com a faixa) e frente (as letras, dentro da área segura).
    bg = Image.new("RGBA", (432, 432), fundo)
    quadriculado(ImageDraw.Draw(bg), 432, 300, 22)
    bg.save(SAIDA.parent / "icone_fundo_432.png")
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    letras(fg, 432, 0.72)
    fg.save(SAIDA.parent / "icone_frente_432.png")
    print("arte/idle/icone_192.png, icone_fundo_432.png, icone_frente_432.png")


if __name__ == "__main__":
    main()
    icones()
