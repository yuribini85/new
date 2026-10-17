#!/usr/bin/env python3
"""Frota 360 (decisão 80, pedido do usuário): a frota do jogo passa a ser a dos
360 modelos 3D do pacote "Veículos 360" (+ os 3 aprovados fora da lista: Nimbo,
Bastion, Aster). Gera a tabela de referência que o importador lê no lugar de
referencia/carros.csv:

  referencia/frota360/frota.json   um carro por linha:
      {id, nome, fabricante, arquetipo, categoria, codigo_ref, doador, sobrepor,
       asset, numero, aprovado, chefe}
  referencia/frota360/antigos.json {id antigo (os 618 da referência): id novo} (saves,
      rivais, prêmios e copas de marca)

Números (CLAUDE.md, escolha do usuário):
- O carro existe na referência (referencia/frota360/casados.json, casamento revisado à mão,
  mesma geração): os números do disco, como antes (doador = false).
- Não existe: a ficha real (referencia/frota360/fichas.json: potência, peso,
  tração, ano) e um doador da referência (o carro de rua de mesma tração mais perto em
  potência e peso) que dá o que a ficha não tem: forma da curva de torque,
  câmbio, aderência, freio, distribuição de peso e a estrutura das peças. Preço
  = preço do doador × (potência/potência do doador)^1,235 × (peso/peso do
  doador)^-0,900 (expoentes da regressão log-log nos carros de rua da referência).
- Potência com fonte mas sem peso: peso pela regra ajustada nas fichas que têm
  peso (log peso ~ log(volume do modelo C×L×A) + picape/utilitário; R² 0,78,
  erro mediano 13%), marcado como estimado no relatório.
- Sem ficha (pesquisa pendente) ou sem referência real (os 3 aprovados): clone
  do carro antigo da frota mais parecido nas medidas, da mesma categoria
  (provisório; aparece no relatório).

Os chefes industriais (caminhões) não entram na loja nem nas provas (chefe =
true; só arena).

Fontes reais (nomes de marcas e modelos) ficam só em referencia/ (fora do git e
do build). Uso: python3 tools/frota360.py [--pacote PASTA_DO_PACOTE...] [--instalar]
  --instalar: troca os modelos de arte/carros3d/ pelos da frota (car.glb →
  <id>.glb, protection.glb → <id>_protecao.glb; os antigos saem).
"""
import argparse
import csv
import glob
import json
import math
import pathlib
import re
import sys
import unicodedata

RAIZ = pathlib.Path(__file__).resolve().parent.parent
REF = RAIZ / "referencia"
F360 = REF / "frota360"
FONTE = REF / "extraido"
TRACAO_REF = {"0": "FR", "1": "FF", "2": "4WD", "3": "MR", "4": "RR"}
EXP_POTENCIA = 1.235
EXP_PESO = -0.900
CATEGORIA = {
    "hatch": "compacto", "hatch alto": "compacto", "microcarro": "compacto",
    "sedã": "seda", "sedã duas portas": "seda", "sedã liftback": "seda", "perua": "seda",
    "picape": "picape", "SUV 4×4": "utilitario", "jipe 4×4": "utilitario",
}
NOME_CAT = {"compacto": "compacto", "seda": "sedã", "cupe": "cupê", "picape": "picape", "utilitario": "utilitário",
            "pesado": "pesado"}
EXTRAS = {"nimbo": "compacto", "bastion": "seda", "aster": "cupe"}
# Marcas antigas sem carro na frota nova: a irmã da mesma marca real (saves e rivais).
IRMA = {"arvelle": "hozuki", "brayford": "lindauer", "tokiwa": "hayase"}


def categoria(cat_pacote: str) -> str:
    if cat_pacote.startswith("caminhão"):
        return "pesado"
    return CATEGORIA.get(cat_pacote, "cupe")


def slug(s: str) -> str:
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")


def arquetipo(cat: str, tracao: str, cv: float) -> str:
    for teto in (100, 200, 300, 450, 600, 800):
        if cv <= teto:
            return f"{NOME_CAT[cat]} {tracao} até {teto} cv"
    return f"{NOME_CAT[cat]} {tracao} acima de 800 cv"


