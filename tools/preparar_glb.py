#!/usr/bin/env python3
"""Confere e instala os modelos 3D dos carros (docs/carros_3d.md) em arte/carros3d/.

Para cada <id>.glb recebido (id de data/carros.json; um sufixo _textured é ignorado):
- confere o padrão: frente em +Z, chão em y = 0, escala em metros (comprimento e
  largura perto das medidas de docs/carros_3d/lista.csv), quatro rodas roda_*,
  orçamento de triângulos;
- tira a textura de dentro do GLB, reduz para no máximo 512 px (sem mudar a
  proporção) e grava ao lado como <id>_atlas.png; o GLB passa a apontar para ela.

O modelo nunca é escalado nem esticado: medida fora da tolerância é erro, para
corrigir na modelagem.

Dois formatos de pintura: (1) atlas de cores com a lataria branca (a textura
sai do GLB para <id>_atlas.png); (2) material "Paint" com textura branca mínima
e as outras partes em materiais de cor (o GLB vai como veio; o jogo pinta só
esse material).

Uso:
  python3 tools/preparar_glb.py PASTA_OU_ARQUIVOS... [--manter=id1,id2]   instala em arte/carros3d/
                                                       (--manter: não substitui esses)
  python3 tools/preparar_glb.py --checar               confere os já instalados
"""
from __future__ import annotations

import csv
import io
import json
import pathlib
import struct
import sys

for _fluxo in (sys.stdout, sys.stderr):
    if hasattr(_fluxo, "reconfigure"):
        _fluxo.reconfigure(encoding="utf-8", errors="replace")

RAIZ = pathlib.Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "arte/carros3d"
LISTA = RAIZ / "docs/carros_3d/lista.csv"
ATLAS_MAX = 512
TOLERANCIA = 0.10  # comprimento e largura: ±10% das medidas da lista
RETROVISORES = 0.30  # a largura da lista é a da carroceria; retrovisores somam até +30%
TRIANGULOS_MAX = 3000
RODAS = {"roda_de", "roda_dd", "roda_te", "roda_td"}


def ler_glb(dados: bytes) -> tuple[dict, bytes]:
    magia, _versao, _total = struct.unpack_from("<III", dados, 0)
    if magia != 0x46546C67:
        raise ValueError("não é um GLB")
    pos = 12
    js, binario = None, b""
    while pos < len(dados):
        tam, tipo = struct.unpack_from("<II", dados, pos)
        corpo = dados[pos + 8:pos + 8 + tam]
        if tipo == 0x4E4F534A:
            js = json.loads(corpo.decode("utf-8"))
        elif tipo == 0x004E4942:
            binario = bytes(corpo)
        pos += 8 + tam
    if js is None:
        raise ValueError("GLB sem JSON")
    return js, binario


def escrever_glb(js: dict, binario: bytes) -> bytes:
    texto = json.dumps(js, separators=(",", ":")).encode("utf-8")
    texto += b" " * (-len(texto) % 4)
    binario += b"\0" * (-len(binario) % 4)
    partes = [struct.pack("<II", len(texto), 0x4E4F534A), texto]
    if binario:
        partes += [struct.pack("<II", len(binario), 0x004E4942), binario]
    corpo = b"".join(partes)
    return struct.pack("<III", 0x46546C67, 2, 12 + len(corpo)) + corpo


def vista(js: dict, binario: bytes, k: int) -> bytes:
    bv = js["bufferViews"][k]
    ini = bv.get("byteOffset", 0)
    return binario[ini:ini + bv["byteLength"]]


def sem_imagens_embutidas(js: dict, binario: bytes, uri: str) -> bytes:
    """Aponta as imagens para `uri` e tira os bytes delas do buffer (reindexa as vistas)."""
    tirar = {img["bufferView"] for img in js.get("images", []) if "bufferView" in img}
    for img in js.get("images", []):
        img.pop("bufferView", None)
        img.pop("mimeType", None)
        img["uri"] = uri
    if not tirar:
        return binario
    novo = bytearray()
    mapa = {}
    vistas = []
    for k, bv in enumerate(js["bufferViews"]):
        if k in tirar:
            continue
        novo += b"\0" * (-len(novo) % 4)
        pedaco = vista(js, binario, k)
        bv = dict(bv, byteOffset=len(novo))
        novo += pedaco
        mapa[k] = len(vistas)
        vistas.append(bv)
    js["bufferViews"] = vistas
    for a in js.get("accessors", []):
        if "bufferView" in a:
            a["bufferView"] = mapa[a["bufferView"]]
        for parte in ("indices", "values"):
            if parte in a.get("sparse", {}):
                a["sparse"][parte]["bufferView"] = mapa[a["sparse"][parte]["bufferView"]]
    js["buffers"] = [{"byteLength": len(novo)}]
    return bytes(novo)


