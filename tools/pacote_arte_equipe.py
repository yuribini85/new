#!/usr/bin/env python3
"""Gera o pacote de pedidos de arte da história: retratos, logos das equipes e o
ícone da aba Equipe, no estilo pedido pelo usuário ("estilo Kentucky").

Lê data/personagens.json, data/equipes.json e data/carreira.json (segundo piloto)
e escreve build/pedido_arte_equipe.zip com:
  LEIA-ME.txt            instruções em português (para quem opera o agente)
  INSTRUCOES_AGENTE.txt  mensagem inicial para o agente, em inglês
  PEDIDOS.md             um pedido por arquivo, em inglês, pronto para colar
  pedidos.json           os mesmos pedidos, para uso em lote
Os nomes de arquivo são os caminhos que os dados já usam: a arte entra no jogo
só pondo o PNG no lugar (visual/assets.gd), sem mexer em código.
Uso: python3 tools/pacote_arte_equipe.py [--saida=caminho.zip] [--so=retratos|logos|icone]
"""
import json
import sys
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent

# Estilo pedido pelo usuário, descrito em traços (sem citar obra nenhuma).
ESTILO = ("Art style: minimalist, theatrical and melancholic. Flat geometric shapes with few planes, "
          "strong clean silhouettes, faces simplified to a handful of shapes (no fine detail, no "
          "photorealism), a limited muted palette (deep navy, graphite, dusty teal, faded ochre) lit by "
          "one warm light source with hard stage-like shadows, quiet magical-realist mood. Every image of "
          "the set must look like it belongs to the same series.")
SEM_MARCA = ("Original design only: no real people, no real team, brand, car maker or sponsor, no logos "
             "of any kind on clothing, no readable text, letters or numbers.")
TRANSPARENTE = ("Fully TRANSPARENT background (PNG with alpha); if transparency is impossible, a flat pure "
                "magenta #FF00FF background with no gradient.")

# Quem é cada um (roteiro de diálogos, "Voz dos personagens"), em termos visuais.
PERSONAGENS = {
    "adrian": "Adrian Cross, young racing driver, Elena's brother; instinctive, competitive, light-hearted, "
              "a confident half smile; racing suit open at the collar, helmet under the arm.",
    "elena": "Elena Cross, young racing driver; analytical, precise, reserved, steady direct gaze, no "
             "attempt to look tough; plain racing suit, hair tied back.",
    "marcus": "Marcus Reed, veteran race mechanic and family friend; pragmatic, dry humour; work "
              "overalls with rolled sleeves, a rag over the shoulder.",
    "victor": "Victor Hale, director of the top factory team; professional, rational, polite; dark "
              "tailored suit, no tie, calm and controlled.",
    "lucas": "Lucas Ward, lead driver of the top factory team; a legitimate, respectful rival, quiet "
             "confidence; immaculate team racing suit.",
    "sophie": "Sophie Laurent, finance and commercial manager of a small racing team; sharp, practical; "
              "smart casual blazer, a tablet in hand.",
    "vendedor": "Used-car dealer of a modest second-hand lot; friendly and tired; cheap jacket, keys "
                "on a ring.",
    "responsavel": "Instructor of a racing licence academy; neutral and formal; plain uniform polo, "
                   "a stopwatch.",
    "jornalista": "Motorsport journalist; curious, a notebook and a small recorder.",
}

TAM_RETRATO = (480, 560)
TAM_LOGO = (512, 512)
TAM_ICONE = (256, 256)


def ler(nome):
    return json.loads((RAIZ / "data" / nome).read_text(encoding="utf-8"))


def arquivo(caminho):
    return caminho.replace("res://", "")


def retrato(ident, caminho, quem):
    return {
        "arquivo": arquivo(caminho), "tipo": "retrato", "id": ident,
        "largura_px": TAM_RETRATO[0], "altura_px": TAM_RETRATO[1],
        "prompt": (f"Portrait for a mobile racing game dialogue box: {quem} Head and shoulders, facing "
                   f"slightly to the side, centred, eyes at about one third from the top. {ESTILO} "
                   f"Plain dark background with a soft gradient. {SEM_MARCA} "
                   f"Final size {TAM_RETRATO[0]}x{TAM_RETRATO[1]} px."),
    }