def marca_de(ref: str, marcas: dict) -> str:
    for b in sorted(marcas, key=len, reverse=True):
        if ref.startswith(b):
            return marcas[b]
    sys.exit(f"sem marca fictícia para {ref!r} (referencia/frota360/marcas.json)")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pacote", nargs="*", default=[], help="pastas do pacote (model-info.json de cada carro)")
    ap.add_argument("--instalar", action="store_true", help="instala os GLB em arte/carros3d/")
    args = ap.parse_args()
    mapa = []
    for f in sorted(F360.glob("mapa_parte*.json")):
        mapa += json.load(open(f, encoding="utf-8"))
    mapa.sort(key=lambda m: m["number"])
    m = json.load(open(F360 / "marcas.json", encoding="utf-8"))
    marcas = dict(m["existentes"])
    for fid, v in m["novas"].items():
        for b in v["marcas"]:
            marcas[b] = fid
    casados = {int(k): v for k, v in json.load(open(F360 / "casados.json", encoding="utf-8")).items()}
    fichas = {x["n"]: x for x in json.load(open(F360 / "fichas.json", encoding="utf-8"))}
    info = {}
    for pasta in args.pacote or [str(F360 / "pacote")]:
        for f in glob.glob(f"{pasta}/*/model-info.json"):
            d = json.load(open(f, encoding="utf-8"))
            info[d["id"]] = d
    fonte = {c["codigo"]: c for c in csv.DictReader(open(FONTE / "carros.csv", encoding="utf-8"))}
    antigos = list(csv.DictReader(open(REF / "carros.csv", encoding="utf-8")))
    num = lambda v: float(v) if v not in (None, "") else 0.0
    # Tração de cada código da referência (pela tabela antiga, que já foi conferida).
    tracao_cod = {}
    for a in antigos:
        tracao_cod[fonte[a["codigo_ref"]]["tracao_tipo"]] = a["tracao"]
    tracao_de = lambda cod: tracao_cod.get(fonte[cod]["tracao_tipo"], TRACAO_REF.get(fonte[cod]["tracao_tipo"], "FR"))
    rua = [c for c in fonte.values() if c["codigo"].endswith("n") and num(c["potencia_ps"]) > 0 and num(c["peso_kg"]) > 0
           and num(c["preco"]) > 0]
    # Medidas da frota antiga (docs/carros_3d/lista.csv) para os clones.
    medidas = {}
    lista = RAIZ / "docs" / "carros_3d" / "lista.csv"
    if lista.exists():
        for l in csv.DictReader(open(lista, encoding="utf-8")):
            medidas[l["arquivo"][:-4]] = (num(l["comprimento_m"]), num(l["largura_m"]), num(l["altura_m"]), l["carroceria"])
    por_id_antigo = {a["id"]: a for a in antigos}

    def doador(tracao: str, cv: float, kg: float) -> dict:
        def custo(c):
            d = abs(math.log(num(c["potencia_ps"]) / cv)) + abs(math.log(num(c["peso_kg"]) / kg))
            return d + (0 if tracao_de(c["codigo"]) == tracao else 2.0)
        return min(rua, key=custo)

    def clone(cat: str, L: float, W: float, H: float) -> str:
        cats = {"compacto": "hatch", "seda": "sedã", "cupe": "cupê"}
        cand = [i for i, md in medidas.items() if i in por_id_antigo and cats.get(cat, "") in md[3]] or list(medidas)
        return min(cand, key=lambda i: abs(medidas[i][0] - L) + abs(medidas[i][1] - W) + abs(medidas[i][2] - H))

    # Peso pelo volume do modelo (regra ajustada nas fichas com peso real).
    amostras = []
    for x in mapa:
        f = fichas.get(x["number"], {})
        mi = info.get(x["asset_id"])
        c = categoria(x["category"])
        if f.get("peso_kg") and f.get("fontes") and mi and c != "pesado":
            amostras.append(([1.0, math.log(mi["L"] * mi["W"] * mi["H"]), float(c == "picape"), float(c == "utilitario")],
                             math.log(float(f["peso_kg"]))))
    coef = _minimos_quadrados([a for a, _ in amostras], [b for _, b in amostras])
    peso_volume = lambda mi, c: math.exp(sum(k * v for k, v in zip(coef, [1.0, math.log(mi["L"] * mi["W"] * mi["H"]),
                                                                        float(c == "picape"), float(c == "utilitario")])))
    estimados = []
    linhas = []
    usados_ids = set()
    pendentes = []
    entradas = [(x["number"], x["asset_id"], x["reference_name"], x["category"]) for x in mapa]
    entradas += [(None, a, None, None) for a in EXTRAS]
    for numero, asset, ref, cat_pacote in entradas:
        mi = info.get(asset)
        if mi is None:
            sys.exit(f"falta model-info de {asset} (passe --pacote)")
        nome_modelo = mi["name"].split(" — ")[0].strip()
        cat = EXTRAS[asset] if numero is None else categoria(cat_pacote)
        fab = marca_de(ref, marcas) if ref else "vantra" if asset == "aster" else "feldhaus" if asset == "nimbo" else "norrvik"
        linha = {"numero": numero, "asset": asset, "fabricante": fab, "categoria": cat, "chefe": cat == "pesado",
                 "aprovado": numero is None}
        if numero in casados:
            cod = casados[numero]
            linha.update({"codigo_ref": cod, "doador": False, "sobrepor": {}})
            cv, tracao = num(fonte[cod]["potencia_ps"]), tracao_de(cod)
        else:
            f = fichas.get(numero, {}) if numero is not None else {}
            if f.get("potencia_cv") and f.get("fontes") and not f.get("peso_kg") and cat != "pesado":
                f = dict(f, peso_kg=round(peso_volume(mi, cat)))
                estimados.append(asset)
            if f.get("potencia_cv") and f.get("peso_kg") and f.get("fontes"):
                cv, kg = float(f["potencia_cv"]), float(f["peso_kg"])
                tracao = f.get("tracao") if f.get("tracao") in TRACAO_REF.values() else "FR"
                d = doador(tracao, cv, kg)
                preco = num(d["preco"]) * (cv / num(d["potencia_ps"])) ** EXP_POTENCIA * (kg / num(d["peso_kg"])) ** EXP_PESO
                sob = {"potencia": round(cv), "peso": round(kg), "tracao": tracao, "preco_cr": round(preco)}
                if f.get("ano"):
                    sob["ano"] = int(f["ano"])
                linha.update({"codigo_ref": d["codigo"], "doador": True, "sobrepor": sob})
            else:
                # Sem ficha conferida: clone do antigo mais parecido nas medidas.
                velho = por_id_antigo[clone(cat, mi["L"], mi["W"], mi["H"])]
                linha.update({"codigo_ref": velho["codigo_ref"], "doador": True, "sobrepor": {}, "clone": True})
                cv, tracao = num(fonte[velho["codigo_ref"]]["potencia_ps"]), tracao_de(velho["codigo_ref"])
                pendentes.append(asset)
        cid = slug(f"{fab}_{nome_modelo}")
        k = 2
        while cid in usados_ids:
            cid = slug(f"{fab}_{nome_modelo}_{k}")
            k += 1
        usados_ids.add(cid)
        nome_fab = m["novas"].get(fab, {}).get("nome") or fab.capitalize()
        linha.update({"id": cid, "nome": f"{nome_fab} {nome_modelo}",
                      "arquetipo": arquetipo(cat, linha["sobrepor"].get("tracao", tracao),
                                             linha["sobrepor"].get("potencia", cv))})
        linhas.append(linha)
    # Antigo -> novo: o casado exato; senão o da mesma marca fictícia mais perto
    # em potência e peso; senão o mais perto da frota (fora os chefes).
    def pot_peso(l):
        s = l["sobrepor"]
        c = fonte[l["codigo_ref"]]
        return s.get("potencia", num(c["potencia_ps"])), s.get("peso", num(c["peso_kg"]))
    novos = [l for l in linhas if not l["chefe"]]
    exato = {l["codigo_ref"]: l["id"] for l in novos if not l["doador"]}
    mapa_antigo = {}
    for a in antigos:
        if a["codigo_ref"] in exato:
            mapa_antigo[a["id"]] = exato[a["codigo_ref"]]
            continue
        c = fonte[a["codigo_ref"]]
        cv, kg = max(num(c["potencia_ps"]), 1), max(num(c["peso_kg"]), 1)
        fab = IRMA.get(a["fabricante"], a["fabricante"])
        mesma = [l for l in novos if l["fabricante"] == fab] or novos
        dist = lambda l: abs(math.log(max(pot_peso(l)[0], 1) / cv)) + abs(math.log(max(pot_peso(l)[1], 1) / kg))
        mapa_antigo[a["id"]] = min(mesma, key=dist)["id"]
    json.dump(linhas, open(F360 / "frota.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump(mapa_antigo, open(F360 / "antigos.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"{len(linhas)} carros: {sum(1 for l in linhas if not l['doador'])} da referência, "
          f"{sum(1 for l in linhas if l['doador'] and not l.get('clone'))} ficha + doador, "
          f"{len(pendentes)} clones provisórios (sem ficha), {sum(1 for l in linhas if l['chefe'])} chefes")
    if args.instalar:
        instalar(linhas, args.pacote or [str(F360 / "pacote")])
    if estimados:
        print("peso pelo volume:", ", ".join(estimados))
    if pendentes:
        print("sem ficha:", ", ".join(pendentes))
    return 0


def instalar(linhas: list[dict], pastas: list[str]) -> None:
    import shutil
    destino = RAIZ / "arte" / "carros3d"
    for velho in destino.iterdir():
        if velho.is_file():
            velho.unlink()
    for l in linhas:
        for pasta in pastas:
            origem = pathlib.Path(pasta) / l["asset"]
            if (origem / "car.glb").exists():
                shutil.copy(origem / "car.glb", destino / f"{l['id']}.glb")
                shutil.copy(origem / "protection.glb", destino / f"{l['id']}_protecao.glb")
                break
        else:
            sys.exit(f"falta o modelo de {l['asset']}")
    print(f"{len(linhas)} modelos instalados em arte/carros3d/")


def _minimos_quadrados(x: list[list[float]], y: list[float]) -> list[float]:
    """Coeficientes de y ~ x (equações normais, sem numpy)."""
    n = len(x[0])
    ata = [[sum(r[i] * r[j] for r in x) for j in range(n)] for i in range(n)]
    aty = [sum(r[i] * v for r, v in zip(x, y)) for i in range(n)]
    for i in range(n):  # Gauss-Jordan
        piv = max(range(i, n), key=lambda k: abs(ata[k][i]))
        ata[i], ata[piv], aty[i], aty[piv] = ata[piv], ata[i], aty[piv], aty[i]
        for k in range(n):
            if k != i:
                fator = ata[k][i] / ata[i][i]
                ata[k] = [a - fator * b for a, b in zip(ata[k], ata[i])]
                aty[k] -= fator * aty[i]
    return [aty[i] / ata[i][i] for i in range(n)]


if __name__ == "__main__":
    sys.exit(main())
