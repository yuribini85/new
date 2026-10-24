#!/usr/bin/env python3
"""Gera o pedido das ilustrações 2D dos cartões de carro (decisão 127, D2).

Uma ilustração por carro para os cartões (lojas, garagem, coleção, fichas), começando
pelos carros das licenças Club e Sport (os que o jogador vê nas primeiras horas). Lê
docs/carros_3d/lista.csv (descrição em inglês, medidas, época) e escreve
build/pedido_arte_cartoes[_NN].zip com:
  LEIA-ME.txt             instruções em português (para quem opera o agente de imagem)
  INSTRUCOES_AGENTE.txt   mensagem inicial para o agente, em inglês
  PEDIDOS.md              um pedido por carro, em inglês
  pedidos.json            os mesmos pedidos, para uso em lote
  referencia_estilo.png   arte/ui/mapa_lojas.png (o estilo ilustrado do jogo)
  silhuetas/<id>.png      a foto atual do modelo 3D (forma e proporção; não é o estilo)
Uso: python3 tools/pacote_arte_cartoes.py [--amostra] [--lote=60] [--licencas=Club,Sport] [--so=id1,id2]
  --amostra: só 3 carros (um compacto, um sedã, um cupê) para aprovar o estilo antes do lote.
  --lote: carros por pacote (padrão 60), na ordem: licença, depois preço.
As silhuetas vêm de build/ref_cartoes/ (tools/fotos_cartao.gd); o script diz quais faltam.
"""
import csv
import json
import sys
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
LISTA = RAIZ / "docs/carros_3d/lista.csv"
REFERENCIA = RAIZ / "arte/ui/mapa_lojas.png"
SILHUETAS = RAIZ / "build/ref_cartoes"
ORDEM_LICENCA = ["Club", "Sport", "National", "International", "Pro", "Elite", "só loja"]

ESTILO = (
    "Style: a hand-painted 2D illustration in the style of the attached reference image (a "
    "retro coastal-road map with showrooms): clean confident outlines, cel shading with two or "
    "three tones per surface, soft painted texture, warm late-afternoon light from the top-left, "
    "a slightly stylised but believable car (proportions true to the silhouette reference, "
    "never cartoonish or chibi). The silhouette image shows the SHAPE and proportions only, not "
    "the style. Original design that evokes the era and type but is not a copy of any real car "
    "model. No text, logos, badges, emblems or licence-plate characters (plates, if any, blank)."
)

# Pintura por programação (docs/arte_carros.md, visual/pintura.gd): carroceria branca,
# recolorida pelo jogo na cor de fábrica ou na pintura do jogador.
PINTURA = (
    "PAINT: ALL the painted bodywork in ONE flat pure white with light grey shading tones; the "
    "game recolours it. Nothing else on the car may be white or light grey: windows dark tinted "
    "glass, interior dark grey, tyres black, wheels medium silver grey, unpainted trim and "
    "grilles black, headlight lenses pale grey (not white), indicators amber, tail lights red, "
    "number plate blank mid grey. No stripes, decals or two-tone paint."
)

VISTA = (
    "View: three-quarter front view, the car pointing toward the bottom-LEFT, camera slightly "
    "above (about 15 degrees), like the silhouette reference. The whole car fits the canvas "
    "with a small even margin; the car fills about 85% of the width."
)

FUNDO = (
    "Fully TRANSPARENT background (PNG with alpha); if transparency is impossible, a flat pure "
    "magenta #FF00FF background with no gradient. No ground, no shadow, no scenery."
)

TELA = "1536x1024"