def pedidos(so=""):
    itens = []
    if so in ("", "retratos"):
        for p in ler("personagens.json"):
            if p["id"] in PERSONAGENS and p.get("retrato"):
                itens.append(retrato(p["id"], p["retrato"], PERSONAGENS[p["id"]]))
        vistos = {i["arquivo"] for i in itens}
        for e in ler("equipes.json"):
            nivel = e.get("nivel", "the player's own small team")
            for k, pil in enumerate(e["pilotos"]):
                if not pil.get("retrato") or arquivo(pil["retrato"]) in vistos:
                    continue
                papel = ("lead driver", "second driver", "reserve driver")[min(k, 2)]
                quem = (f"{pil['nome']}, {papel} of the fictional team {e['nome']} ({nivel} level); racing "
                        f"suit in the team's colour (the same colour for every driver of {e['nome']}).")
                itens.append(retrato(pil["id"], pil["retrato"], quem))
                vistos.add(arquivo(pil["retrato"]))
        seg = ler("carreira.json").get("equipe_jogador", {}).get("segundo_piloto")
        if seg and seg.get("retrato") and arquivo(seg["retrato"]) not in vistos:
            itens.append(retrato(seg["id"], seg["retrato"], f"{seg['nome']}, second driver of the "
                                 "player's small team Second Driver; plain racing suit, earnest."))
    if so in ("", "logos"):
        for e in ler("equipes.json"):
            if not e.get("logo"):
                continue
            nivel = e.get("nivel", "the player's own independent team")
            itens.append({
                "arquivo": arquivo(e["logo"]), "tipo": "logo", "id": e["id"],
                "largura_px": TAM_LOGO[0], "altura_px": TAM_LOGO[1],
                "prompt": (f"Emblem for the fictional racing team \"{e['nome']}\" ({nivel} level) in a "
                           f"mobile racing game. A simple bold symbol that evokes the name, two or three "
                           f"flat colours, centred, filling about 80% of the canvas, readable at 64 px. "
                           f"The game writes the team name next to it, so the emblem has NO text. "
                           f"{ESTILO} {SEM_MARCA} {TRANSPARENTE} Final size {TAM_LOGO[0]}x{TAM_LOGO[1]} px."),
            })
    if so in ("", "icone"):
        itens.append({
            "arquivo": "arte/ui/aba_equipe.png", "tipo": "icone", "id": "aba_equipe",
            "largura_px": TAM_ICONE[0], "altura_px": TAM_ICONE[1],
            "prompt": ("Game UI icon for the 'Team' tab of a mobile racing game: two racing helmets side by "
                       "side, one slightly ahead. Same look as the other tab icons of the game: bold simple "
                       "silhouette, flat shapes with soft painted shading, thick dark outline (#1A1D22), "
                       "mostly off-white with ochre (#D6A23E) details, light from the top-left, readable at "
                       f"48 px on a dark background. No text. {TRANSPARENTE} "
                       f"Final size {TAM_ICONE[0]}x{TAM_ICONE[1]} px."),
        })
    return itens


INSTRUCOES = """You will create artwork for a mobile racing game. Each request below names the exact output
file, its size and its prompt. Keep ONE consistent style across all portraits and all team emblems (the
style is described in every prompt). Deliver PNG files named exactly as requested, in the same folders,
all together in one zip. Do not add text, real brands, real people or real teams.
"""

LEIA_ME = """Pedido de arte da história (retratos, logos das equipes, ícone da aba Equipe).

1. Mande INSTRUCOES_AGENTE.txt para o agente de imagem como primeira mensagem.
2. Cole os pedidos de PEDIDOS.md (ou use pedidos.json em lote). Se quiser fixar o estilo, anexe
   junto as suas imagens de referência do estilo Kentucky.
3. Junte os PNG com os nomes e pastas exatos (ex.: arte/pilotos/elena_cross.png) e me mande o zip.
   O jogo mostra cada arquivo assim que ele está no lugar; o que faltar continua com o placeholder.
"""


def main():
    saida = RAIZ / "build/pedido_arte_equipe.zip"
    so = ""
    for a in sys.argv[1:]:
        if a.startswith("--saida="):
            saida = Path(a.split("=", 1)[1])
        elif a.startswith("--so="):
            so = a.split("=", 1)[1]
    itens = pedidos(so)
    md = ["# Pedidos de arte: história e equipes", ""]
    for k, i in enumerate(itens, 1):
        md += [f"## {k}. `{i['arquivo']}` ({i['tipo']}, {i['largura_px']}x{i['altura_px']})", "", i["prompt"], ""]
    saida.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(saida, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("LEIA-ME.txt", LEIA_ME)
        z.writestr("INSTRUCOES_AGENTE.txt", INSTRUCOES)
        z.writestr("PEDIDOS.md", "\n".join(md))
        z.writestr("pedidos.json", json.dumps(itens, ensure_ascii=False, indent=1))
    por_tipo = {}
    for i in itens:
        por_tipo[i["tipo"]] = por_tipo.get(i["tipo"], 0) + 1
    print(f"{saida.relative_to(RAIZ) if saida.is_relative_to(RAIZ) else saida}: {len(itens)} pedidos {por_tipo}")


if __name__ == "__main__":
    main()
