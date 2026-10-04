#!/usr/bin/env python3
"""Converte o despejo do GT2 (referencia/gt2/, saída de extrair_gt2.py) em data/.

Passos:
  1. tools/importar_gt2.py --sugerir
       Preenche a coluna codigo_gt2 de referencia/carros.csv com o carro do
       GT2 de nome mais parecido com ref_real e lista as alternativas. Revise.
  2. tools/importar_gt2.py
       Gera data/carros.json, pecas.json, pneus.json, pilotos_ia.json,
       eventos.json, licencas.json (tempos vazios), economia.json e
       carreira.json, e imprime um diagnóstico.
  3. godot --headless --script res://tools/calibrar_licencas.gd
       Preenche os tempos das licenças com a própria simulação.

Conversões (todas a partir de valores do GT2; ver data/README.md):
  potência     Engine.DisplayedPower (ps; ps ≈ cv)
  peso         Chassis.Weight (kg)
  preço, ano   Car.Price, 1900 + Car.Year
  tração       Drivetrain.DrivetrainType, códigos deduzidos da coluna
               tracao de referencia/carros.csv (falha se não forem coerentes)
  aderência    média de Chassis.FrontGrip/RearGrip ÷ mediana de todos os
               carros de rua (o carro mediano tem 1,0)
  freio        Brake.BrakingPower de fábrica ÷ mediana, no máximo 1,0
  peças        por carro (carros_permitidos), preço do GT2; efeito:
               motor (PortPolish, EngineBalance, Displacement, Computer,
               Muffler, Intercooler, NATune, TurbineKit): PowerMultiplier/100;
               peso (Lightweight): Weight ÷ peso de fábrica;
               freios (Brake): BrakingPower ÷ o de fábrica.
               NATune e TurbineKit dividem a categoria "aspiracao" (no GT2
               são excludentes).
  pneus        por estágio de TiresFront: aderência = mediana de
               GripMultiplier do estágio ÷ o de fábrica; preço = mediana.
               O GT2 não tem chuva: chuva = seco.
  eventos      voltas, licença, limite de ps, tração, prêmios (×100 fora do
               Japão), carro-prêmio quando é um dos nossos carros. A pista do
               GT2 vira uma das nossas pela função (PISTAS abaixo).
               Adversários: o carro do EnemyCars se for um dos nossos; senão o
               nosso carro elegível de potência mais próxima.
               Pilotos de IA: ritmo = média dos AI*Acceleration do evento/100.
Valores que o GT2 não tem ficam marcados como "a_confirmar" no diagnóstico.
"""
from __future__ import annotations

import argparse
import csv
import difflib
import json
import pathlib
import statistics
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
GT2 = RAIZ / "referencia" / "gt2"
REF = RAIZ / "referencia" / "carros.csv"
DATA = RAIZ / "data"

# Pista do GT2 (trecho do nome, minúsculas) -> nossa pista pela função.
PISTAS = [
    ("speedway", "anel_do_vale"), ("high speed", "anel_do_vale"), ("grand valley", "anel_do_vale"),
    ("seattle", "anel_do_vale"), ("test course", "anel_do_vale"),
    ("trial mountain", "serra_alta"), ("deep forest", "serra_alta"), ("red rock", "serra_alta"),
    ("apricot", "serra_alta"), ("tahiti", "serra_alta"), ("smokey", "serra_alta"),
]
PISTA_PADRAO = "parque_das_docas"  # técnicos: Autumn Ring, Mid-Field, Rome, Laguna Seca, Clubman...

MOTOR = ["PortPolish", "EngineBalance", "Displacement", "Computer", "Muffler", "Intercooler"]
NOMES_CATEGORIA = {
    "PortPolish": "Polimento de dutos", "EngineBalance": "Balanceamento do motor",
    "Displacement": "Aumento de cilindrada", "Computer": "Computador de bordo",
    "Muffler": "Escapamento", "Intercooler": "Intercooler", "NATune": "Preparação aspirada",
    "TurbineKit": "Kit turbo", "Lightweight": "Redução de peso", "Brake": "Freios",
}
NOMES_PNEU = ["Pneu de fábrica", "Pneu esportivo", "Pneu de corrida duro", "Pneu de corrida médio",
              "Pneu de corrida macio", "Pneu de corrida supermacio", "Pneu de simulação"]
ESTAGIO_TERRA = 7


def ler(nome: str, obrigatorio: bool = False) -> list[dict]:
    caminho = GT2 / f"{nome}.csv"
    if not caminho.exists():
        if obrigatorio:
            sys.exit(f"falta {caminho}: rode tools/extrair_gt2.py antes")
        return []  # tabela vazia no disco: o extrator não grava CSV
    return list(csv.DictReader(open(caminho, encoding="utf-8")))