INSTRUCOES_AGENTE = """You are producing the card illustrations for "Chrome & Wreckage", a mobile racing
management game. Each car needs ONE image, shown on its card in the shops and the garage.

Attached: referencia_estilo.png (the target illustration style of the game), silhuetas/ (the
current 3D model of each car: shape and proportions to follow, NOT the style), PEDIDOS.md (one
prompt per car) and pedidos.json (the same, for batch use).

Rules for every image:
- File name exactly as listed: <id>_cartao.png. PNG, landscape canvas (about 1536x1024).
- Transparent background (or flat magenta #FF00FF). No ground, no shadow, no scenery.
- The same illustration style for every car (the style of the reference image).
- Shape and proportions of each car from its silhouette image and description: a small city car
  must look small and boxy, a sports coupe long and low.
- Paint every car WHITE (the game recolours the bodywork); only the bodywork may be white or
  light grey.
- Same camera for every car: three-quarter front, pointing to the bottom-left, slightly from above.
- Original designs: nothing that copies a real car; no text, logos, badges or plate numbers.

Deliver all files in one folder or zip, named as listed.
"""

LEIA_ME = """PEDIDO: ILUSTRAÇÕES DOS CARTÕES DE CARRO — Chrome & Wreckage

Uma ilustração por carro, para os cartões das lojas, da garagem e da coleção (decisão 127:
os testadores acharam os carros genéricos). A pintura é do jogo: o carro vem branco e o jogo
pinta na cor de fábrica ou na pintura do jogador.

{cabecalho}Como usar com o agente de imagem:
1. Envie ao agente: INSTRUCOES_AGENTE.txt (primeira mensagem), referencia_estilo.png e a pasta
   silhuetas/.
2. Peça os arquivos na ordem de PEDIDOS.md (cada pedido traz o nome do arquivo e o prompt).
3. Junte os PNG numa pasta com os nomes exatos e me mande (zip). Eu recorto, removo fundo
   magenta, meço a pintura e coloco no jogo.

O que conferir antes de mandar:
- O mesmo estilo em todos (o da referência), o mesmo ângulo (frente para baixo e à esquerda).
- A forma de cada carro igual à da silhueta (compacto pequeno, cupê longo e baixo).
- Carroceria branca; nada branco fora dela (faróis cinza-claros, placa cinza, interior escuro).
- Sem sombra, chão, texto, logotipo ou placa escrita; nenhum carro parecido demais com um real.

Total: {n} carros.
"""

AMOSTRA = """AMOSTRA: só 3 carros (um compacto, um sedã e um cupê). Mande estes primeiro: com o
estilo aprovado no jogo, sai o lote completo.

"""


def ler_lista():
    with open(LISTA, encoding="utf-8") as f:
        return list(csv.DictReader(f))


# A lista em português, traduzida para o agente (a coluna descricao_en está vazia).
DETALHES = {
    "aerofólio": "a rear spoiler", "asa grande de rali": "a large rally wing", "defletor no teto": "a roof deflector",
    "escape duplo": "twin exhausts", "faróis escamoteáveis": "pop-up headlights", "faróis finos": "slim headlights",
    "faróis redondos": "round headlights", "grade em fenda": "a slot grille", "grade redonda": "a round grille",
    "linhas retas em cunha (anos 80)": "straight wedge lines (1980s)", "lábio na tampa traseira": "a boot-lid lip",
    "rodas traseiras maiores": "larger rear wheels", "tomada de ar no capô": "a bonnet air scoop",
    "tomadas laterais": "side air intakes",
}
CARROCERIA = {"hatch compacto": "compact hatchback", "sedã": "saloon (sedan)", "cupê": "sports coupé",
              "utilitario": "boxy utility / off-road wagon", "picape": "pickup truck", "pesado": "heavy truck"}
TRACAO = {"dianteira, motor na frente": "front-engined, front-wheel drive",
          "integral": "all-wheel drive", "traseira, motor atrás": "rear-engined, rear-wheel drive",
          "traseira, motor central": "mid-engined (cabin forward, long rear deck with side intakes)",
          "traseira, motor na frente": "front-engined, rear-wheel drive"}
ESCOLA = {"br": "Brazilian", "de": "German", "eu": "European", "fr": "French", "it": "Italian", "jp": "Japanese",
          "se": "Swedish", "uk": "British", "us": "American"}


