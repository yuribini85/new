#!/usr/bin/env python3
"""Pacote de pedido de imagens dos rivais para o ChatGPT (decisão 67): os
dirigentes das dez equipes do The Grid (em primeiro plano na ficha da equipe) e
os retratos dos pilotos rivais. Pessoas, no estilo de arte aprovado: o dos
personagens da história (arte/personagens) e dos candidatos a segundo piloto
(arte/pilotos), que vão como referência. Os retratos de animal antigos foram
descartados.

Escreve build/pedido_arte_grid.zip com:
  LEIA-ME.md        como pedir no ChatGPT (português)
  PROMPTS.md        um pedido por imagem, em inglês, pronto para colar
  pedidos.json      os mesmos pedidos, com nome de arquivo e destino
  referencias/      estilo (personagens aprovados) e o emblema de cada equipe
Parte 1: o Grid (dirigentes e pilotos das dez equipes). Parte 2: os pilotos das
outras equipes. Ao receber, salve cada PNG com o nome pedido numa pasta e rode
tools/importar_arte_grid.py <pasta>: ele recorta/escala (sem distorcer), tira o
fundo magenta e põe cada um no caminho que data/equipes.json já usa.
Uso: python3 tools/pacote_arte_grid.py [--saida=caminho.zip]
"""
import io
import json
import sys
import zipfile
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent

# O estilo aprovado, descrito em traços (as referências anexas mandam).
ESTILO = ("Art style: match the attached reference portraits exactly (same series). Stylised human "
          "characters built from flat angular planes, like faceted cut paper or a low-poly painting: bold "
          "simplified shapes, faces reduced to a few planes, no outlines, no fine texture, no photorealism. "
          "Muted limited palette (deep navy, graphite, warm ochre, off-white) with the team colours as "
          "accents; one warm key light with hard-edged shadow planes; calm, theatrical, slightly melancholic "
          "mood. Adults, credible proportions (not chibi, not anime, not cartoon). ")
SEM_TEXTO = ("Original design only: no real people, teams, brands, car makers or sponsors. NO text, letters, "
             "numbers or logos anywhere (clothing included); team identity only through the colours and "
             "simple abstract shapes. ")
TRANSPARENTE = ("Background: fully TRANSPARENT (PNG with alpha). If transparency is impossible, a flat pure "
                "magenta #FF00FF background, no gradient, no shadow on it. ")

# Dirigente de cada equipe do Grid: nome (data/equipes.json → dirigente) e quem é.
DIRIGENTES = {
    "eq15_gravelborn": ("Hank Ruddle", "man in his sixties, rally veteran turned team boss; sun-creased "
                        "face, grey stubble, dusty wide-brim hat pushed back, faded work jacket over a shirt, "
                        "arms crossed, squinting as if watching a dirt stage"),
    "eq18_copperhead_racing": ("Silas Varn", "lean man in his fifties with a sly, patient stare; slicked-"
                               "back dark hair, long leather coat, fingers steepled, utterly still"),
    "eq06_redline_union": ("Gus Moreau", "stocky man in his late fifties, shop-floor union boss; thick "
                           "forearms with rolled sleeves on work overalls, grease on the hands, tired but "
                           "defiant jaw, bald with a grey moustache"),
    "eq13_tempest_garage": ("Walt Brennigan", "broad, calm man in his fifties, foreman of a working-class "
                            "garage; work shirt, a wrench held loosely on the shoulder, honest steady eyes, "
                            "short beard"),
    "eq04_ironclad_racing": ("Moss Kettering", "gaunt tall man in his sixties with a hunched, watchful "
                             "posture; heavy padded jacket like armour, bald head, hooked nose, "
                             "calculating eyes"),
    "eq08_black_circuit": ("Lou Tasker", "small wiry man in his sixties in a rumpled suit, loosened tie, a "
                           "gold tooth in a crooked grin; runs the dirtiest pit box in the series"),
    "eq07_northstar_works": ("Astrid Halvorsen", "composed woman in her fifties, strategist of a night-racing "
                             "team; long coat, silver hair in a tight bun, round glasses, a stopwatch on a "
                             "chain, measuring gaze"),
    "eq02_vortex_motorsport": ("Victor Sloane", "powerful broad-shouldered man in his forties in a tailored "
                               "jacket, open collar, shaved head, calm and cold, a businessman of racing"),
    "eq20_storm_division": ("Delphine Arceneaux", "elegant woman in her forties with long dark braided hair; "
                            "velvet blazer with contrasting lapels, gloves in hand, the quiet before a storm"),
    "eq14_crown_vector": ("Augustin Pryce", "aristocratic old man in his seventies; double-breasted coat "
                          "with antique-gold buttons, a cane with a plain gold knob, neat white hair, "
                          "pale polished look of old money, unreadable eyes"),
}