def n(v) -> float:
    return float(v) if v not in (None, "") else 0.0


def sugerir() -> int:
    gt2 = ler("carros", True)
    linhas = list(csv.DictReader(open(REF, encoding="utf-8")))
    if "codigo_gt2" not in linhas[0]:
        for l in linhas:
            l["codigo_gt2"] = ""
    rotulos = {f'{c["nome"]} \'{int(n(c["ano"])) % 100:02d}': c for c in gt2}
    for l in linhas:
        alvo = l["ref_real"].split("/")[0].strip()
        opcoes = difflib.get_close_matches(alvo, list(rotulos), n=4, cutoff=0.3)
        print(f'{l["id"]:18s} {alvo}')
        for o in opcoes:
            c = rotulos[o]
            print(f'    {c["codigo"]}  {o:40s} {c["potencia_ps"]:>4s} ps {c["peso_kg"]:>5s} kg  {c["preco"]:>7s} Cr')
        if not l["codigo_gt2"] and opcoes:
            l["codigo_gt2"] = rotulos[opcoes[0]]["codigo"]
    with open(REF, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(linhas[0].keys()))
        w.writeheader()
        w.writerows(linhas)
    print(f"\ncodigo_gt2 preenchido em {REF} com a primeira opção de cada um. Revise antes de importar.")
    return 0


