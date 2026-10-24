#!/usr/bin/env python3
"""Gera o pacote de pedidos do kit de arte das pistas para o agente de imagem.

Lê arte/pistas/kit_manifesto.json e escreve build/pedido_arte_pistas.zip com:
  LEIA-ME.txt            instruções em português (para quem opera o agente)
  INSTRUCOES_AGENTE.txt  mensagem inicial para o agente, em inglês
  PEDIDOS.md             um pedido por arquivo, em inglês, pronto para colar
  pedidos.json           os mesmos pedidos, para uso em lote
  kit_manifesto.json     a lista oficial (nome, tipo, tamanho, metros)
  referencia_estilo.png  docs/referencias/pista_estilo.png
  provisorios/*.png      o kit provisório: orientação e proporção de cada arquivo
Uso: python3 tools/pacote_arte_pistas.py [--saida=caminho.zip] [--so=nome1,nome2]
  --so: só esses arquivos (pedido de refação).
"""
import json
import sys
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
MANIFESTO = RAIZ / "arte/pistas/kit_manifesto.json"
REFERENCIA = RAIZ / "docs/referencias/pista_estilo.png"
PROVISORIOS = RAIZ / "arte/pistas/kit"

ESTILO = (
    "Style: painted digital art for a top-down mobile racing game, matching the attached "
    "reference image (a forest race circuit seen from directly above). Clean painterly "
    "surfaces, soft brush texture, few fine details, readable on a phone screen. "
    "Orthographic view from straight above (90 degrees, no perspective, no horizon). "
    "Neutral daylight colours: do NOT bake in the sunset/orange tint of the reference, "
    "the game applies the time-of-day tint itself. No text, numbers, logos, brands, "
    "readable signs or cars."
)

REGRA_TIPO = {
    "textura": (
        "Output: one square seamless tileable texture filling the whole canvas edge to edge, "
        "no border, no vignette, no objects, no painted lines, even lighting. Opposite edges "
        "must match so it repeats without a visible seam. It covers {m0:g} x {m1:g} metres of "
        "ground, so details must have that real-world scale."
    ),
    "faixa": (
        "Output: a strip texture that repeats vertically along the track, {m0:g} m wide and "
        "{m1:g} m long, filling the whole canvas, top and bottom edges must connect seamlessly."
    ),
    "sprite": (
        "Output: a single object centred on a fully TRANSPARENT background (PNG with alpha); "
        "if transparency is impossible, use a flat pure magenta #FF00FF background with no "
        "gradient. The object fills most of the canvas with a small margin, its footprint "
        "proportions are {m0:g} m wide by {m1:g} m tall (keep this width:height ratio). "
        "Soft internal shading lit from the top-left. NO cast shadow on the ground "
        "(the game draws shadows)."
    ),
}


def tela(item):
    """Tamanho de tela do gerador mais próximo da proporção pedida."""
    if item["tipo"] != "sprite":
        return "1024x1024"
    r = item["largura_px"] / item["altura_px"]
    if r > 1.2:
        return "1536x1024"
    if r < 0.83:
        return "1024x1536"
    return "1024x1024"


def pedido(item):
    m0, m1 = item["metros"]
    return {
        "arquivo": item["nome"] + ".png",
        "tela": tela(item),
        "prompt": "Subject: %s.\n%s\n%s" % (
            item["descricao"], REGRA_TIPO[item["tipo"]].format(m0=m0, m1=m1), ESTILO),
    }


INSTRUCOES_AGENTE = """You are producing the environment art kit for "Second Drive", a top-down mobile racing game.
The game does not use painted tracks: it assembles every circuit from this kit (ground textures and
top-down objects) along the exact track layout. So each file must work on its own and be consistent
with all the others.

Attached: referencia_estilo.png (target look and finish), kit_manifesto.json (the official list),
provisorios/ (crude placeholders showing the orientation and proportions of each file),
PEDIDOS.md (one prompt per file).

Rules for every file:
- File name exactly as listed (e.g. arvore_1.png). PNG.
- View from directly above, orthographic. No perspective.
- Neutral daylight colours; the game adds the dusk/night tint and vignette.
- Textures: seamless, tileable, no objects, no lines, no border.
- Objects: transparent background (or flat magenta #FF00FF if transparency is impossible),
  one object per image, centred, lit softly from the top-left, NO cast shadow.
- Keep the orientation of the placeholder (e.g. truck cab at the top, pit garage door at the bottom).
- No text, numbers, logos, brands, readable signs, no cars, nothing from existing games or real circuits.
- Keep the same palette, brush and level of detail across the whole kit: generate the textures first,
  then the trees and rocks, then the buildings, comparing each new file with the previous ones.

Deliver all files in one folder or zip, named as in the list. Exact pixel size is not required:
the game's importer resizes and trims, but it rejects objects without a transparent (or magenta) background.
"""

