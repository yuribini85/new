#!/usr/bin/env python3
"""Gera o pacote de pedidos de arte das cenas da história: os cenários que ficam
atrás dos personagens nos diálogos e as ilustrações de tela cheia dos momentos
marcantes (data/historia.json → cenarios, ilustracoes).

Escreve build/pedido_arte_cenas.zip com:
  LEIA-ME.txt            instruções em português (para quem opera o agente)
  INSTRUCOES_AGENTE.txt  mensagem inicial para o agente, em inglês
  PEDIDOS.md             um pedido por arquivo, em inglês, pronto para colar
  pedidos.json           os mesmos pedidos, para uso em lote
  referencia/            a arte do jogo que define o estilo (fundos e personagens)
Os nomes de arquivo são os caminhos que o jogo já lê (visual/assets.gd): a arte
entra só pondo o arquivo no lugar; até lá, cada cena usa a provisória do catálogo.
Uso: python3 tools/pacote_arte_cenas.py [--saida=caminho.zip]
"""
import json
import sys
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
TAM = (1080, 1920)

# O estilo é o da arte da interface que já está no jogo (arte/ui/fundo_*.png).
ESTILO = ("Art style: match the reference images exactly: painterly digital illustration, semi-realistic, "
          "soft brushwork, warm amber light against deep blue-grey shadows, muted desaturated palette, "
          "atmospheric haze, cinematic lighting, quiet and melancholic mood. Every image of the set must look "
          "like it belongs to the same game.")
SEM_MARCA = ("Original design only: no real brands, car makers, sponsors, teams, tracks or people; no logos; "
             "no readable text, letters or numbers unless the prompt asks for one specific word.")
CENARIO = ("Vertical 9:16 background for a dialogue scene of a mobile game. NO people or animals in it: a "
           "full-body character is drawn on top, standing in the lower centre, and a dialogue box covers the "
           "middle-lower area, so keep the lower 60% simple and without important detail; put the interest "
           "(light, horizon, the place's identity) in the upper third. Eye-level camera.")
ILUSTRACAO = ("Vertical 9:16 full-screen story illustration for a mobile game, shown on its own like a film "
              "still; a text box covers the bottom 20%, so keep that band simple. Cinematic composition with one "
              "clear focal point.")
PERSONAGEM = ("Characters in this world are anthropomorphic animals; follow the character reference images in "
              "referencia/ for species, proportions and racing-suit design, and show them small, from behind or "
              "in silhouette (no close-up faces).")

# Cada lugar e cada momento, em termos visuais.
CENARIOS = {
    "garagem_cross": "The Cross family's small racing garage at golden hour: roller door half open to a mountain "
                     "valley at dusk, a single hanging lamp, tool chests, stacked tyres, worn concrete floor. "
                     "Modest, lived-in, loved.",
    "garagem_cross_noite": "The same small family racing garage at night: door closed, only the hanging lamp on, "
                           "cold blue light from a small window, long shadows, a mug on the workbench.",
    "garagem_vazia": "The same small family racing garage months after a tragedy: the car bay is empty, a dust "
                     "sheet folded on the floor where the car used to be, tools neatly put away, dust in the "
                     "light beam from the half-open door, grey morning light.",
    "oficina_cross": "Workbench corner of the small family garage: brake discs and calipers on a cloth, a torque "
                     "wrench, a parts box, warm task lamp, the car's front wheel just visible at the edge.",
    "box_largada": "Pit lane of a regional race track just before the start: open pit box, tyre warmers, a "
                   "pit board leaning on the wall, the grid visible through the opening, late-afternoon sun, haze.",
    "grid_noite": "Starting grid of a night race seen from the pit wall: floodlights, wet-looking asphalt "
                  "reflecting light, the first corner in the distance, tense and quiet.",
    "podio": "A small regional podium after a race: three steps, confetti on the floor, trophies on the top "
             "step, stands in soft focus, warm sunset light.",
    "second_chance": "\"Second Chance Motors\", a modest used-car lot across the street from a garage: a few old "
                     "sports coupés and hatchbacks under string lights, a tiny office cabin, price tags on "
                     "windscreens (unreadable), dusk.",
    "vector_academy": "A racing licence academy: clean modern training building beside a test track, timing "
                      "screens (no readable numbers), traffic cones, a row of identical white school cars, "
                      "cool morning light with a warm accent.",
    "sala_imprensa": "Small motorsport press room: a table with microphones, a backdrop wall with blank sponsor "
                     "panels, folding chairs, camera flashes frozen as soft light blooms.",
    "paddock_apex": "Paddock of the dominant factory team: immaculate black-and-silver hospitality unit, "
                    "polished floor, identical crates, cold white light, everything expensive and orderly.",
    "escritorio_apex": "Office of the factory team director at the top of the team building: floor-to-ceiling "
                       "window over the track at dusk, minimalist desk with a single contract folder, a scale "
                       "model car, cold elegance.",
    "garagem_second_driver": "A small new independent team garage: second-hand equipment freshly painted in "
                             "amber and graphite, two car bays, a whiteboard with diagrams (no readable text), "
                             "hopeful morning light.",
}
ILUSTRACOES = {
    "anel_do_vale": "Opening shot: a race track winding through a forested mountain valley at the last sunset "
                    "of the season, a single race car small on the straight, long shadows, golden haze. Calm "
                    "before everything changes.",
    "acidente": "Aftermath of a crash, seen from far away and restrained (no gore, no visible driver): the "
                "third corner of a mountain track at night, a damaged safety barrier, yellow flags, the "
                "orange glow of safety-car lights in the rain, marshals as small silhouettes.",
    "capacete_na_bancada": "Close still life: a racing helmet resting on the workbench of a small garage, a "
                           "pair of driving gloves beside it, dust in a beam of grey light, the empty car bay "
                           "blurred behind. Grief without people.",
    "elena_na_porta": "Months later: a young female driver seen from behind, standing at the open roller door of "
                      "the empty family garage, backlit by bright morning light, her shadow stretching into the "
                      "room. A decision, not sadness. " + PERSONAGEM,
    "licenca_club": "Close still life: a brand-new racing licence card lying on a table next to a stopwatch and "
                    "a pair of racing gloves, warm light; the card shows only a photo silhouette and coloured "
                    "bands (no readable text).",
    "placa_second_driver": "A hand-painted sign being finished above the door of a small garage at dusk, the "
                           "two words SECOND DRIVER in amber on graphite (the only text allowed; copy the "
                           "logo in referencia/logo.png), a paint can and a ladder below.",
    "elite": "The highest level reached: an empty starting grid of a huge circuit at night under "
             "floodlights, grandstands full of tiny lights, one small amber car on the front row.",
}