def deduzir_tracoes(ref: list[dict], resumo: dict) -> dict[str, str]:
    votos: dict[str, dict[str, int]] = {}
    for l in ref:
        c = resumo[l["codigo_gt2"]]
        votos.setdefault(c["tracao_tipo"], {}).setdefault(l["tracao"], 0)
        votos[c["tracao_tipo"]][l["tracao"]] += 1
    mapa = {}
    for codigo, v in votos.items():
        if len(v) > 1:
            sys.exit(f"tração incoerente: código {codigo} do GT2 aparece como {v} em referencia/carros.csv")
        mapa[codigo] = next(iter(v))
    return mapa


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--sugerir", action="store_true")
    ap.add_argument("--gt2", help="pasta do despejo (padrão referencia/gt2)")
    ap.add_argument("--ref", help="tabela de referência (padrão referencia/carros.csv)")
    ap.add_argument("--data", help="pasta de saída (padrão data/)")
    args = ap.parse_args()
    global GT2, REF, DATA
    GT2 = pathlib.Path(args.gt2) if args.gt2 else GT2
    REF = pathlib.Path(args.ref) if args.ref else REF
    DATA = pathlib.Path(args.data) if args.data else DATA
    if args.sugerir:
        return sugerir()

    ref = list(csv.DictReader(open(REF, encoding="utf-8")))
    if not ref or not all(l.get("codigo_gt2") for l in ref):
        sys.exit("preencha codigo_gt2 em referencia/carros.csv (tools/importar_gt2.py --sugerir)")
    resumo = {c["codigo"]: c for c in ler("carros", True)}
    faltando = [l["codigo_gt2"] for l in ref if l["codigo_gt2"] not in resumo]
    if faltando:
        sys.exit(f"códigos inexistentes no GT2: {faltando}")
    tab_car = {c["CarId"]: c for c in ler("Car", True)}
    partes = {nome: ler(nome) for nome in MOTOR + ["NATune", "TurbineKit", "Lightweight", "Brake", "TiresFront", "Engine"]}
    nosso = {l["codigo_gt2"]: l["id"] for l in ref}

    # Normalizações pela mediana dos carros de rua do jogo inteiro.
    grips = [(n(c["aderencia_dianteira"]) + n(c["aderencia_traseira"])) / 2 for c in resumo.values()
             if n(c["aderencia_dianteira"]) > 0]
    grip_mediana = statistics.median(grips)
    freios = partes["Brake"]
    freio_fabrica = {}
    for codigo, car in tab_car.items():
        i = int(n(car["Brake"]))
        if i < len(freios):
            freio_fabrica[codigo] = n(freios[i]["BrakingPower"])
    freio_mediana = statistics.median([v for v in freio_fabrica.values() if v > 0] or [1.0])

    tracoes = deduzir_tracoes(ref, resumo)
    carros = []
    for l in ref:
        c = resumo[l["codigo_gt2"]]
        grip = (n(c["aderencia_dianteira"]) + n(c["aderencia_traseira"])) / 2
        ano = int(n(c["ano"]))
        carros.append({
            "id": l["id"], "nome": l["nome"], "fabricante": l["fabricante"], "arquetipo_ref": l["arquetipo"],
            "categoria": l["categoria"], "tracao": tracoes[c["tracao_tipo"]],
            "potencia": int(n(c["potencia_ps"])), "peso": int(n(c["peso_kg"])),
            "aderencia": round(grip / grip_mediana, 3),
            "freio": round(min(1.0, freio_fabrica.get(l["codigo_gt2"], freio_mediana) / freio_mediana), 3),
            "preco": int(n(c["preco"])), "ano": ano + 1900 if ano < 100 else ano,
        })

    pecas = []
    for codigo, id_nosso in nosso.items():
        peso_fabrica = n(resumo[codigo]["peso_kg"])
        for cat in MOTOR + ["NATune", "TurbineKit", "Lightweight", "Brake"]:
            for p in partes[cat]:
                if p["CarId"] != codigo or int(n(p["Stage"])) == 0 or int(n(p.get("Price"))) <= 0:
                    continue
                estagio = int(n(p["Stage"]))
                if cat == "Lightweight":
                    if not 0 < n(p["Weight"]) < peso_fabrica:
                        continue
                    efeitos = [{"atributo": "peso", "op": "mult", "valor": round(n(p["Weight"]) / peso_fabrica, 4)}]
                elif cat == "Brake":
                    base = freio_fabrica.get(codigo, 0)
                    if base <= 0:
                        continue
                    efeitos = [{"atributo": "freio", "op": "mult", "valor": round(n(p["BrakingPower"]) / base, 4)}]
                else:
                    campo = "HighRPMPowerMultiplier" if cat == "TurbineKit" else "PowerMultiplier"
                    if n(p[campo]) <= 0:
                        continue
                    efeitos = [{"atributo": "potencia", "op": "mult", "valor": round(n(p[campo]) / 100.0, 4)}]
                pecas.append({
                    "id": f"{id_nosso}_{cat.lower()}_{estagio}",
                    "nome": f"{NOMES_CATEGORIA[cat]} {estagio}",
                    "categoria": "aspiracao" if cat in ("NATune", "TurbineKit") else cat.lower(),
                    "preco": int(n(p["Price"])), "carros_permitidos": [id_nosso], "efeitos": efeitos,
                })

    # Pneus: estágios de TiresFront dos nossos carros.
    por_estagio: dict[int, list[tuple[float, float]]] = {}
    fabrica_grip = {}
    for p in partes["TiresFront"]:
        if p["CarId"] not in nosso:
            continue
        est = int(n(p["Stage"]))
        if est == 0:
            fabrica_grip[p["CarId"]] = n(p["GripMultiplier"])
    for p in partes["TiresFront"]:
        est = int(n(p["Stage"]))
        base = fabrica_grip.get(p["CarId"], 0)
        if p["CarId"] not in nosso or est == ESTAGIO_TERRA or base <= 0:
            continue
        por_estagio.setdefault(est, []).append((n(p["GripMultiplier"]) / base, n(p["Price"])))
    pneus = []
    for est in sorted(por_estagio):
        ader = round(statistics.median(a for a, _ in por_estagio[est]), 3)
        pneus.append({"id": f"gt2_pneu_{est}", "nome": NOMES_PNEU[est] if est < len(NOMES_PNEU) else f"Pneu {est}",
                      "preco": 0 if est == 0 else int(statistics.median(pr for _, pr in por_estagio[est])),
                      "aderencia": {"seco": ader, "chuva": ader}})

    eventos, pilotos = importar_eventos(nosso, resumo, carros)
    licencas = []
    for lic in ("B", "A"):
        limites = [e["restricoes"]["potencia_max"] for e in eventos
                   if e["restricoes"].get("licenca") == lic and "potencia_max" in e["restricoes"]]
        restr = {"potencia_max": min(limites)} if limites else {}
        licencas.append({"id": lic, "nome": f"Licença {lic}", "requisito": "B" if lic == "A" else None,
                         "testes": [{"id": f"{lic.lower()}{k + 1}", "pista": pista, "voltas": 1, "condicao": "seco",
                                     "restricoes": restr, "tempos": {"ouro": None, "prata": None, "bronze": None}}
                                    for k, pista in enumerate(["anel_do_vale", "parque_das_docas", "serra_alta"])]})

    gravar("carros", carros)
    gravar("pecas", pecas)
    gravar("pneus", pneus)
    gravar("pilotos_ia", pilotos)
    gravar("eventos", eventos)
    gravar("licencas", licencas)
    economia = json.load(open(DATA / "economia.json"))
    economia.update({"saldo_inicial": 10000, "pneu_de_fabrica": "gt2_pneu_0"})
    gravar("economia", economia)
    carreira = json.load(open(DATA / "carreira.json"))
    carreira["piloto_jogador"] = "jogador"
    gravar("carreira", carreira)

    print(f"{len(carros)} carros, {len(pecas)} peças, {len(pneus)} pneus, {len(eventos)} eventos, {len(pilotos)} pilotos")
    print(f"aderência: mediana GT2 {grip_mediana:.1f} = 1,0 · freio: mediana {freio_mediana:.1f} = 1,0")
    print(f"tração: códigos do GT2 {tracoes}")
    print("\ncarro               ps   kg   preço  aspirado_max  turbo_max  peso_min")
    for c in carros:
        pc = [p for p in pecas if p["carros_permitidos"] == [c["id"]]]
        motor = 1.0
        for cat in MOTOR:
            ms = [p["efeitos"][0]["valor"] for p in pc if p["categoria"] == cat.lower()]
            motor *= max(ms) if ms else 1.0
        na = max([p["efeitos"][0]["valor"] for p in pc if p["id"].count("_natune_")] or [1.0])
        tb = max([p["efeitos"][0]["valor"] for p in pc if p["id"].count("_turbinekit_")] or [0.0])
        lw = min([p["efeitos"][0]["valor"] for p in pc if p["categoria"] == "lightweight"] or [1.0])
        print(f'{c["id"]:18s} {c["potencia"]:4d} {c["peso"]:4d} {c["preco"]:7d}  {c["potencia"] * motor * na:12.0f}  '
              f'{(c["potencia"] * motor * tb) if tb else 0:9.0f}  {c["peso"] * lw:8.0f}')
    print("\nCompare aspirado_max/turbo_max/peso_min com a lista de Connoy (NA MaxHP, Turbo MaxHP em hp,")
    print("Tuned Wt. em lb): se estiverem muito fora, a escala de alguma peça está errada.")
    print("a_confirmar (não vêm do GT2): fracao_revenda, usados, teto_offline_s, sigma_ruido, cda_m2, consistência e agressividade dos pilotos.")
    return 0