# Pilotos rivais: quem é, em termos visuais (o jeito vem de data/equipes.json).
PILOTOS = {
    "lucien_vale": "man, early 30s, sharp cheekbones, swept dark hair, cool half-lidded look",
    "nadia_voss": "woman, early 30s, platinum hair in a tight braid, composed and exact",
    "ren_kaito": "man, mid 20s, spiky black hair, grin of a straight-line speed addict",
    "hana_mori": "woman, early 20s, short black bob, eager determined eyes",
    "bram_holt": "man, early 40s, big and heavy-set, red beard, ex-karting brawler",
    "soren_pike": "man, mid 30s, lean, ash-blond, patient pale eyes",
    "lucas_ward": "man, late 20s, clean-cut, immaculate, quiet confidence of a factory-team lead driver",
    "cassian_roe": "man, early 30s, curly dark hair, slow calm smile, saves himself for the second half",
    "nyra_sol": "woman, late 20s, shaved sides with a long top, fierce stare",
    "dario_kest": "man, mid 30s, square jaw, shaved head, unshakably calm heavy-lidded eyes",
    "lena_brook": "woman, late 20s, freckles, auburn ponytail, careful and precise",
    "erik_halden": "man, late 30s, neat beard, thoughtful, reads the race like a chessboard",
    "liv_arnesen": "woman, mid 20s, white-blonde undercut, restless half-smile",
    "marek_stone": "man, early 40s, broken nose, toothy smile that looks like a threat",
    "ivy_corran": "woman, early 30s, dark hair with a red streak, a scar on the chin, wary eyes",
    "tomas_reyl": "man, early 50s, greying temples, veteran who knows every paddock shortcut",
    "sasha_imre": "man, late 20s, slick black hair, cold flawless focus",
    "gus_harrow": "man, mid 30s, stocky, quiet, soot-dark stubble",
    "pia_lund": "woman, early 30s, short blonde crop, stern no-nonsense look",
    "viktor_ren": "man, mid 20s, white-dyed hair, explosive grin",
    "yuna_kess": "woman, mid 20s, long silver-white hair, sly sideways glance",
    "oscar_flint": "man, early 40s, neat moustache, polished and patient",
    "mina_rowe": "woman, early 30s, hair in a neat low bun, rule-book precise",
    "noel_mercer": "man, early 30s, wavy brown hair, methodical, steady eyes",
    "zara_keene": "woman, late 20s, dark curls tied up, sharp but careful",
    "elias_wren": "man, early 20s, fair hair, privileged young prodigy eager to prove himself",
    "celeste_armand": "woman, early 30s, long pale-blonde hair, cool aristocratic poise",
    "rafe_calder": "man, mid 30s, sun-tanned rally driver, dusty stubble, patient eyes",
    "nika_stroud": "woman, late 20s, messy short hair, rally grit, nervous energy",
    "theo_maren": "man, late 20s, tall, calm, slow-burning focus",
    "selene_ashby": "woman, early 30s, sleek black hair, poised",
    "magnus_rell": "man, early 40s, big, cold and quiet, close-cropped grey hair",
    "ines_calloway": "woman, late 20s, short spiky hair, ex-karting scrapper",
    "ash_corwin": "man, early 30s, auburn hair, unreadable, unpredictable smirk",
    "cleo_vane": "woman, late 20s, copper-red hair, impatient energy",
    "finn_sutter": "man, mid 30s, weathered sailor-like face, stubborn",
    "kaia_rehn": "woman, early 30s, dark braids, ice-calm stare",
    "rex_arden": "man, early 40s, dark-skinned, imposing, never seems to make a mistake",
    "mira_danvers": "woman, early 30s, fox-red hair, analytical look",
}