def ler(nome):
    return json.loads((RAIZ / "data" / nome).read_text(encoding="utf-8"))


def pedidos():
    h = ler("historia.json")
    itens = []
    for tipo, cat, desc, base, pasta in (("cenario", h.get("cenarios", {}), CENARIOS, CENARIO, "cenarios"),
                                         ("ilustracao", h.get("ilustracoes", {}), ILUSTRACOES, ILUSTRACAO, "cenas")):
        for ident in cat:
            if ident not in desc:
                sys.exit(f"{ident}: sem descrição em tools/pacote_arte_cenas.py")
            itens.append({
                "arquivo": f"arte/{pasta}/{ident}.webp", "tipo": tipo, "id": ident,
                "largura_px": TAM[0], "altura_px": TAM[1],
                "prompt": f"{base} {desc[ident]} {ESTILO} {SEM_MARCA} Final size {TAM[0]}x{TAM[1]} px.",
            })
    return itens


def referencias():
    """Arte já no jogo que fixa o estilo e os personagens."""
    arqs = ["arte/ui/fundo_garagem.png", "arte/ui/fundo_competicoes.png", "arte/ui/fundo_resultado.png",
            "arte/ui/banner_anel_do_vale.png", "arte/ui/logo.png"]
    for p in ler("personagens.json"):
        r = p.get("retrato", "").replace("res://", "")
        if r:
            corpo = Path(r).parent / "corpo" / (Path(r).stem + ".webp")
            arqs.append(str(corpo))
    return [a for a in arqs if (RAIZ / a).exists()]


INSTRUCOES = """You will create artwork for a mobile racing game: vertical backgrounds for dialogue scenes and
full-screen story illustrations. Each request below names the exact output file, its size and its prompt.
The images in referencia/ are art already in the game: match their style exactly, and use the character
images for anyone who appears. Keep ONE consistent style across the whole set. Deliver the files named
exactly as requested, in the same folders, all together in one zip (WebP or PNG with the same name are
both fine). Do not add text, real brands, real people or real teams.
"""

LEIA_ME = """Pedido de arte das cenas da história (cenários dos diálogos e ilustrações dos momentos marcantes).

1. Mande INSTRUCOES_AGENTE.txt para o agente de imagem como primeira mensagem, com as imagens de
   referencia/ anexadas (são a arte do jogo; fixam o estilo e os personagens).
2. Cole os pedidos de PEDIDOS.md (ou use pedidos.json em lote).
3. Junte os arquivos com os nomes e pastas exatos (ex.: arte/cenarios/garagem_cross.webp) e me mande o
   zip. Cada cena troca para a arte nova assim que o arquivo está no lugar; o que faltar continua com a
   provisória (a arte da interface com um tom de cor).
"""


def main():
    saida = RAIZ / "build/pedido_arte_cenas.zip"
    for a in sys.argv[1:]:
        if a.startswith("--saida="):
            saida = Path(a.split("=", 1)[1])
    itens = pedidos()
    md = ["# Pedidos de arte: cenas da história", ""]
    for k, i in enumerate(itens, 1):
        md += [f"## {k}. `{i['arquivo']}` ({i['tipo']}, {i['largura_px']}x{i['altura_px']})", "", i["prompt"], ""]
    refs = referencias()
    saida.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(saida, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("LEIA-ME.txt", LEIA_ME)
        z.writestr("INSTRUCOES_AGENTE.txt", INSTRUCOES)
        z.writestr("PEDIDOS.md", "\n".join(md))
        z.writestr("pedidos.json", json.dumps(itens, ensure_ascii=False, indent=1))
        for r in refs:
            z.write(RAIZ / r, "referencia/" + Path(r).name)
    por_tipo = {}
    for i in itens:
        por_tipo[i["tipo"]] = por_tipo.get(i["tipo"], 0) + 1
    print(f"{saida.relative_to(RAIZ) if saida.is_relative_to(RAIZ) else saida}: {len(itens)} pedidos {por_tipo}, "
          f"{len(refs)} referências")


if __name__ == "__main__":
    main()