def sujeito(c):
    if c["descricao_en"].strip():
        return c["descricao_en"].strip()
    det = [DETALHES.get(d.strip(), d.strip()) for d in c["detalhes"].split(",") if d.strip()]
    return ("an original %s-era %s-school %s, %s; about %s m long, %s m wide and %s m tall, wheelbase %s m%s." % (
        c["ano"], ESCOLA.get(c["escola"], c["escola"]), CARROCERIA.get(c["carroceria"], c["carroceria"]),
        TRACAO.get(c["tracao"], c["tracao"]), c["comprimento_m"], c["largura_m"], c["altura_m"], c["entre_eixos_m"],
        "; details: " + ", ".join(det) if det else ""))


def pedido(c):
    sujeito_txt = sujeito(c)
    return {
        "id": c["arquivo"].removesuffix(".glb"),
        "arquivo": "%s_cartao.png" % c["arquivo"].removesuffix(".glb"),
        "tela": TELA,
        "prompt": "Subject: %s\n%s\n%s\n%s\n%s" % (sujeito_txt, PINTURA, VISTA, FUNDO, ESTILO),
    }


def gravar(itens, saida, cabecalho):
    pedidos = [pedido(c) for c in itens]
    md = ["# Pedidos — ilustrações dos cartões (Chrome & Wreckage)", ""]
    for k, p in enumerate(pedidos, 1):
        md += ["## %d. %s" % (k, p["arquivo"]), "", "Canvas: %s · silhouette: silhuetas/%s.png" % (p["tela"], p["id"]),
               "", "```", p["prompt"], "```", ""]
    faltam = []
    saida.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(saida, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("LEIA-ME.txt", LEIA_ME.format(cabecalho=cabecalho, n=len(itens)))
        z.writestr("INSTRUCOES_AGENTE.txt", INSTRUCOES_AGENTE)
        z.writestr("PEDIDOS.md", "\n".join(md))
        z.writestr("pedidos.json", json.dumps(pedidos, indent=1, ensure_ascii=False))
        z.write(REFERENCIA, "referencia_estilo.png")
        for p in pedidos:
            png = SILHUETAS / ("%s.png" % p["id"])
            if png.exists():
                z.write(png, "silhuetas/" + png.name)
            else:
                faltam.append(p["id"])
    print("%s: %d carros" % (saida, len(itens)))
    if faltam:
        print("sem silhueta (rode tools/fotos_cartao.gd -- %s)" % ",".join(faltam))


def main():
    saida = RAIZ / "build/pedido_arte_cartoes.zip"
    lote = 60
    licencas = ["Club", "Sport"]
    amostra = False
    so = set()
    for a in sys.argv[1:]:
        if a.startswith("--saida="):
            saida = Path(a.split("=", 1)[1]).resolve()
        elif a.startswith("--lote="):
            lote = int(a.split("=", 1)[1])
        elif a.startswith("--licencas="):
            licencas = a.split("=", 1)[1].split(",")
        elif a == "--amostra":
            amostra = True
        elif a.startswith("--so="):
            so = set(a.split("=", 1)[1].split(","))
    carros = ler_lista()
    if so:
        itens = [c for c in carros if c["arquivo"].removesuffix(".glb") in so]
    else:
        itens = [c for c in carros if c["primeira_licenca"] in licencas]
    itens.sort(key=lambda c: (ORDEM_LICENCA.index(c["primeira_licenca"]) if c["primeira_licenca"] in ORDEM_LICENCA
                              else 99, int(float(c["preco"] or 0))))
    if amostra:
        escolha = []
        for tipo in ("compacto", "sedã", "cupê"):
            for c in itens:
                if tipo in c["carroceria"].lower() and c not in escolha:
                    escolha.append(c)
                    break
        gravar(escolha, saida.with_name("pedido_arte_cartoes_amostra.zip"), AMOSTRA)
        return
    total = (len(itens) + lote - 1) // lote
    for k in range(0, len(itens), lote):
        n = k // lote + 1
        gravar(itens[k:k + lote], saida.with_name("%s_%02d.zip" % (saida.stem, n)),
               "Lote %d de %d (licenças %s, na ordem em que o jogador vê os carros).\n\n" % (n, total, ", ".join(licencas)))


if __name__ == "__main__":
    main()