TAM_DIRIGENTE = (720, 1080)   # 2:3 (pedido 1024x1536)
TAM_PILOTO = (240, 280)       # o formato de arte/pilotos (6:7; pedido 1024x1024)


def ler(nome):
    return json.loads((RAIZ / "data" / nome).read_text(encoding="utf-8"))


def caminho(res):
    return RAIZ / res.replace("res://", "")


def rivais():
    """Equipes rivais: as do Grid primeiro (#10 → #1), depois as outras."""
    l = [e for e in ler("equipes.json") if not e.get("jogador")]
    return sorted(l, key=lambda e: (e.get("grid") is None, -int(e.get("grid") or 0), e["id"]))


def cores(e):
    c = e.get("cores", {})
    return f"main {c.get('carro', '')}, stripe {c.get('faixa', '')}, pinstripe {c.get('filete', '')}"


def pedidos():
    itens = []
    for e in rivais():
        parte = 1 if e.get("grid") is not None else 2
        rotulo = f"#{e['grid']} of The Grid" if parte == 1 else "rival team"
        refs = ["referencias/estilo_aprovado.png", f"referencias/emblemas/{e['id']}.png"]
        if e["id"] in DIRIGENTES:
            nome, quem = DIRIGENTES[e["id"]]
            itens.append({
                "parte": parte, "tipo": "dirigente", "equipe": e["id"], "nome_equipe": e["nome"], "nome": nome,
                "arquivo_pedido": f"dirigente_{e['id']}.png",
                "destino": f"arte/equipes/dirigentes/{e['id']}.png",
                "largura_px": TAM_DIRIGENTE[0], "altura_px": TAM_DIRIGENTE[1], "referencias": refs,
                "prompt": (f"Team boss of the rival team \"{e['nome']}\" ({rotulo}) in a mobile racing game. "
                           f"{nome}: {quem}. Team colours as accents on the clothing: {cores(e)}. Team "
                           f"temperament: {e.get('personalidade', '')} Framing: waist-up, three-quarter view, "
                           f"whole head with margin above, body cut cleanly at the waist; will be layered in "
                           f"front of two drivers, so a strong readable silhouette. {ESTILO}{TRANSPARENTE}"
                           f"{SEM_TEXTO}Size 1024x1536 (portrait)."),
            })
        for p in e["pilotos"]:
            if not p.get("retrato") or caminho(p["retrato"]).exists():
                continue
            quem = PILOTOS.get(p["id"], "adult racing driver")
            itens.append({
                "parte": parte, "tipo": "piloto", "equipe": e["id"], "nome_equipe": e["nome"], "nome": p["nome"],
                "arquivo_pedido": f"piloto_{p['id']}.png",
                "destino": p["retrato"].replace("res://", ""),
                "largura_px": TAM_PILOTO[0], "altura_px": TAM_PILOTO[1], "referencias": refs,
                "prompt": (f"Racing driver portrait for the rival team \"{e['nome']}\" ({rotulo}) in a mobile "
                           f"racing game. {p['nome']}: {quem}. Personality: {p.get('personalidade', '')} "
                           f"Wearing a racing suit in the team colours ({cores(e)}), collar open, no helmet. "
                           f"Framing exactly like the driver portraits in the bottom rows of the reference sheet: "
                           f"chest-up, a light pose (arms crossed, hand on hip or relaxed), head in the top third "
                           f"with a little margin above, about 8% margin on the left and right (it will be cropped "
                           f"to 6:7). {ESTILO}{TRANSPARENTE}{SEM_TEXTO}Size 1024x1024."),
            })
    return itens


def png(img):
    b = io.BytesIO()
    img.save(b, "PNG")
    return b.getvalue()