LEIA_ME = """PEDIDO DO KIT DE ARTE DAS PISTAS — Second Drive

O jogo monta todas as pistas a partir deste kit (texturas de chão e objetos vistos de cima).
Trocar estes arquivos muda a cara de todas as pistas de uma vez.

Como usar com o agente do ChatGPT:
1. Envie ao agente: INSTRUCOES_AGENTE.txt (como primeira mensagem), referencia_estilo.png,
   kit_manifesto.json e a pasta provisorios/.
2. Peça os arquivos na ordem de PEDIDOS.md (texturas, depois árvores e rochas, depois
   construções). Cada pedido já traz o nome do arquivo, o tamanho de tela e o prompt.
   pedidos.json tem o mesmo conteúdo para uso em lote.
3. Junte os PNG numa pasta, com os nomes exatos, e me mande (zip). O importador do jogo
   redimensiona, recorta, corrige emenda de textura e remove fundo magenta; o que vier sem
   fundo transparente volta para refazer, com o relatório dizendo o motivo.

O que observar antes de mandar:
- Vista de cima de verdade, sem perspectiva.
- Sem sombra projetada nos objetos (o jogo faz a sombra).
- Cores de dia, neutras (o jogo aplica o entardecer).
- Sem texto, logotipo, marca ou carro.
- Mesma paleta e mesmo pincel em todos os arquivos.

Total: {n} arquivos ({t} texturas, {f} faixa, {s} objetos).
"""

REFACAO = """REFAÇÃO: este pacote pede só os arquivos abaixo, para substituir os atuais (pasta
atuais/ mostra a versão que precisa mudar). Mesmas regras do kit; mesma paleta e pincel
dos arquivos já aprovados.

"""

ORDEM = {"textura": 0, "faixa": 1, "sprite": 2}
GRUPO = [("arvore", 0), ("pinheiro", 0), ("rocha", 0), ("poste", 2)]


def chave(item):
    sub = 1
    for prefixo, g in GRUPO:
        if item["nome"].startswith(prefixo):
            sub = g
    return (ORDEM[item["tipo"]], sub, item["nome"])


def main():
    saida = RAIZ / "build/pedido_arte_pistas.zip"
    so = set()
    for a in sys.argv[1:]:
        if a.startswith("--saida="):
            saida = Path(a.split("=", 1)[1]).resolve()
        elif a.startswith("--so="):
            so = set(a.split("=", 1)[1].split(","))
    itens = sorted(json.loads(MANIFESTO.read_text(encoding="utf-8")), key=chave)
    if so:
        faltam = so - {i["nome"] for i in itens}
        if faltam:
            sys.exit("fora do manifesto: %s" % ", ".join(sorted(faltam)))
        itens = [i for i in itens if i["nome"] in so]
    pedidos = [pedido(i) for i in itens]
    md = ["# Pedidos — kit de arte das pistas (Second Drive)", "",
          "Order: textures, kerb strip, trees and rocks, then buildings and props.", ""]
    for k, p in enumerate(pedidos, 1):
        md += ["## %d. %s" % (k, p["arquivo"]), "", "Canvas: %s" % p["tela"], "", "```", p["prompt"], "```", ""]
    cont = {t: sum(1 for i in itens if i["tipo"] == t) for t in ORDEM}
    saida.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(saida, "w", zipfile.ZIP_DEFLATED) as z:
        leia = LEIA_ME.format(n=len(itens), t=cont["textura"], f=cont["faixa"], s=cont["sprite"])
        if so:
            leia = REFACAO + leia
        z.writestr("LEIA-ME.txt", leia)
        z.writestr("INSTRUCOES_AGENTE.txt", INSTRUCOES_AGENTE)
        z.writestr("PEDIDOS.md", "\n".join(md))
        z.writestr("pedidos.json", json.dumps(pedidos, indent=1, ensure_ascii=False))
        z.write(MANIFESTO, "kit_manifesto.json")
        z.write(REFERENCIA, "referencia_estilo.png")
        for i in itens:
            png = PROVISORIOS / (i["nome"] + ".png")
            if png.exists():
                z.write(png, ("atuais/" if so else "provisorios/") + png.name)
    print("%s: %d pedidos" % (saida, len(pedidos)))


if __name__ == "__main__":
    main()