def posicoes(js: dict, binario: bytes) -> list[tuple[float, float, float]]:
    """Vértices de todas as malhas em coordenadas do modelo (com a transformação dos nós)."""
    pts = []

    def mult(m, p):
        return (m[0] * p[0] + m[4] * p[1] + m[8] * p[2] + m[12],
                m[1] * p[0] + m[5] * p[1] + m[9] * p[2] + m[13],
                m[2] * p[0] + m[6] * p[1] + m[10] * p[2] + m[14])

    def matriz(no):
        if "matrix" in no:
            return no["matrix"]
        t = no.get("translation", [0, 0, 0])
        s = no.get("scale", [1, 1, 1])
        x, y, z, w = no.get("rotation", [0, 0, 0, 1])
        r = [1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w), 0,
             2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w), 0,
             2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y), 0, 0, 0, 0, 1]
        for c in range(3):
            for l in range(3):
                r[c * 4 + l] *= s[c]
        r[12:15] = t
        return r

    def compor(a, b):
        return [sum(a[k * 4 + l] * b[c * 4 + k] for k in range(4)) for c in range(4) for l in range(4)]

    def visitar(k, pai):
        no = js["nodes"][k]
        m = compor(pai, matriz(no))
        if "mesh" in no:
            for prim in js["meshes"][no["mesh"]]["primitives"]:
                a = js["accessors"][prim["attributes"]["POSITION"]]
                bruto = vista(js, binario, a["bufferView"])
                passo = js["bufferViews"][a["bufferView"]].get("byteStride", 12)
                ini = a.get("byteOffset", 0)
                for i in range(a["count"]):
                    pts.append(mult(m, struct.unpack_from("<3f", bruto, ini + i * passo)))
        for f in no.get("children", []):
            visitar(f, m)

    ident = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
    cena = js.get("scenes", [{"nodes": list(range(len(js["nodes"])))}])[js.get("scene", 0)]
    for k in cena["nodes"]:
        visitar(k, ident)
    return pts


def triangulos(js: dict) -> int:
    n = 0
    for m in js.get("meshes", []):
        for p in m["primitives"]:
            a = js["accessors"][p["indices"]] if "indices" in p else js["accessors"][p["attributes"]["POSITION"]]
            n += a["count"] // 3
    return n


def medidas() -> dict:
    if not LISTA.exists():
        return {}
    with open(LISTA, newline="", encoding="utf-8") as f:
        return {r["arquivo"][:-4]: r for r in csv.DictReader(f)}


def conferir(id_: str, js: dict, binario: bytes, ref: dict) -> tuple[list[str], list[str]]:
    erros, avisos = [], []
    pts = posicoes(js, binario)
    if not pts:
        return ["sem malha"], []
    xs, ys, zs = zip(*pts)
    comp, larg, alt = max(zs) - min(zs), max(xs) - min(xs), max(ys) - min(ys)
    if abs(min(ys)) > 0.03:
        erros.append(f"chão fora de y = 0 (menor y = {min(ys):.3f} m)")
    if larg > comp:
        erros.append(f"mais largo que comprido ({larg:.2f} × {comp:.2f} m): a frente deve apontar para +Z")
    if ref:
        for nome, valor, alvo, acima in (("comprimento", comp, float(ref["comprimento_m"]), TOLERANCIA),
                                         ("largura", larg, float(ref["largura_m"]), RETROVISORES)):
            if not alvo * (1 - TOLERANCIA) <= valor <= alvo * (1 + acima):
                erros.append(f"{nome} {valor:.2f} m, lista pede {alvo:.2f} m (-{TOLERANCIA:.0%}/+{acima:.0%}): "
                             "escala em metros?")
    elif id_:
        erros.append("id fora de data/carros.json")
    # Frente em +Z: a metade da frente é mais baixa (capô) que a de trás (cabine, aerofólio).
    alto = 0.75 * max(ys)
    altos = [z for (_x, y, z) in pts if y > alto]
    if altos and sum(altos) / len(altos) > 0.15 * comp:
        avisos.append("o alto do carro está na metade +Z: conferir se a frente aponta para +Z")
    nomes = {str(n.get("name", "")).lower() for n in js.get("nodes", [])}
    faltam = RODAS - nomes
    if faltam:
        avisos.append(f"rodas separadas faltando ({', '.join(sorted(faltam))}): no jogo elas não giram")
    tri = triangulos(js)
    if tri > TRIANGULOS_MAX:
        avisos.append(f"{tri} triângulos (orçamento {TRIANGULOS_MAX})")
    return erros, avisos


