#!/usr/bin/env python3
"""Gera o pacote de pedidos da arte dos carros para o agente de imagem.

Lê arte/carros/manifesto.json e escreve build/pedido_arte_carros.zip com:
  LEIA-ME.txt             instruções em português (para quem opera o agente)
  INSTRUCOES_AGENTE.txt   mensagem inicial para o agente, em inglês
  PEDIDOS.md              dois pedidos por carro (isométrico e de cima), em inglês
  pedidos.json            os mesmos pedidos, para uso em lote
  manifesto.json          a lista oficial (id, descrição, cor)
  referencia_estilo.webp  docs/referencias/carro_estilo.webp
  provisorios/*.png       os sprites provisórios: ângulo, orientação e proporção
Uso: python3 tools/pacote_arte_carros.py [--saida=caminho.zip] [--so=id1,id2] [--so-faltando]
                                         [--provisorios=/pasta] [--lote=N]
  --so: só esses carros (pedido de refação).
  --so-faltando: só os carros sem arte em arte/carros/ (pedido novo, não refação).
  --provisorios: pasta dos provisórios dos carros sem arte (gerar_sprites.gd --destino).
  --lote: divide em pacotes de N carros (nome_01.zip, nome_02.zip...), na ordem do manifesto.
"""
import json
import sys
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
MANIFESTO = RAIZ / "arte/carros/manifesto.json"
REFERENCIA = RAIZ / "docs/referencias/carro_estilo.webp"
PROVISORIOS = RAIZ / "arte/carros"

ESTILO = (
    "Style: exactly the render style of the attached reference image: a low-poly faceted 3D "
    "look with flat-shaded planar facets and crisp edges, a subtle painted grain on the "
    "bodywork, muted realistic colours, dark tinted windows with a hint of the interior, black "
    "tyres, simple multi-spoke wheels, amber indicators. Soft studio light from the top-left, "
    "no harsh reflections. The reference shows the STYLE only: do not copy its shape or its "
    "body kit (rear wing, over-fenders); this car has its own design as described, in stock "
    "factory condition unless the description says otherwise. Original design that evokes the "
    "era and type but is not a copy of any real car model. No text, logos, badges, emblems, "
    "stripes with lettering or licence-plate characters (plates, if any, are blank)."
)

FUNDO = (
    "Fully TRANSPARENT background (PNG with alpha); if transparency is impossible, a flat pure "
    "magenta #FF00FF background with no gradient. No ground, no shadow under the car, no "
    "reflection, no scenery. The whole car fits inside the canvas with a small margin."
)

VISTA = {
    "iso": (
        "View: three-quarter front view from above, like the reference image and the "
        "placeholder: camera about 30 degrees above the ground, the car pointing toward the "
        "BOTTOM-LEFT of the image, so we see the front, the bonnet, the roof and the car's left "
        "side. Near-orthographic, almost no perspective distortion. Canvas: landscape."
    ),
    "topo": (
        "View: the SAME car seen from directly above (orthographic top-down, 90 degrees), front "
        "of the car pointing to the TOP of the image, car axis perfectly vertical, centred. "
        "Roof, bonnet, windscreen, mirrors and wheel arches visible from above. Same design, "
        "colour and details as the three-quarter image of this car. Canvas: portrait."
    ),
}

TELA = {"iso": "1536x1024", "topo": "1024x1536"}


def pedido(item, vista):
    return {
        "arquivo": "%s_%s.png" % (item["id"], vista),
        "tela": TELA[vista],
        "prompt": "Subject: %s. Factory paint colour: %s.\n%s\n%s\n%s" % (
            item["descricao"], item["cor"], VISTA[vista], FUNDO, ESTILO),
    }


INSTRUCOES_AGENTE = """You are producing the car art for "Second Drive", a mobile racing game seen from above.
Each car model needs exactly two images:
  <id>_iso.png   three-quarter front view from above (garage, showroom and close-up race moments)
  <id>_topo.png  straight top-down view, front pointing up (the game rotates it on the track)

Attached: referencia_estilo.webp (the target render style), manifesto.json (the official list of
cars with a description and a factory colour), provisorios/ (crude placeholders showing the exact
camera angle, orientation and proportions of each image), PEDIDOS.md (one prompt per image).

Rules for every image:
- File name exactly as listed (e.g. hayase_kobo_iso.png). PNG.
- Transparent background (or flat magenta #FF00FF if transparency is impossible). No ground,
  no shadow, no reflection: the game draws the shadow.
- Same render style as the reference for every car: faceted low-poly, flat shading, subtle
  painted grain, muted colours, soft light from the top-left.
- The reference is style only: each car has its own shape from its description.
- Original designs: nothing that copies a real car model; no text, logos, badges or plate numbers.
- Make the iso image first, then the top-down image of the same car, keeping shape, colour and
  details identical between the two.
- Keep the camera angle and orientation of the placeholders (iso: car pointing to the bottom-left;
  top-down: front at the top).
- Keep scale consistent across the set: a small city car must look small next to a GT coupe
  (the game rescales each image to the real size of the car, but proportions must be right:
  length, width and height of each body type).

Deliver all files in one folder or zip, named as in the list. Exact pixel size is not required.
"""