def folha_estilo():
    """Os retratos aprovados (personagens da história e candidatos a segundo
    piloto), lado a lado sobre fundo escuro: a referência de estilo."""
    fs = sorted((RAIZ / "arte/personagens").glob("*.png"))
    cand = [c["retrato"] for c in ler("carreira.json").get("equipe_jogador", {}).get("candidatos", [])]
    fs += [caminho(c) for c in cand if caminho(c).exists()]
    lado, col = 256, 6
    o = Image.new("RGB", (col * lado, ((len(fs) + col - 1) // col) * lado), (24, 24, 26))
    for i, f in enumerate(fs):
        im = Image.open(f).convert("RGBA")
        im.thumbnail((lado, lado))
        x, y = (i % col) * lado + (lado - im.size[0]) // 2, (i // col) * lado + (lado - im.size[1])
        o.paste(im, (x, y), im)
    return o


LEIA_ME = """# Rivais: pedido de imagens (ChatGPT)

Estilo aprovado: o dos personagens da história e dos candidatos a segundo piloto (pessoas,
planos chapados e angulosos). Os retratos de animal antigos foram descartados.

São {n} imagens:
- **Parte 1 — The Grid** ({n1}): os 10 dirigentes e os pilotos das 10 equipes do Grid.
- **Parte 2 — outras equipes** ({n2}): os pilotos das demais equipes rivais.

## Como pedir
1. Conversa nova no ChatGPT (geração de imagem).
2. Anexe `referencias/estilo_aprovado.png` e o emblema da equipe (`referencias/emblemas/`).
3. Cole o prompt da imagem (PROMPTS.md). Um pedido por imagem; dá para seguir na mesma
   conversa, uma de cada vez, para manter o estilo.
4. Salve com o **nome indicado** (`dirigente_<equipe>.png` ou `piloto_<id>.png`) numa pasta só.
5. Mande a pasta (ou um zip) de volta: o importador recorta/escala sem distorcer, tira o
   fundo magenta e põe cada arquivo no lugar.

## Conferir antes de aceitar
- Mesmo estilo da folha de referência (pessoas, planos chapados, sem contorno, sem foto-realismo).
- **Nenhum texto, letra, número ou logo** na roupa ou no fundo (a identidade vem das cores).
- Fundo **transparente** (ou magenta chapado #FF00FF).
- Dirigente: da cintura para cima, cabeça inteira com folga. Piloto: do peito para cima,
  como os pilotos de referência (fileiras de baixo), com folga nas laterais (o jogo recorta
  para 6:7).
- Errou (texto na roupa, corte na cabeça, estilo diferente)? Peça de novo citando o problema.

## Lista
{lista}
"""


def main():
    saida = RAIZ / "build" / "pedido_arte_grid.zip"
    for a in sys.argv[1:]:
        if a.startswith("--saida="):
            saida = Path(a.split("=", 1)[1])
    itens = pedidos()
    saida.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(saida, "w", zipfile.ZIP_DEFLATED) as z:
        lista = []
        for parte, titulo in [(1, "Parte 1 — The Grid"), (2, "Parte 2 — outras equipes")]:
            lista.append(f"\n### {titulo}")
            lista += [f"- {i['nome_equipe']} · `{i['arquivo_pedido']}` · {i['tipo']} · {i['nome']}"
                      for i in itens if i["parte"] == parte]
        z.writestr("LEIA-ME.md", LEIA_ME.format(n=len(itens), n1=sum(i["parte"] == 1 for i in itens),
                                                n2=sum(i["parte"] == 2 for i in itens), lista="\n".join(lista)))
        md = ["# Prompts (one image per request)", ""]
        for parte, titulo in [(1, "Part 1 — The Grid"), (2, "Part 2 — other rival teams")]:
            md += [f"# {titulo}", ""]
            for i in [i for i in itens if i["parte"] == parte]:
                md += [f"## {i['arquivo_pedido']} ({i['tipo']}: {i['nome']}, {i['nome_equipe']})", "",
                       f"Attach: {', '.join(i['referencias'])}", "", "```", i["prompt"], "```", ""]
        z.writestr("PROMPTS.md", "\n".join(md))
        z.writestr("pedidos.json", json.dumps(itens, ensure_ascii=False, indent=1))
        z.writestr("referencias/estilo_aprovado.png", png(folha_estilo()))
        for e in rivais():
            logo = caminho(e.get("logo", ""))
            if logo.exists():
                z.writestr(f"referencias/emblemas/{e['id']}.png", png(Image.open(logo).convert("RGBA")))
    print(f"{saida} ({len(itens)} pedidos)")


if __name__ == "__main__":
    main()
