#!/usr/bin/env python3
"""Pacote de pedido de imagens do The Grid para o ChatGPT (decisão 67): os
dirigentes das dez equipes (em primeiro plano na ficha da equipe) e os retratos
de piloto que faltam nelas. Mesmo estilo dos pilotos rivais já entregues
(arte/pilotos): animal antropomórfico, pintura digital semi-realista, luz quente
de recorte, fundo escuro.

Escreve build/pedido_arte_grid.zip com:
  LEIA-ME.md        como pedir no ChatGPT (português)
  PROMPTS.md        um pedido por imagem, em inglês, pronto para colar
  pedidos.json      os mesmos pedidos, com nome de arquivo e destino
  referencias/      estilo (pilotos atuais), e por equipe o emblema e os pilotos
Ao receber, salve cada PNG com o nome pedido numa pasta e rode
tools/importar_arte_grid.py <pasta>: ele recorta/escala (sem distorcer) e põe
cada um no caminho que data/equipes.json já usa.
Uso: python3 tools/pacote_arte_grid.py [--saida=caminho.zip]
"""
import io
import json
import sys
import zipfile
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent

ESTILO = ("Style: semi-realistic digital painting of an anthropomorphic animal character, the same series "
          "as the attached reference portraits: detailed fur and fabric, painterly brushwork, warm "
          "cinematic rim light from one side, deep shadows, gritty motorsport mood, mature and credible "
          "(not cartoon, not chibi, not cute). ")
SEM_TEXTO = ("Original design only: no real people, teams, brands, car makers or sponsors. NO text, letters, "
             "numbers or logos anywhere (clothing included); team identity only through the colours and "
             "simple abstract shapes. The lettering on the reference suits is outdated: copy their style, "
             "never their words or badges. ")
FUNDO_PILOTO = ("Background: plain dark warm-brown vignette, lighter behind the head, like the references. ")
FUNDO_DIRIGENTE = ("Background: fully TRANSPARENT (PNG with alpha). If transparency is impossible, a flat "
                   "pure magenta #FF00FF background, no gradient, no shadow on it. ")

# Dirigente de cada equipe do Grid: nome (vai para data/equipes.json) e quem é,
# em termos visuais. A espécie conversa com o emblema e com os pilotos.
DIRIGENTES = {
    "eq15_gravelborn": ("Hank Ruddle", "a weathered old coyote, rally veteran turned team boss; sun-creased "
                        "face, dusty wide-brim hat pushed back, faded mustard-and-rust work jacket over a "
                        "cream shirt, arms crossed, squinting like he's watching a dirt stage"),
    "eq18_copperhead_racing": ("Silas Varn", "a lean stoat with a sly, patient stare; slicked-back fur, "
                               "copper-brown leather coat with a dark green collar, cream shirt, fingers "
                               "steepled, the stillness of a snake waiting to strike"),
    "eq06_redline_union": ("Gus Moreau", "a stocky old bulldog, union shop-floor boss; rolled sleeves on "
                           "brick-red overalls with cream panels, grease on the forearms, a tired but "
                           "defiant jaw"),
    "eq13_tempest_garage": ("Walt Brennigan", "a broad, calm beaver, foreman of a working-class garage; "
                            "navy-blue work shirt with grey panels and cream stitching, a wrench held loosely "
                            "on the shoulder, honest steady eyes"),
    "eq04_ironclad_racing": ("Moss Kettering", "a gaunt vulture with a hunched, watchful posture; gunmetal "
                             "grey armoured-looking jacket with rust-orange trims and tan details, bare "
                             "scarred neck, calculating eyes"),
    "eq08_black_circuit": ("Lou Tasker", "an old rat in a rumpled crimson suit with sand-coloured lapels, "
                           "loosened black tie, gold tooth in a crooked grin; runs the dirtiest pit box in "
                           "the series"),
    "eq07_northstar_works": ("Astrid Halvorsen", "a composed great grey owl, strategist of a night-racing "
                             "team; deep navy long coat with teal lining and a small mustard accent, a "
                             "stopwatch on a chain, measuring gaze"),
    "eq02_vortex_motorsport": ("Victor Sloane", "a powerful orca in a dark teal tailored jacket with silver-"
                               "grey trims, open collar, calm and cold; a shark-sharp businessman of racing"),
    "eq20_storm_division": ("Delphine Arceneaux", "an elegant dark bay mare with a braided mane; muted "
                            "violet velvet blazer with deep maroon lapels and thin gold piping, gloves in "
                            "hand, the quiet before a storm"),
    "eq14_crown_vector": ("Augustin Pryce", "an aristocratic old raven; ivory double-breasted coat with "
                          "maroon lining and antique-gold buttons, a cane topped with a plain gold knob, "
                          "pale polished look of old money, unreadable eyes"),
}