LEIA_ME = """PEDIDO DA ARTE DOS CARROS — Second Drive

Cada carro tem duas imagens: isométrica (garagem, vitrine, momento de velocidade) e de cima
(corrida; o jogo gira o desenho). Estilo: a imagem referencia_estilo.webp.

Como usar com o agente do ChatGPT:
1. Envie ao agente: INSTRUCOES_AGENTE.txt (como primeira mensagem), referencia_estilo.webp,
   manifesto.json e a pasta provisorios/.
2. Peça os arquivos na ordem de PEDIDOS.md: para cada carro, primeiro o isométrico, depois o de
   cima do mesmo carro. Cada pedido traz o nome do arquivo, o tamanho de tela e o prompt.
   pedidos.json tem o mesmo conteúdo para uso em lote.
3. Junte os PNG numa pasta com os nomes exatos e me mande (zip). O importador do jogo recorta,
   coloca na escala real de cada carro (160 px por metro) e remove fundo magenta; o que vier sem
   fundo transparente volta para refazer.

O que observar antes de mandar:
- Ângulo igual ao dos provisórios: isométrico com o carro apontando para baixo e à esquerda;
  de cima com a frente para o alto, carro reto na vertical.
- Mesmo carro nas duas imagens (forma, cor, detalhes).
- Sem sombra, sem chão, sem texto, logotipo, emblema ou placa escrita.
- Nenhum carro parecido demais com um modelo real.
- Mesmo estilo em todos os carros.

Total: {n} carros, {i} imagens.
"""

REFACAO = """REFAÇÃO: este pacote pede só os carros abaixo, para substituir as imagens atuais
(pasta provisorios/ mostra a versão atual). Mesmas regras e mesmo estilo dos já aprovados.

"""


def main():
    saida = RAIZ / "build/pedido_arte_carros.zip"
    so = set()
    so_faltando = False
    lote = 0
    extra = None
    for a in sys.argv[1:]:
        if a.startswith("--saida="):
            saida = Path(a.split("=", 1)[1]).resolve()
        elif a.startswith("--so="):
            so = set(a.split("=", 1)[1].split(","))
        elif a == "--so-faltando":
            so_faltando = True
        elif a.startswith("--provisorios="):
            extra = Path(a.split("=", 1)[1]).resolve()
        elif a.startswith("--lote="):
            lote = int(a.split("=", 1)[1])
    itens = json.loads(MANIFESTO.read_text(encoding="utf-8"))
    if so_faltando:
        itens = [i for i in itens if not (PROVISORIOS / ("%s_iso.png" % i["id"])).exists()]
    if lote > 0:
        for k in range(0, len(itens), lote):
            parte = itens[k:k + lote]
            gravar(parte, saida.with_name("%s_%02d.zip" % (saida.stem, k // lote + 1)), False, extra,
                   "Lote %d de %d.\n\n" % (k // lote + 1, (len(itens) + lote - 1) // lote))
        return
    gravar(itens, saida, bool(so), extra, "", so)


def gravar(itens, saida, refacao, extra, cabecalho, so=None):
    if so:
        faltam = so - {i["id"] for i in itens}
        if faltam:
            sys.exit("fora do manifesto: %s" % ", ".join(sorted(faltam)))
        itens = [i for i in itens if i["id"] in so]
    pedidos = [pedido(i, v) for i in itens for v in ("iso", "topo")]
    md = ["# Pedidos — arte dos carros (Second Drive)", "",
          "For each car: the three-quarter image first, then the top-down image of the same car.", ""]
    for k, p in enumerate(pedidos, 1):
        md += ["## %d. %s" % (k, p["arquivo"]), "", "Canvas: %s" % p["tela"], "", "```", p["prompt"], "```", ""]
    publico = [{"id": i["id"], "descricao": i["descricao"], "cor": i["cor"]} for i in itens]
    saida.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(saida, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("LEIA-ME.txt", cabecalho + (REFACAO if refacao else "") + LEIA_ME.format(n=len(itens), i=len(pedidos)))
        z.writestr("INSTRUCOES_AGENTE.txt", INSTRUCOES_AGENTE)
        z.writestr("PEDIDOS.md", "\n".join(md))
        z.writestr("pedidos.json", json.dumps(pedidos, indent=1, ensure_ascii=False))
        z.writestr("manifesto.json", json.dumps(publico, indent=1, ensure_ascii=False))
        z.write(REFERENCIA, "referencia_estilo.webp")
        for p in pedidos:
            png = PROVISORIOS / p["arquivo"]
            if not png.exists() and extra is not None:
                png = extra / p["arquivo"]
            if png.exists():
                z.write(png, "provisorios/" + png.name)
    print("%s: %d carros, %d pedidos" % (saida, len(itens), len(pedidos)))


if __name__ == "__main__":
    main()
