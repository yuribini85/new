#!/usr/bin/env python3
"""Exporta as formas dos carros para o gerador (visual/carroceria.gd).

Cada carro da frota 360 foi desenhado a partir de uns 60 números guardados em
referencia/frota360/pacote/<asset>/model-info.json. O gerador facetado só usa
parte deles; este script copia essa parte, para cada id de data/carros.json
(id -> asset em referencia/frota360/frota.json), para arte/carros3d/formas.json,
que vai no jogo. referencia/ nunca vai: dele só saem medidas da carroceria, sem
nome, intenção, referência ou qualquer campo que aponte para carro real.

Também confere que formas.json entra no pacote web (include_filter do
export_presets.cfg). Os GLB continuam no pacote: o gerado só substitui o GLB
nos carros de Carroceria.ATIVOS (pedido do usuário: um carro por vez).

Uso:
  python3 tools/exportar_formas.py            gera formas.json e atualiza o preset
  python3 tools/exportar_formas.py --checar   confere (sem precisar de referencia/)
"""
import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
FROTA = RAIZ / "referencia" / "frota360"
SAIDA = RAIZ / "arte" / "carros3d" / "formas.json"
PRESET = RAIZ / "export_presets.cfg"
VERSAO = 1

# Campos que o gerador usa (nada além disto sai da referência).
ESCALARES = ["W", "r", "low", "lo", "hi", "sx", "za", "zb", "wind", "back"]
LISTAS = ["axles", "rows", "roof"]
RODAS = {"Mount_FrontLeft", "Mount_FrontRight", "Mount_RearLeft", "Mount_RearRight"}


def arred(v):
    if isinstance(v, list):
        return [arred(x) for x in v]
    return round(float(v), 3)


def forma(info: dict) -> dict:
    f = {k: arred(info[k]) for k in ESCALARES}
    for k in LISTAS:
        f[k] = arred(info[k])
    f["rodas"] = [[w["name"]] + arred(w["position"]) for w in info["wheel_mounts"]]
    if info.get("doors") in (2, 4):
        f["doors"] = int(info["doors"])  # 2 portas: coluna B no fim da porta
    return f


def ids_do_jogo() -> list[str]:
    return [c["id"] for c in json.loads((RAIZ / "data" / "carros.json").read_text(encoding="utf-8"))]


def gerar() -> dict:
    frota = {l["id"]: l["asset"] for l in json.loads((FROTA / "frota.json").read_text(encoding="utf-8"))}
    carros = {}
    faltam = []
    for id_ in ids_do_jogo():
        if id_ not in frota:
            faltam.append(id_)
            continue
        info = json.loads((FROTA / "pacote" / frota[id_] / "model-info.json").read_text(encoding="utf-8"))
        carros[id_] = forma(info)
    if faltam:
        print("sem forma na frota:", ", ".join(faltam))
    return {"_nota": "Gerado por tools/exportar_formas.py (medidas da carroceria para visual/carroceria.gd). "
            "Não editar à mão.", "versao": VERSAO, "carros": carros}


def ler_preset() -> tuple[str, str]:
    texto = PRESET.read_text(encoding="utf-8")
    m = re.search(r'^exclude_filter="([^"]*)"', texto, re.M)
    return texto, m.group(1)


## A frota inteira usa o carro gerado (Carroceria/Pesados, decisão 91): o GLB
## da carroceria e a textura dele saem do pacote. A blindagem (*_protecao*)
## continua. Os curingas do Godot não separam os dois, então a lista é por id.
def exclusoes_glb(ids: list[str]) -> list[str]:
    r = []
    for id_ in sorted(ids):
        r += [f"arte/carros3d/{id_}.glb", f"arte/carros3d/{id_}_0.png"]
    return r


def com_exclusoes(exc: str, ids: list[str]) -> str:
    itens = [p.strip() for p in exc.split(",") if p.strip()]
    itens = [p for p in itens if not (p.startswith("arte/carros3d/") and "_protecao" not in p
                                      and (p.endswith(".glb") or p.endswith("_0.png")))]
    return ", ".join(itens + exclusoes_glb(ids))


def checar_preset(ids: list[str]) -> list[str]:
    texto, exc = ler_preset()
    erros = []
    inc = re.search(r'^include_filter="([^"]*)"', texto, re.M).group(1)
    if "arte/carros3d/formas.json" not in [p.strip() for p in inc.split(",")]:
        erros.append("export_presets.cfg: include_filter sem arte/carros3d/formas.json")
    if com_exclusoes(exc, ids) != exc:
        erros.append("export_presets.cfg: exclude_filter sem os GLB de carroceria de todos os carros "
                     "(rodar tools/exportar_formas.py)")
    return erros


def checar() -> int:
    erros = []
    if not SAIDA.exists():
        print("ERRO: arte/carros3d/formas.json não existe")
        return 1
    dados = json.loads(SAIDA.read_text(encoding="utf-8"))
    carros = dados.get("carros", {})
    ids = ids_do_jogo()
    for id_ in ids:
        f = carros.get(id_)
        if f is None:
            erros.append(f"{id_}: sem forma")
            continue
        for k in ESCALARES + LISTAS + ["rodas"]:
            if k not in f:
                erros.append(f"{id_}: falta {k}")
        nomes = {r[0] for r in f.get("rodas", [])}
        if not RODAS <= nomes or not all(n.startswith("Mount_") for n in nomes):
            erros.append(f"{id_}: rodas devem incluir {sorted(RODAS)} (nomes Mount_*)")
        if len(f.get("rows", [])) < 3:
            erros.append(f"{id_}: poucas seções")
        extras = set(f) - set(ESCALARES + LISTAS + ["rodas", "doors"])
        if extras:
            erros.append(f"{id_}: campos fora do gerador {sorted(extras)}")
    for id_ in set(carros) - set(ids):
        erros.append(f"{id_}: forma de carro que não está em data/carros.json")
    if FROTA.exists() and gerar() != dados:
        erros.append("formas.json desatualizado em relação à referência (rodar tools/exportar_formas.py)")
    erros += checar_preset(sorted(carros))
    for e in erros:
        print("ERRO", e)
    print(f"formas dos carros: {len(carros)} de {len(ids)}, {len(erros)} erro(s)")
    return 1 if erros else 0


def main(args: list[str]) -> int:
    if args == ["--checar"]:
        return checar()
    if args:
        print(__doc__)
        return 1
    if not FROTA.exists():
        print("referencia/frota360 não existe: sem a frota não há o que exportar")
        return 1
    dados = gerar()
    SAIDA.write_text(json.dumps(dados, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    texto, _ = ler_preset()
    inc = re.search(r'^include_filter="([^"]*)"', texto, re.M).group(1)
    if "arte/carros3d/formas.json" not in inc:
        texto = texto.replace(f'include_filter="{inc}"', f'include_filter="{inc}, arte/carros3d/formas.json"', 1)
    _, exc = ler_preset()
    texto = texto.replace(f'exclude_filter="{exc}"', f'exclude_filter="{com_exclusoes(exc, sorted(dados["carros"]))}"', 1)
    PRESET.write_text(texto, encoding="utf-8")
    print(f"{len(dados['carros'])} formas em {SAIDA.relative_to(RAIZ)} ({SAIDA.stat().st_size // 1024} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