# Pilotos das equipes do Grid sem retrato: quem é (o perfil e a frase de
# data/equipes.json) em termos visuais, no macacão das cores da equipe.
PILOTOS = {
    "dario_kest": "a muscular pit-bull-type dog, calm even under pressure, steady heavy-lidded eyes",
    "lena_brook": "a brown hare, careful and precise, ears back, focused saving-it-for-the-last-lap look",
    "marek_stone": "a wild boar with chipped tusks, a smile that looks like a threat",
    "ivy_corran": "a raccoon with a sharp, cautious gaze, wheel-to-wheel fighter, a scratch on the muzzle",
    "liv_arnesen": "a young puma, unpredictable, restless half-smile, one ear notched",
}

TAM_DIRIGENTE = (720, 1080)   # 2:3 (pedido 1024x1536); fica recortado do fundo na ficha
TAM_PILOTO = (240, 280)       # o formato de arte/pilotos (6:7; pedido 1024x1024)


def ler(nome):
    return json.loads((RAIZ / "data" / nome).read_text(encoding="utf-8"))


def caminho(res):
    return RAIZ / res.replace("res://", "")


def equipes_grid():
    l = [e for e in ler("equipes.json") if e.get("grid") is not None]
    return sorted(l, key=lambda e: -int(e["grid"]))


def cores(e):
    c = e.get("cores", {})
    return f"main {c.get('carro', '')}, stripe {c.get('faixa', '')}, pinstripe {c.get('filete', '')}"


def pedidos():
    itens = []
    for e in equipes_grid():
        nome, quem = DIRIGENTES[e["id"]]
        itens.append({
            "tipo": "dirigente", "equipe": e["id"], "grid": e["grid"], "nome": nome,
            "arquivo_pedido": f"dirigente_{e['id']}.png",
            "destino": f"arte/equipes/dirigentes/{e['id']}.png",
            "largura_px": TAM_DIRIGENTE[0], "altura_px": TAM_DIRIGENTE[1],
            "referencias": [f"referencias/estilo_pilotos.png", f"referencias/{e['id']}/"],
            "prompt": (f"Team boss portrait for the rival team \"{e['nome']}\" (#{e['grid']} of The Grid) in a "
                       f"mobile racing game. Character: {quem}. Team colours to use on the clothing: {cores(e)}. "
                       f"Team temperament: {e.get('personalidade', '')} "
                       f"Framing: waist-up, three-quarter view, standing slightly turned, whole head and "
                       f"ears inside the frame with margin above, body cut cleanly at the waist; he/she will "
                       f"be layered in front of two drivers, so a strong readable silhouette. "
                       f"{ESTILO}{FUNDO_DIRIGENTE}{SEM_TEXTO}Size 1024x1536 (portrait)."),
        })
        for p in e["pilotos"]:
            if p["id"] in PILOTOS and not caminho(p.get("retrato", "")).exists():
                itens.append({
                    "tipo": "piloto", "equipe": e["id"], "grid": e["grid"], "nome": p["nome"],
                    "arquivo_pedido": f"piloto_{p['id']}.png",
                    "destino": p["retrato"].replace("res://", ""),
                    "largura_px": TAM_PILOTO[0], "altura_px": TAM_PILOTO[1],
                    "referencias": [f"referencias/estilo_pilotos.png", f"referencias/{e['id']}/"],
                    "prompt": (f"Racing driver portrait for the rival team \"{e['nome']}\" in a mobile racing game, "
                               f"matching the attached driver portraits exactly in style and framing. Character: "
                               f"{p['nome']}, {PILOTOS[p['id']]}. Personality: {p.get('personalidade', '')} "
                               f"Wearing a padded racing suit with harness straps in the team colours ({cores(e)}). "
                               f"Framing: head and shoulders, facing the viewer, head centred in the upper half, "
                               f"shoulders reaching the side edges, leave about 8% margin on the left and right "
                               f"so it can be cropped to 6:7. {ESTILO}{FUNDO_PILOTO}{SEM_TEXTO}Size 1024x1024."),
                })
    return itens


