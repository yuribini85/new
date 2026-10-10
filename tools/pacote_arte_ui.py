#!/usr/bin/env python3
"""Gera o pacote de pedidos da arte da interface para o agente de imagem.

Lê arte/ui/ui_manifesto.json e escreve build/pedido_arte_ui.zip com:
  LEIA-ME.txt            instruções em português (para quem opera o agente)
  INSTRUCOES_AGENTE.txt  mensagem inicial para o agente, em inglês
  PEDIDOS.md             um pedido por arquivo, em inglês, pronto para colar
  pedidos.json           os mesmos pedidos, para uso em lote
  ui_manifesto.json      a lista oficial (nome, tipo, tamanho, uso)
  referencias/*.webp     as três telas de referência (docs/referencias/ui_*.webp)
Uso: python3 tools/pacote_arte_ui.py [--saida=caminho.zip] [--so=nome1,nome2]
"""
import json
import sys
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
MANIFESTO = RAIZ / "arte/ui/ui_manifesto.json"
REFERENCIAS = sorted((RAIZ / "docs/referencias").glob("ui_*.webp"))

PALETA = ("Palette of the attached reference screens: dark graphite and navy (#14171C, #1E2228), "
          "warm off-white (#E8E2D4) and ochre accent (#D6A23E).")
SEM_TEXTO = "No text, letters, numbers, logos, brands or readable signs anywhere in the image."
TRANSPARENTE = ("Fully TRANSPARENT background (PNG with alpha); if transparency is impossible, a flat pure "
                "magenta #FF00FF background with no gradient. No shadow on the background.")

REGRA_TIPO = {
    "icone": ("Output: one game UI icon, centred, filling about 80% of a square canvas. Bold simple "
              "silhouette, flat shapes with soft painted shading, thick dark outline (#1A1D22), mostly "
              "off-white with amber details, readable at 48 px on a dark background. Same stroke weight "
              "and lighting (from the top-left) as every other icon of the set. " + TRANSPARENTE),
    "miniatura": ("Output: a painted illustration of the object, three-quarter view, on a dark graphite "
                  "workshop background with a soft warm rim light, muted realistic colours like the "
                  "part thumbnails in the garage reference screen. The object fills the frame with a "
                  "small margin. Opaque background."),
    "banner": ("Output: a wide painted cinematic illustration, muted desaturated colours, warm amber lights "
               "against dark graphite and navy, soft painterly brushwork like the track banners in the "
               "competitions reference screen. Keep the left third calmer and darker: the game writes "
               "the race name and prize over it. Important content in the middle horizontal band (the "
               "game may crop top and bottom). No cars, no people."),
    "fundo": ("Output: a painted cinematic background, muted desaturated colours, dusk or night light, warm "
              "amber lights against dark graphite and navy, soft painterly brushwork like the reference "
              "screens. Calm, low detail where the game places text and the car. No cars, no people."),
    "emblema": ("Output: a blank badge shape for a championship, metallic off-white with amber trim, "
                "centred, filling about 80% of the canvas; the game tints it and writes the name, so the "
                "inner area must stay plain. " + TRANSPARENTE),
    "silhueta": ("Output: a single dark silhouette (one dark tone with a thin warm rim light), full body, "
                 "centred, feet near the bottom edge, no face details. " + TRANSPARENTE),
}


def tela(item):
    """Tamanho de tela do gerador mais próximo da proporção pedida."""
    r = item["largura_px"] / item["altura_px"]
    if r > 1.2:
        return "1536x1024"
    if r < 0.83:
        return "1024x1536"
    return "1024x1024"


def pedido(item):
    return {
        "arquivo": item["nome"] + ".png",
        "tela": tela(item),
        "prompt": "Subject: %s.\n%s\n%s\n%s" % (item["descricao"], REGRA_TIPO[item["tipo"]], PALETA, SEM_TEXTO),
    }


