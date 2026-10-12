#!/usr/bin/env python3
"""Pacote de pedido de imagens para o ChatGPT: os dirigentes das dez equipes do
The Grid (decisão 67, em primeiro plano na ficha da equipe) e os pilotos
genéricos que faltam (decisão 72: todo piloto usa um de 12 genéricos; os 01–08
são os candidatos aprovados). Pessoas, no estilo de arte aprovado: o dos
personagens da história (arte/personagens) e dos genéricos já feitos, que vão
como referência.

Escreve build/pedido_arte_grid.zip com:
  LEIA-ME.md        como pedir no ChatGPT (português)
  PROMPTS.md        um pedido por imagem, em inglês, pronto para colar
  pedidos.json      os mesmos pedidos, com nome de arquivo e destino
  referencias/      estilo (retratos e corpos aprovados) e o emblema de cada equipe
Parte 1: os dirigentes do Grid. Parte 2: os pilotos genéricos. Ao receber, salve
cada PNG com o nome pedido numa pasta e rode tools/importar_arte_grid.py <pasta>:
ele recorta/escala (sem distorcer), tira o fundo magenta e põe cada um no lugar
(do genérico, o corpo e o retrato recortado dele).
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

# Decisão 72: os pilotos usam 12 retratos genéricos (arte/pilotos/genericos).
# Os 01–08 são os 8 candidatos aprovados; faltam os 09–12, pedidos de corpo
# inteiro (o retrato sai recortado do próprio corpo, como nos 01–08). Macacão em
# cores neutras: o mesmo rosto aparece em equipes diferentes.
GENERICOS = {
    9: "woman, early 30s, East Asian, short asymmetric black hair, focused level gaze; charcoal and "
       "teal racing suit with off-white panels",
    10: "man, mid 50s, weathered white veteran, close grey beard, deep-set calm eyes; burgundy and "
        "graphite racing suit with sand-coloured panels",
    11: "woman, early 40s, Black, dark braids tied back, steady confident half-smile; olive and black "
        "racing suit with orange accents",
    12: "man, early 20s, pale with freckles and messy copper-red hair, restless eager grin; light grey and "
        "royal-blue racing suit with white panels",
}

TAM_DIRIGENTE = (720, 1080)   # 2:3 (pedido 1024x1536)
TAM_PILOTO = (240, 280)       # o retrato dos genéricos (6:7), recortado do corpo
TAM_CORPO = (600, 900)        # o corpo dos genéricos (2:3; pedido 1024x1536)


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
    for n, quem in GENERICOS.items():
        if caminho(f"res://arte/pilotos/genericos/generico_{n:02d}.png").exists():
            continue
        itens.append({
            "parte": 2, "tipo": "piloto genérico", "equipe": "", "nome_equipe": "Genéricos", "nome": f"Genérico {n:02d}",
            "arquivo_pedido": f"generico_{n:02d}.png",
            "destino": f"arte/pilotos/genericos/corpo/generico_{n:02d}.webp",
            "destino_retrato": f"arte/pilotos/genericos/generico_{n:02d}.png",
            "largura_px": TAM_CORPO[0], "altura_px": TAM_CORPO[1],
            "referencias": ["referencias/estilo_aprovado.png", "referencias/corpo_aprovado.png"],
            "prompt": (f"Racing driver for a mobile racing game, one of a set of generic drivers shared by many "
                       f"teams. {quem}. Racing suit with bold angular colour panels, collar closed, no helmet, "
                       f"no gloves. Framing exactly like the attached full-body reference: whole figure standing, "
                       f"front three-quarter view, relaxed neutral stance with arms down, head near the top with a "
                       f"little margin, feet near the bottom, centred with margin on both sides. {ESTILO}"
                       f"{TRANSPARENTE}{SEM_TEXTO}Size 1024x1536 (portrait)."),
        })
    return itens


def png(img):
    b = io.BytesIO()
    img.save(b, "PNG")
    return b.getvalue()


def folha(fs, lado, col, alto=None):
    alto = alto or lado
    o = Image.new("RGB", (col * lado, ((len(fs) + col - 1) // col) * alto), (24, 24, 26))
    for i, f in enumerate(fs):
        im = Image.open(f).convert("RGBA")
        im.thumbnail((lado, alto))
        x, y = (i % col) * lado + (lado - im.size[0]) // 2, (i // col) * alto + (alto - im.size[1])
        o.paste(im, (x, y), im)
    return o


def folha_estilo():
    """Os retratos aprovados (personagens da história e genéricos de piloto),
    lado a lado sobre fundo escuro: a referência de estilo."""
    fs = sorted((RAIZ / "arte/personagens").glob("*.png")) + sorted((RAIZ / "arte/pilotos/genericos").glob("*.png"))
    return folha(fs, 256, 6)


def folha_corpos():
    """Os corpos inteiros dos genéricos aprovados: a referência de enquadramento."""
    return folha(sorted((RAIZ / "arte/pilotos/genericos/corpo").glob("*.webp")), 200, 8, 300)


LEIA_ME = """# Rivais: pedido de imagens (ChatGPT)