def png(img):
    b = io.BytesIO()
    img.save(b, "PNG")
    return b.getvalue()


def folha_estilo():
    """Os retratos de piloto já entregues, lado a lado: a referência de estilo."""
    fs = sorted(p for p in (RAIZ / "arte/pilotos").glob("*.png"))
    fs = [f for f in fs if Image.open(f).size == TAM_PILOTO]
    animais = [f for f in fs if f.stem in ("rafe_calder", "nika_stroud", "bram_holt", "soren_pike", "lucien_vale",
                                            "nadia_voss", "rex_arden", "mira_danvers", "elias_wren", "celeste_armand",
                                            "noel_mercer", "zara_keene", "cleo_vane", "ash_corwin", "erik_halden")]
    col = 5
    o = Image.new("RGB", (col * TAM_PILOTO[0], ((len(animais) + col - 1) // col) * TAM_PILOTO[1]), (16, 14, 12))
    for i, f in enumerate(animais):
        o.paste(Image.open(f).convert("RGB"), ((i % col) * TAM_PILOTO[0], (i // col) * TAM_PILOTO[1]))
    return o


LEIA_ME = """# The Grid: pedido de imagens (ChatGPT)

São {n} imagens: {n_dir} dirigentes (um por equipe do Grid) e {n_pil} retratos de piloto que faltam.

## Como pedir
1. Abra uma conversa nova no ChatGPT (geração de imagem).
2. Anexe `referencias/estilo_pilotos.png` e as imagens da pasta da equipe
   (`referencias/<equipe>/`: o emblema e os pilotos que já existem).
3. Cole o prompt da imagem (PROMPTS.md). Um pedido por imagem.
4. Salve o resultado com o **nome indicado** (`dirigente_<equipe>.png` ou `piloto_<id>.png`)
   numa pasta só.
5. Mande a pasta (ou um zip) de volta. O importador recorta/escala sem distorcer e põe cada
   arquivo no lugar; a ficha do Grid passa a usar sozinha.

## Regras para conferir antes de aceitar
- Mesmo estilo dos pilotos de referência (animal antropomórfico, pintura semi-realista).
- **Nenhum texto, letra, número ou logo** na roupa ou no fundo (a identidade vem das cores).
- Dirigente: da cintura para cima, cabeça e orelhas inteiras com folga, **fundo transparente**
  (ou magenta chapado #FF00FF, sem degradê).
- Piloto: cabeça e ombros, de frente, fundo marrom escuro como os de referência, com folga nas
  laterais (o jogo recorta para 6:7).
- Se sair errado (texto na roupa, corte na cabeça, estilo cartoon), peça de novo citando o problema.

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
        lista = "\n".join(f"- #{i['grid']} · `{i['arquivo_pedido']}` · {i['tipo']} · {i['nome']}" for i in itens)
        z.writestr("LEIA-ME.md", LEIA_ME.format(n=len(itens), n_dir=sum(i["tipo"] == "dirigente" for i in itens),
                                                n_pil=sum(i["tipo"] == "piloto" for i in itens), lista=lista))
        md = ["# Prompts (one image per request)", ""]
        for i in itens:
            md += [f"## #{i['grid']} · {i['arquivo_pedido']} ({i['tipo']}: {i['nome']})", "",
                   f"Attach: {', '.join(i['referencias'])}", "", "```", i["prompt"], "```", ""]
        z.writestr("PROMPTS.md", "\n".join(md))
        z.writestr("pedidos.json", json.dumps(itens, ensure_ascii=False, indent=1))
        z.writestr("referencias/estilo_pilotos.png", png(folha_estilo()))
        for e in equipes_grid():
            logo = caminho(e.get("logo", ""))
            if logo.exists():
                z.writestr(f"referencias/{e['id']}/emblema.png", png(Image.open(logo).convert("RGBA")))
            for p in e["pilotos"]:
                r = caminho(p.get("retrato", "")) if p.get("retrato") else None
                if r is not None and r.exists():
                    z.writestr(f"referencias/{e['id']}/piloto_{p['id']}.png", r.read_bytes())
    print(f"{saida} ({len(itens)} pedidos)")


if __name__ == "__main__":
    main()