INSTRUCOES_AGENTE = """You are producing the interface art for "Second Drive", a mobile racing game (portrait screen).
Attached: three reference screens (referencias/) showing the target look: dark graphite UI, warm amber
accents, painted dusk illustrations, bold simple icons. ui_manifesto.json is the official list and
PEDIDOS.md has one prompt per file.

Rules for every file:
- File name exactly as listed (e.g. icone_potencia.png). PNG.
- NO text, letters, numbers, logos or brands in any image: the game writes all text (the reference
  screens contain text only to show the layout; do not copy it, and the game name there is misspelled).
- Icons, badges and silhouettes: transparent background (or flat magenta #FF00FF if transparency is
  impossible), centred, one consistent icon style for the whole set (same outline weight, same two
  tones, same light from the top-left).
- Thumbnails: opaque dark workshop background, consistent framing across all parts and tyres.
- Banners and backgrounds: painted, muted, dusk/night, no cars, no people, calm areas for text.
- Nothing recognisable from real circuits, real brands or other games.

Order: icons first (keep them as one family), then part and tyre thumbnails, then badges and
silhouettes, then banners and backgrounds. Deliver all files in one folder or zip, named as listed.
Exact pixel size is not required: the game's importer resizes and trims.
"""

LEIA_ME = """PEDIDO DA ARTE DA INTERFACE — Second Drive

Ícones, miniaturas das peças e pneus, banners das pistas, fundos das telas, emblemas de campeonato e
silhuetas do pódio. Base: as três telas de referência (pasta referencias/) e o glossário novo
(docs/linguagem.md): a arte não tem texto, porque os textos são do jogo.

Como usar com o agente do ChatGPT:
1. Envie ao agente: INSTRUCOES_AGENTE.txt (como primeira mensagem), a pasta referencias/ e
   ui_manifesto.json.
2. Peça na ordem de PEDIDOS.md: primeiro todos os ícones (para saírem como uma família), depois
   miniaturas, emblemas e silhuetas, por último banners e fundos. pedidos.json tem o mesmo conteúdo
   para uso em lote.
3. Junte os PNG numa pasta com os nomes exatos e me mande (zip).

O que observar antes de mandar:
- Nenhum texto, letra ou número na arte (inclusive "KG" no peso, "SECOND DRIVER" nas placas).
- Ícones parecidos entre si: mesmo traço, mesmas duas cores, mesma luz.
- Fundos e banners sem carros e sem pessoas.
- Nada de marca, logotipo ou lugar real reconhecível.

Total: {n} arquivos ({resumo}).
"""

ORDEM = {"icone": 0, "miniatura": 1, "emblema": 2, "silhueta": 3, "banner": 4, "fundo": 5}


def main():
    saida = RAIZ / "build/pedido_arte_ui.zip"
    so = set()
    for a in sys.argv[1:]:
        if a.startswith("--saida="):
            saida = Path(a.split("=", 1)[1]).resolve()
        elif a.startswith("--so="):
            so = set(a.split("=", 1)[1].split(","))
    itens = sorted(json.loads(MANIFESTO.read_text(encoding="utf-8")), key=lambda i: (ORDEM[i["tipo"]], i["nome"]))
    if so:
        faltam = so - {i["nome"] for i in itens}
        if faltam:
            sys.exit("fora do manifesto: %s" % ", ".join(sorted(faltam)))
        itens = [i for i in itens if i["nome"] in so]
    pedidos = [pedido(i) for i in itens]
    md = ["# Pedidos — arte da interface (Second Drive)", "",
          "Order: icons, thumbnails, badges, silhouettes, banners, backgrounds.", ""]
    for k, (i, p) in enumerate(zip(itens, pedidos), 1):
        md += ["## %d. %s" % (k, p["arquivo"]), "", "Canvas: %s · final size %dx%d px" % (
            p["tela"], i["largura_px"], i["altura_px"]), "", "```", p["prompt"], "```", ""]
    contagem = {}
    for i in itens:
        contagem[i["tipo"]] = contagem.get(i["tipo"], 0) + 1
    nomes = {"icone": "ícones", "miniatura": "miniaturas", "emblema": "emblemas", "silhueta": "silhuetas",
             "banner": "banners", "fundo": "fundos"}
    resumo = ", ".join("%d %s" % (contagem[t], nomes[t]) for t in ORDEM if t in contagem)
    saida.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(saida, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("LEIA-ME.txt", LEIA_ME.format(n=len(itens), resumo=resumo))
        z.writestr("INSTRUCOES_AGENTE.txt", INSTRUCOES_AGENTE)
        z.writestr("PEDIDOS.md", "\n".join(md))
        z.writestr("pedidos.json", json.dumps(pedidos, indent=1, ensure_ascii=False))
        z.write(MANIFESTO, "ui_manifesto.json")
        for r in REFERENCIAS:
            z.write(r, "referencias/" + r.name)
    print("%s: %d pedidos (%s)" % (saida, len(pedidos), resumo))


if __name__ == "__main__":
    main()