def pintura_por_material(js: dict) -> bool:
    """Formato com a lataria num material "Paint" (textura branca mínima) e as
    outras partes em materiais de cor: o jogo pinta só esse material."""
    return any(str(m.get("name", "")).lower() == "paint" for m in js.get("materials", []))


def instalar(arquivo: pathlib.Path, ref_todas: dict) -> bool:
    from PIL import Image  # só para instalar

    id_ = arquivo.stem.removesuffix("_textured")
    js, binario = ler_glb(arquivo.read_bytes())
    erros, avisos = conferir(id_, js, binario, ref_todas.get(id_, {}))
    if not erros and pintura_por_material(js):
        # Sem atlas: o GLB vai como veio (a textura branca embutida é mínima).
        for a in avisos:
            print(f"  aviso {id_}: {a}")
        DESTINO.mkdir(parents=True, exist_ok=True)
        saida = DESTINO / f"{id_}.glb"
        saida.write_bytes(arquivo.read_bytes())
        for velho in DESTINO.glob(f"{id_}_*.png*"):
            velho.unlink()
        print(f"ok {id_}: {saida.stat().st_size // 1024} KB (pintura pelo material Paint)")
        return True
    imagens = js.get("images", [])
    atlas = None
    if imagens:
        img = imagens[0]
        if "bufferView" in img:
            atlas = Image.open(io.BytesIO(vista(js, binario, img["bufferView"])))
        elif "uri" in img and (arquivo.parent / img["uri"]).exists():
            atlas = Image.open(arquivo.parent / img["uri"])
    if atlas is None:
        erros.append("sem textura (atlas) no GLB nem ao lado dele")
    for a in avisos:
        print(f"  aviso {id_}: {a}")
    if erros:
        for e in erros:
            print(f"  ERRO {id_}: {e}")
        return False
    lado = max(atlas.size)
    if lado > ATLAS_MAX:
        f = ATLAS_MAX / lado  # escala uniforme: a proporção não muda
        atlas = atlas.resize((round(atlas.width * f), round(atlas.height * f)), Image.NEAREST)  # cores chapadas: sem misturar ilhas
    DESTINO.mkdir(parents=True, exist_ok=True)
    nome_atlas = f"{id_}_atlas.png"
    atlas.convert("RGB").save(DESTINO / nome_atlas, optimize=True)
    binario = sem_imagens_embutidas(js, binario, nome_atlas)
    saida = DESTINO / f"{id_}.glb"
    saida.write_bytes(escrever_glb(js, binario))
    # Texturas que o Godot extraiu de uma versão anterior com imagem embutida.
    for velho in DESTINO.glob(f"{id_}_*.png*"):
        if not velho.name.startswith(nome_atlas):
            velho.unlink()
    print(f"ok {id_}: {saida.stat().st_size // 1024} KB + atlas {atlas.width}×{atlas.height} "
          f"({(DESTINO / nome_atlas).stat().st_size // 1024} KB)")
    return True


def checar(ref_todas: dict) -> int:
    falhas = 0
    for arq in sorted(DESTINO.glob("*.glb")):
        js, binario = ler_glb(arq.read_bytes())
        erros, _ = conferir(arq.stem, js, binario, ref_todas.get(arq.stem, {}))
        imgs = js.get("images", [])
        if any("bufferView" in i for i in imgs) and not pintura_por_material(js):
            erros.append("textura embutida: passar pelo tools/preparar_glb.py")
        for i in imgs:
            uri = i.get("uri", "")
            if uri and not (DESTINO / uri).exists():
                erros.append(f"atlas {uri} não existe")
        for e in erros:
            print(f"ERRO {arq.name}: {e}")
        falhas += bool(erros)
    print(f"carros 3D: {len(list(DESTINO.glob('*.glb')))} modelos, {falhas} com erro")
    return 1 if falhas else 0


def main(args: list[str]) -> int:
    ref = medidas()
    if args == ["--checar"]:
        return checar(ref)
    if not args:
        print(__doc__)
        return 1
    manter = set()
    for a in [x for x in args if x.startswith("--manter=")]:
        manter |= set(a.split("=", 1)[1].split(","))
    args = [x for x in args if not x.startswith("--")]
    arquivos = []
    for a in map(pathlib.Path, args):
        arquivos += sorted(a.glob("*.glb")) if a.is_dir() else [a]
    arquivos = [a for a in arquivos if a.stem.removesuffix("_textured") not in manter]
    ok = sum(instalar(a, ref) for a in arquivos)
    print(f"{ok}/{len(arquivos)} instalados")
    return 0 if ok == len(arquivos) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