def importar_eventos(nosso: dict, resumo: dict, carros: list[dict]) -> tuple[list[dict], list[dict]]:
    brutos = ler("Event")
    resumidos = ler("eventos")
    inimigos = ler("EnemyCars")
    por_id = {c["id"]: c for c in carros}
    pilotos = {"jogador": {"id": "jogador", "ritmo": 1.0, "consistencia": 1.0, "agressividade": 1.0}}
    eventos = []
    for k, (b, r) in enumerate(zip(brutos, resumidos)):
        if r["rally"] not in ("", "0") or r["licenca"] not in ("", "B", "A"):
            continue
        restr = {}
        if n(r["limite_ps"]) > 0:
            restr["potencia_max"] = int(n(r["limite_ps"]))
        if r["tracao"]:
            restr["tracao"] = [r["tracao"]]
        if r["licenca"]:
            restr["licenca"] = r["licenca"]
        elegiveis = [c for c in carros
                     if c["potencia"] <= restr.get("potencia_max", 10 ** 6) and c["tracao"] in restr.get("tracao", [c["tracao"]])]
        if not elegiveis:
            continue
        ia = [n(b[c]) for c in b if c.startswith("AIAcceleration")]
        ritmo = round(statistics.mean(ia) / 100.0, 3) if ia and statistics.mean(ia) > 0 else 1.0
        id_piloto = f"gt2_ia_{int(round(ritmo * 100))}"
        pilotos[id_piloto] = {"id": id_piloto, "ritmo": ritmo, "consistencia": 1.0, "agressividade": 1.0}
        adversarios = []
        for idx in r["adversarios"].split()[:5]:
            i = int(idx)
            codigo = inimigos[i]["CarId"] if i < len(inimigos) else ""
            if codigo in nosso and nosso[codigo] in [c["id"] for c in elegiveis]:
                carro = nosso[codigo]
            else:
                alvo = n(resumo.get(codigo, {}).get("potencia_ps", 0))
                carro = min(elegiveis, key=lambda c: abs(c["potencia"] - alvo))["id"]
            adversarios.append({"carro": carro, "piloto": id_piloto})
        premio_carros = [nosso[c] for c in r["carros_premio"].split() if c in nosso]
        pista = next((nossa for trecho, nossa in PISTAS if trecho in r["pista"].lower()), PISTA_PADRAO)
        eventos.append({
            "id": f"gt2_{k:03d}", "nome": r["evento"], "pista": pista, "voltas": int(n(r["voltas"])) or 2,
            "condicao": "seco", "restricoes": restr, "adversarios": adversarios,
            "premios": [int(v) * 100 for v in r["premios_x100"].split() if int(v) > 0],
            "carro_premio": premio_carros[0] if premio_carros else None,
            "pista_gt2": r["pista"],
        })
    return eventos, list(pilotos.values())


def gravar(nome: str, obj) -> None:
    (DATA / f"{nome}.json").write_text(json.dumps(obj, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