Estilo aprovado: o dos personagens da história e dos pilotos genéricos (pessoas, planos
chapados e angulosos). Os retratos de animal antigos foram descartados.

São {n} imagens:
- **Parte 1 — The Grid** ({n1}): os dirigentes das 10 equipes do Grid.
- **Parte 2 — pilotos genéricos** ({n2}): corpo inteiro; todos os pilotos do jogo usam um
  dos 12 genéricos (os 01–08 já existem). O retrato sai recortado do corpo.

## Como pedir
1. Conversa nova no ChatGPT (geração de imagem).
2. Anexe as referências indicadas no prompt: `referencias/estilo_aprovado.png` e o emblema da
   equipe (dirigente) ou `referencias/corpo_aprovado.png` (genérico).
3. Cole o prompt da imagem (PROMPTS.md). Um pedido por imagem; dá para seguir na mesma
   conversa, uma de cada vez, para manter o estilo.
4. Salve com o **nome indicado** (`dirigente_<equipe>.png` ou `generico_NN.png`) numa pasta só.
5. Mande a pasta (ou um zip) de volta: o importador recorta/escala sem distorcer, tira o
   fundo magenta e põe cada arquivo no lugar.

## Conferir antes de aceitar
- Mesmo estilo da folha de referência (pessoas, planos chapados, sem contorno, sem foto-realismo).
- **Nenhum texto, letra, número ou logo** na roupa ou no fundo (a identidade vem das cores).
- Fundo **transparente** (ou magenta chapado #FF00FF).
- Dirigente: da cintura para cima, cabeça inteira com folga. Genérico: corpo inteiro em pé,
  da cabeça aos pés, como `corpo_aprovado.png`, com folga nas laterais.
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
        for parte, titulo in [(1, "Parte 1 — The Grid"), (2, "Parte 2 — pilotos genéricos")]:
            lista.append(f"\n### {titulo}")
            lista += [f"- {i['nome_equipe']} · `{i['arquivo_pedido']}` · {i['tipo']} · {i['nome']}"
                      for i in itens if i["parte"] == parte]
        z.writestr("LEIA-ME.md", LEIA_ME.format(n=len(itens), n1=sum(i["parte"] == 1 for i in itens),
                                                n2=sum(i["parte"] == 2 for i in itens), lista="\n".join(lista)))
        md = ["# Prompts (one image per request)", ""]
        for parte, titulo in [(1, "Part 1 — The Grid"), (2, "Part 2 — generic drivers")]:
            md += [f"# {titulo}", ""]
            for i in [i for i in itens if i["parte"] == parte]:
                md += [f"## {i['arquivo_pedido']} ({i['tipo']}: {i['nome']}, {i['nome_equipe']})", "",
                       f"Attach: {', '.join(i['referencias'])}", "", "```", i["prompt"], "```", ""]
        z.writestr("PROMPTS.md", "\n".join(md))
        z.writestr("pedidos.json", json.dumps(itens, ensure_ascii=False, indent=1))
        z.writestr("referencias/estilo_aprovado.png", png(folha_estilo()))
        z.writestr("referencias/corpo_aprovado.png", png(folha_corpos()))
        for e in [e for e in rivais() if e["id"] in DIRIGENTES]:
            logo = caminho(e.get("logo", ""))
            if logo.exists():
                z.writestr(f"referencias/emblemas/{e['id']}.png", png(Image.open(logo).convert("RGBA")))
    print(f"{saida} ({len(itens)} pedidos)")


if __name__ == "__main__":
    main()
