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
  potência     pico da curva de torque do motor (Engine.TorqueCurve × rpm ×
               PowerMultiplier/100), em ps. Bate com a lista de Connoy (garagem do
               GT2) em ~1%; DisplayedPower é o número de concessionária, impreciso.
  peso         Chassis.Weight (kg)
  dinheiro     todo valor em Cr do GT2 (preços de carros, peças, pneus e usados,
               prêmios, bônus de campeão, saldo inicial) vira Giros (G):
               × FATOR_MOEDA, arredondado (moeda(); mínimo 1 G se não era 0).
               O fator quebrado tira o padrão de 00/000 dos preços do GT2.
  preço, ano   Car.Price, 1900 + Car.Year; carros de fora do Japão têm ano 0
               no GT2 e usam a coluna ano de referencia/carros.csv
  novo         só se o carro nunca aparece nos usados do GT2 (lá os modelos
               antigos só se compram usados)
  tração       Drivetrain.DrivetrainType, códigos deduzidos da coluna
               tracao de referencia/carros.csv (falha se não forem coerentes)
  peso dianteiro  Chassis.FrontWeightDistribution ÷ 100 (fração do peso no eixo
               dianteiro): a tração usa o peso sobre o eixo motriz
  aderência    média de Chassis.FrontGrip/RearGrip ÷ mediana de todos os
               carros de rua (o carro mediano tem 1,0)
  freio        Brake.BrakingPower de fábrica ÷ mediana, no máximo 1,0
  peças        por carro (carros_permitidos), preço do GT2; efeito:
               motor: ganho percentual sobre a potência de fábrica, somado
               (op "soma", em ps): PortPolish, EngineBalance, Displacement,
               Computer, Muffler, Intercooler = PowerMultiplier + PowerbandScaling;
               NATune = PowerMultiplier; TurbineKit = HighRPMPowerMultiplier.
               Conferido contra Connoy: turbo máx. ~3%, aspirado máx. ~7% abaixo
               (o GT2 ainda sobe a rotação, que o nosso modelo não tem);
               peso (Lightweight): Weight é o peso final em ‰ do de fábrica
               (bate exato com Connoy);
               freios (Brake): BrakingPower ÷ o de fábrica.
               NATune e TurbineKit dividem a categoria "aspiracao" (no GT2
               são excludentes).
  motor        Engine: curva de torque (TorqueCurve × 0,01 kgf·m × 9,80665 ×
               PowerMultiplier/100, em N·m) nas rotações TorqueCurveRPM × 100;
               corte = RedlineRPM × 100. O pico de torque × rpm dá a potência acima.
  câmbio       Gear de fábrica (índice em Car.Gear): relações e diferencial ÷ 1000.
               O câmbio ajustável (Gear estágio 3) vira peça "cambio" com o preço
               do GT2 e os limites MinFinalDriveRatio/MaxFinalDriveRatio.
  roda         raio do pneu de fábrica (TiresFront → TireSize): aro em polegadas
               ÷ 2 + largura × perfil. Interpretação a confirmar: largura em cm
               (×10 mm) e perfil em passos de 5% (×5), o que dá 150–220 mm e
               45–65%, faixas de pneus de rua.
  forma do motor  EngineBalance: RPMIncrease (×100 rpm) sobe o corte.
               NATune: PowerbandRPMIncrease e RPMIncrease (×100 rpm) deslocam
               a curva e o corte; TurbineKit: o torque vai de LowRPMPowerMultiplier%
               (giro baixo) a 100% + HighRPMPowerMultiplier% (giro alto). A
               potência final continua a da conta acima; a forma muda onde ela está.
  usados       .usedcar_usa: janelas [dia_inicio, dia_fim, preço] por período
               de 10 dias (dia = corridas disputadas)
  pneus        por estágio de TiresFront: o grip é o 1º byte do composto
               (TireCompound); aderência = grip do estágio ÷ o de fábrica
               (mediana entre os nossos carros); preço = mediana. Sem terra.
               O GT2 não tem chuva: chuva = seco.
  eventos      voltas, licença, limite de ps, tração, prêmios (×100 fora do
               Japão), carro-prêmio quando é um dos nossos carros. A pista do
               GT2 vira uma das nossas pela função (PISTAS abaixo).
               Adversários: o carro do EnemyCars com a preparação dele
               (PowerMultiplier ÷ 100 multiplica a potência; pneu do estágio de
               TiresFront). Largada lançada: RollingStartSpeed (km/h).
               Pilotos de IA: ritmo = média dos AI*Acceleration do evento/100.
               Copas de marca (EligibleCarsRestriction ≠ 0): a lista de carros
               vem de Regulations (índice base 1; EligibleCarIds são ids de
               carro, ver gt2/tabelas.id_para_nome). CarRestrictionFlags 256 =
               só carro de rua; 512 = versão de corrida (kit ou carro de
               corrida). A pista é sorteada no GT2 (pool); aqui gira pelas
               nossas pistas de corrida, na ordem dos eventos.
  kit corrida  RacingModify estágio 1 (a carroceria de corrida do GT2): peça
               "corrida" com o preço e o peso (Weight em % do de fábrica). A
               pressão aerodinâmica (Downforce) e o arrasto (Drag) ficam de
               fora: a simulação não tem esses termos por carro.
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

# Saída em UTF-8 também no Windows (o console padrão lá é cp1252).
for _fluxo in (sys.stdout, sys.stderr):
    if hasattr(_fluxo, "reconfigure"):
        _fluxo.reconfigure(encoding="utf-8", errors="replace")

RAIZ = pathlib.Path(__file__).resolve().parent.parent
GT2 = RAIZ / "referencia" / "gt2"
REF = RAIZ / "referencia" / "carros.csv"
DATA = RAIZ / "data"

# Pista do GT2 (id interno) -> nossa pista pela função (docs/pistas_arquetipos.md).
# As versões curtas do GT2 vão para a versão curta da nossa pista do mesmo grupo.
PISTAS = {
    "highway": "anel_do_vale", "s_speed": "anel_do_vale", "speed": "anel_do_vale", "seattle": "anel_do_vale",
    "circuit": "anel_do_vale", "seatt_s": "anel_curto",
    # Retas muito longas (grupo 1).
    "test_in2": "pista_de_testes", "testline": "pista_de_testes", "maxspeed": "pista_de_testes",
    "mountain": "serra_alta", "grindel": "serra_alta", "tahiti_t": "serra_alta", "parma": "serra_alta",
    "new_parmas": "serra_curta",
    # Misto permanente (grupo 4).
    "laguna": "circuito_misto", "autumn": "circuito_misto",
    "roma_short": "docas_curta",
}
PISTA_PADRAO = "parque_das_docas"  # técnicas: roma, shortway, short, sprint2

# Séries do GT2 que entram no jogo (prefixo do código do evento -> nosso nome).
# Fora: rali, testes de licença e a licença S (os eventos dela não têm pista no
# disco). As copas de marca entram à parte (Regulations). O resto do evento vem
# do disco. Resistência (RESISTENCIA): prova única, com as voltas do GT2, sem
# pit stop nem desgaste de pneu (o jogo não tem esses sistemas).
SERIES = {
    "SND": "Copa de Domingo", "CBM": "Copa Clube", "WLK": "Copa Peso-Leve",
    "GJL": "Liga Regional I", "GUL": "Liga Regional II", "GBL": "Liga Regional III",
    "GFL": "Liga Regional IV", "GGL": "Liga Regional V", "GIL": "Liga Regional VI", "GCC": "Liga Regional VII",
    "FFC": "Desafio Tração Dianteira", "FRC": "Desafio Tração Traseira", "4WD": "Desafio 4x4",
    "80S": "Copa Anos 80", "HTC": "Troféu 250", "WOS": "Copa Aberta 250", "SLS": "Copa 400", "PSC": "Série 400",
    "WGN": "Copa Grand Tour", "MRC": "Desafio Motor Central", "MSC": "Copa Livre", "PFL": "Série 550",
    "STT": "Série 500", "EPL": "Copa Continental", "GT3": "Campeonato GT Leve", "GTC": "Campeonato GT Clube",
    "GT5": "Campeonato GT Pesado", "GTA": "Mundial de Estrelas", "GTW": "Liga Mundial GT", "TCN": "Copa Turismo",
    "TCT": "Copa Preparados",
    # Resistência (nome pela nossa pista: highway, seattle e circuit viram o Anel do Vale).
    "EGV": "Resistência do Vale", "ELS": "Resistência do Vinhedo", "EPS": "Resistência da Serra Curta",
    "ERM": "Resistência das Docas", "ES5": "Resistência Expressa", "EST": "Resistência do Anel",
    "ETM": "Resistência da Serra",
}
RESISTENCIA = {"EGV", "ELS", "EPS", "ERM", "ES5", "EST", "ETM"}
LICENCAS_GT2 = ["B", "A", "IC", "IB", "IA"]
# Licenças do jogo (decisão 33): CLUB=B, SPORT=A, NATIONAL=IC, INTERNATIONAL=IB,
# PRO=IA; ELITE (a S do GT2, sem dados no disco) libera as resistências.
LICENCA_DO_GT2 = {"B": "CLUB", "A": "SPORT", "IC": "NATIONAL", "IB": "INTERNATIONAL", "IA": "PRO"}
LICENCAS = ["CLUB", "SPORT", "NATIONAL", "INTERNATIONAL", "PRO", "ELITE"]
NOMES_LICENCA = {"CLUB": "Club", "SPORT": "Sport", "NATIONAL": "National", "INTERNATIONAL": "International",
                 "PRO": "Pro", "ELITE": "Elite"}
# Ids antigos dos testes (b1...) -> novos (club1...): o importador guarda os tempos
# já calibrados ao trocar os ids.
TESTE_ANTIGO = {k.lower(): v.lower() for k, v in LICENCA_DO_GT2.items()}
# Enquanto uma pista nova não está em data/pistas.json, os eventos dela vão para
# a pista do mesmo grupo que já existe.
PISTA_DE_RESERVA = {"anel_curto": "anel_do_vale", "serra_curta": "serra_alta", "docas_curta": "parque_das_docas",
                    "circuito_misto": "parque_das_docas"}
PISTAS_EXISTENTES: set[str] = set()
# Acima disso são os testes de licença do disco (255 voltas), que não entram.
MAX_VOLTAS = 99
FRACAO_REVENDA = 0.25
FATOR_MOEDA = 0.0427  # Cr do GT2 → Giros (decisão do usuário: valores bem menores, sem rastro)
# Copas de marca: CarRestrictionFlags do GT2.
SO_RUA, SO_CORRIDA = 256, 512
CARACTERES_ID = "-0123456789abcdefghijklmnopqrstuvwxyz"
# Pistas de corrida para as copas de marca (o GT2 sorteia; a de testes fica de fora).
POOL_MARCA = ["anel_do_vale", "parque_das_docas", "serra_alta", "circuito_misto", "anel_curto", "docas_curta",
              "serra_curta"]

MOTOR = ["PortPolish", "EngineBalance", "Displacement", "Computer", "Muffler", "Intercooler"]
NOMES_CATEGORIA = {
    "PortPolish": "Polimento de dutos", "EngineBalance": "Balanceamento do motor",
    "Displacement": "Aumento de cilindrada", "Computer": "Computador de bordo",
    "Muffler": "Escapamento", "Intercooler": "Intercooler", "NATune": "Preparação aspirada",
    "TurbineKit": "Kit turbo", "Lightweight": "Redução de peso", "Brake": "Freios",
    "RacingModify": "Kit de corrida",
}
NOMES_PNEU = ["Pneu de fábrica", "Pneu esportivo", "Pneu de corrida duro", "Pneu de corrida médio",
              "Pneu de corrida macio", "Pneu de corrida supermacio", "Pneu de simulação"]
ESTAGIO_TERRA = 7
CONSISTENCIA = 0.7
AGRESSIVIDADE = 1.0


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

    global PISTAS_EXISTENTES
    caminho_pistas = DATA / "pistas.json"
    PISTAS_EXISTENTES = {p["id"] for p in json.load(open(caminho_pistas, encoding="utf-8"))} if caminho_pistas.exists() \
            else set(PISTAS.values()) | {PISTA_PADRAO}
    ref = list(csv.DictReader(open(REF, encoding="utf-8")))
    if not ref or not all(l.get("codigo_gt2") for l in ref):
        sys.exit("preencha codigo_gt2 em referencia/carros.csv (tools/importar_gt2.py --sugerir)")
    resumo = {c["codigo"]: c for c in ler("carros", True)}
    faltando = [l["codigo_gt2"] for l in ref if l["codigo_gt2"] not in resumo]
    if faltando:
        sys.exit(f"códigos inexistentes no GT2: {faltando}")
    tab_car = {c["CarId"]: c for c in ler("Car", True)}
    partes = {nome: ler(nome) for nome in MOTOR + ["NATune", "TurbineKit", "Lightweight", "Brake", "TiresFront", "Engine",
                                                     "Gear", "TireSize", "RacingModify"]}
    motores = partes["Engine"]
    potencia = {cod: potencia_curva(motores[int(n(car["Engine"]))]) for cod, car in tab_car.items()
                if int(n(car["Engine"])) < len(motores)}
    for cod, c in resumo.items():
        c["potencia_real"] = potencia.get(cod, n(c["potencia_ps"]))
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
    chassis = {r["CarId"]: r for r in ler("Chassis")}
    carros = []
    for l in ref:
        c = resumo[l["codigo_gt2"]]
        grip = (n(c["aderencia_dianteira"]) + n(c["aderencia_traseira"])) / 2
        ano = int(n(c["ano"]))
        carros.append({
            "id": l["id"], "nome": l["nome"], "fabricante": l["fabricante"], "arquetipo_ref": l["arquetipo"],
            "categoria": l["categoria"], "tracao": tracoes[c["tracao_tipo"]],
            "potencia": int(round(c["potencia_real"])), "peso": int(n(c["peso_kg"])),
            "aderencia": round(grip / grip_mediana, 3),
            "freio": round(min(1.0, freio_fabrica.get(l["codigo_gt2"], freio_mediana) / freio_mediana), 3),
            "preco": moeda(n(c["preco"])),
            "ano": (ano + 1900 if ano < 100 else ano) if ano > 0 else int(n(l.get("ano"))),
        })
        car = tab_car[l["codigo_gt2"]]
        ch = chassis.get(l["codigo_gt2"], {})
        if n(ch.get("FrontWeightDistribution", 0)) > 0:
            carros[-1]["peso_dianteiro"] = round(n(ch["FrontWeightDistribution"]) / 100.0, 3)
        carros[-1].update(motor_cambio_roda(car, partes))
        if l["codigo_gt2"].endswith("r"):
            carros[-1]["corrida"] = True  # carro de corrida de fábrica (vale nas copas "versão de corrida")
        janelas = usados_do_carro(l["codigo_gt2"])
        carros[-1]["novo"] = not janelas
        if janelas:
            carros[-1]["usados"] = janelas

    pecas = []
    for codigo, id_nosso in nosso.items():
        base_ps = resumo[codigo]["potencia_real"]
        for cat in MOTOR + ["NATune", "TurbineKit", "Lightweight", "Brake"]:
            for p in partes[cat]:
                if p["CarId"] != codigo or int(n(p["Stage"])) == 0 or int(n(p.get("Price"))) <= 0:
                    continue
                estagio = int(n(p["Stage"]))
                if cat == "Lightweight":
                    if not 0 < n(p["Weight"]) < 1000:
                        continue
                    efeitos = [{"atributo": "peso", "op": "mult", "valor": round(n(p["Weight"]) / 1000.0, 4)}]
                elif cat == "Brake":
                    base = freio_fabrica.get(codigo, 0)
                    if base <= 0:
                        continue
                    efeitos = [{"atributo": "freio", "op": "mult", "valor": round(n(p["BrakingPower"]) / base, 4)}]
                else:
                    if cat == "TurbineKit":
                        pct = n(p["HighRPMPowerMultiplier"])
                    elif cat == "NATune":
                        pct = n(p["PowerMultiplier"])
                    else:
                        pct = n(p["PowerMultiplier"]) + n(p.get("PowerbandScaling"))
                    if pct <= 0:
                        continue
                    efeitos = [{"atributo": "potencia", "op": "soma", "valor": round(base_ps * pct / 100.0, 1)}]
                forma = {}
                if cat == "NATune":
                    forma = {"faixa_rpm": int(n(p["PowerbandRPMIncrease"])) * 100, "corte": int(n(p["RPMIncrease"])) * 100}
                elif cat == "TurbineKit":
                    forma = {"turbo_baixa": n(p["LowRPMPowerMultiplier"]) / 100.0,
                             "turbo_alta": 1.0 + n(p["HighRPMPowerMultiplier"]) / 100.0,
                             "corte": int(n(p["RedlineIncrease"])) * 100}
                elif int(n(p.get("RPMIncrease", 0))) > 0:
                    # Balanceamento do motor: sobe o corte (mesma unidade da NATune).
                    forma = {"corte": int(n(p["RPMIncrease"])) * 100}
                pecas.append({
                    "id": f"{id_nosso}_{cat.lower()}_{estagio}",
                    "nome": f"{NOMES_CATEGORIA[cat]} {estagio}",
                    "categoria": "aspiracao" if cat in ("NATune", "TurbineKit") else cat.lower(),
                    "preco": moeda(n(p["Price"])), "carros_permitidos": [id_nosso], "efeitos": efeitos,
                })
                if forma:
                    pecas[-1]["motor"] = forma
        # Kit de corrida (RacingModify): o estágio mais baixo com preço.
        kits = sorted((p for p in partes["RacingModify"] if p["CarId"] == codigo and int(n(p["Stage"])) > 0
                       and int(n(p["Price"])) > 0 and not codigo.endswith("r")), key=lambda p: int(n(p["Stage"])))
        if kits and 0 < n(kits[0]["Weight"]) <= 100:
            pecas.append({
                "id": f"{id_nosso}_corrida", "nome": NOMES_CATEGORIA["RacingModify"], "categoria": "corrida",
                "preco": moeda(n(kits[0]["Price"])), "carros_permitidos": [id_nosso],
                "efeitos": [{"atributo": "peso", "op": "mult", "valor": round(n(kits[0]["Weight"]) / 100.0, 4)}],
            })
        # Câmbio ajustável (Gear estágio 3): limites do diferencial do GT2.
        for g in partes["Gear"]:
            if g["CarId"] == codigo and int(n(g["Stage"])) == 3 and int(n(g["Price"])) > 0:
                pecas.append({
                    "id": f"{id_nosso}_cambio", "nome": "Câmbio ajustável", "categoria": "cambio",
                    "preco": moeda(n(g["Price"])), "carros_permitidos": [id_nosso], "efeitos": [],
                    "cambio": {"final_min": n(g["MinFinalDriveRatio"]) / 1000.0, "final_max": n(g["MaxFinalDriveRatio"]) / 1000.0},
                })

    # Pneus: estágios de TiresFront dos nossos carros; grip no 1º byte do composto.
    compostos = [int(c["_bruto"][:2], 16) for c in ler("TireCompound")]
    grip_pneu = lambda p: compostos[int(n(p["TireCompound"]))] if int(n(p["TireCompound"])) < len(compostos) else 0
    por_estagio: dict[int, list[tuple[float, float]]] = {}
    fabrica_grip = {}
    for p in partes["TiresFront"]:
        if p["CarId"] in nosso and int(n(p["Stage"])) == 0:
            fabrica_grip[p["CarId"]] = grip_pneu(p)
    for p in partes["TiresFront"]:
        est = int(n(p["Stage"]))
        base = fabrica_grip.get(p["CarId"], 0)
        if p["CarId"] not in nosso or est == ESTAGIO_TERRA or base <= 0:
            continue
        por_estagio.setdefault(est, []).append((grip_pneu(p) / base, n(p["Price"])))
    pneus = []
    for est in sorted(por_estagio):
        ader = round(statistics.median(a for a, _ in por_estagio[est]), 3)
        pneus.append({"id": f"pneu_{est}", "nome": NOMES_PNEU[est] if est < len(NOMES_PNEU) else f"Pneu {est}",
                      "preco": 0 if est == 0 else moeda(statistics.median(pr for _, pr in por_estagio[est])),
                      "aderencia": {"seco": ader, "chuva": ader}})

    eventos, pilotos = importar_eventos(nosso, resumo, carros, {p["id"] for p in pneus})
    # Tempos já calibrados (calibrar_licencas.gd) ficam, inclusive dos ids antigos.
    caminho_lic = DATA / "licencas.json"
    tempos_antigos = {}
    if caminho_lic.exists():
        for l in json.load(open(caminho_lic, encoding="utf-8")):
            for t in l.get("testes", []):
                tid = t["id"]
                novo = TESTE_ANTIGO.get(tid.rstrip("0123456789"), tid.rstrip("0123456789")) + tid[len(tid.rstrip("0123456789")):]
                if all(v is not None for v in t.get("tempos", {}).values()):
                    tempos_antigos[novo] = t["tempos"]
    licencas = []
    for lic in LICENCAS:
        limites = sorted(e["restricoes"]["potencia_max"] for e in eventos
                         if e["restricoes"].get("licenca") == lic and "potencia_max" in e["restricoes"])
        if lic == "CLUB":
            # Mediana dos limites de potência dos eventos que a licença abre.
            por_teste = [int(statistics.median(limites))] * 3 if limites else [None] * 3
        else:
            # A: mediana, quartil inferior e superior dos limites das provas A
            # (o limite real mais próximo de cada um). Limites diferentes por
            # teste: potência sozinha não resolve todos.
            por_teste = [None] * 3
            if limites:
                q1, q2, q3 = statistics.quantiles(limites, n=4, method="inclusive")
                por_teste = [min(limites, key=lambda x: abs(x - q)) for q in (q2, q1, q3)]
        anterior = LICENCAS[LICENCAS.index(lic) - 1] if lic != LICENCAS[0] else None
        testes = [{"id": f"{lic.lower()}{k + 1}", "pista": pista, "voltas": 1, "condicao": "seco",
                   "restricoes": {"potencia_max": por_teste[k]} if por_teste[k] else {},
                   "tempos": tempos_antigos.get(f"{lic.lower()}{k + 1}", {"ouro": None, "prata": None, "bronze": None})}
                  for k, pista in enumerate(["anel_do_vale", "parque_das_docas", "serra_alta"])]
        if lic == "ELITE":
            testes = []  # a S do GT2 não tem testes no disco: a avaliação são os contratos
        licencas.append({"id": lic, "nome": f"Licença {NOMES_LICENCA[lic]}", "requisito": anterior,
                         "gt2": next((k for k, v in LICENCA_DO_GT2.items() if v == lic), "S"), "preco": 0,
                         "testes": testes})

    gravar("carros", carros)
    gravar("pecas", pecas)
    gravar("pneus", pneus)
    gravar("pilotos_ia", pilotos)
    gravar("eventos", eventos)
    gravar("licencas", licencas)
    economia = json.load(open(DATA / "economia.json", encoding="utf-8"))
    # Revenda medida no GT2 (DuckStation): venda = 25% do Car.Price, seja qual for o
    # preço pago no usado; peças não entram (3 carros: 8000→2000, 6400→1600, 2800→700).
    economia.update({"saldo_inicial": moeda(10000), "pneu_de_fabrica": "pneu_0", "fracao_revenda": FRACAO_REVENDA})
    gravar("economia", economia)
    carreira = json.load(open(DATA / "carreira.json", encoding="utf-8"))
    carreira["piloto_jogador"] = "jogador"
    gravar("carreira", carreira)

    print(f"{len(carros)} carros, {len(pecas)} peças, {len(pneus)} pneus, {len(eventos)} eventos, {len(pilotos)} pilotos")
    print(f"aderência: mediana GT2 {grip_mediana:.1f} = 1,0 · freio: mediana {freio_mediana:.1f} = 1,0")
    print(f"tração: códigos do GT2 {tracoes}")
    print("\ncarro               ps   kg   preço  aspirado_max  turbo_max  peso_min")
    for c in carros:
        pc = [p for p in pecas if p["carros_permitidos"] == [c["id"]]]
        def melhor(cat):
            return max([p["efeitos"][0]["valor"] for p in pc if p["id"].startswith(f'{c["id"]}_{cat}_')] or [0.0])
        motor = sum(melhor(cat.lower()) for cat in MOTOR)
        na, tb = melhor("natune"), melhor("turbinekit")
        lw = min([p["efeitos"][0]["valor"] for p in pc if p["categoria"] == "lightweight"] or [1.0])
        print(f'{c["id"]:18s} {c["potencia"]:4d} {c["peso"]:4d} {c["preco"]:7d}  {c["potencia"] + motor + na:12.0f}  '
              f'{(c["potencia"] + motor + tb) if tb else 0:9.0f}  {c["peso"] * lw:8.0f}')
    print("\nCompare aspirado_max/turbo_max/peso_min com a lista de Connoy (NA MaxHP, Turbo MaxHP em hp,")
    print("Tuned Wt. em lb): se estiverem muito fora, a escala de alguma peça está errada.")
    print("a_confirmar (não vêm do GT2): teto_offline_s, sigma_ruido, cda_m2, consistência e agressividade dos pilotos.")
    return 0


def motor_cambio_roda(car: dict, partes: dict) -> dict:
    """Curva de torque (N·m por rpm), câmbio de fábrica e raio da roda (m)."""
    r = {}
    motores = partes["Engine"]
    i = int(n(car["Engine"]))
    if i < len(motores):
        m = motores[i]
        pts = int(n(m.get("TorqueCurvePoints"))) or 16
        mult = n(m["PowerMultiplier"]) / 100.0
        curva = [(int(n(m[f"TorqueCurveRPM{k}"])) * 100, round(n(m[f"TorqueCurve{k}"]) * 0.01 * 9.80665 * mult, 1))
                 for k in range(1, pts + 1)]
        curva = [c for c in curva if c[0] > 0]
        r["motor"] = {"rpm": [c[0] for c in curva], "torque_nm": [c[1] for c in curva],
                      "corte": int(n(m["RedlineRPM"])) * 100}
    cambios = partes["Gear"]
    i = int(n(car["Gear"]))
    if i < len(cambios):
        g = cambios[i]
        nomes = ["First", "Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh"]
        rel = [n(g[f"{x}GearRatio"]) / 1000.0 for x in nomes if n(g[f"{x}GearRatio"]) > 0]
        if rel:
            r["cambio"] = {"relacoes": rel, "final": n(g["DefaultFinalDriveRatio"]) / 1000.0}
    pneus = partes["TiresFront"]
    i = int(n(car["TiresFront"]))
    if i < len(pneus):
        tam = partes["TireSize"]
        w = int(n(pneus[i]["WheelSize"]))
        if w < len(tam):
            t = tam[w]
            mm = n(t["DiameterInches"]) * 25.4 / 2.0 + n(t["WidthMM"]) * 10.0 * n(t["Profile"]) * 5.0 / 100.0
            r["raio_roda"] = round(mm / 1000.0, 3)
    return r


def potencia_curva(motor: dict) -> float:
    """Potência de pico (ps) pela curva de torque: T [0,01 kgf·m] × rpm / 716,2."""
    pontos = [(n(motor.get(f"TorqueCurve{i}")), n(motor.get(f"TorqueCurveRPM{i}")) * 100) for i in range(1, 17)]
    pico = max((t * r for t, r in pontos if r > 0), default=0.0)
    return pico / 100.0 / 716.2 * n(motor.get("PowerMultiplier")) / 100.0


def moeda(cr: float) -> int:
    """Valor em Cr do GT2 para Giros (FATOR_MOEDA); 0 continua 0."""
    return 0 if cr <= 0 else max(1, round(cr * FATOR_MOEDA))


def usados_do_carro(codigo: str) -> list[list[int]]:
    """Janelas [dia_inicio, dia_fim, preço] em que o carro está no usado do GT2.

    Períodos seguidos com o mesmo preço viram uma janela só.
    """
    janelas: list[list[int]] = []
    for u in sorted((u for u in ler("usados") if u["codigo"] == codigo), key=lambda u: int(u["periodo"])):
        ini, preco = int(u["dia_inicio"]), moeda(int(u["preco"]))
        if janelas and janelas[-1][1] == ini - 1 and janelas[-1][2] == preco:
            janelas[-1][1] = ini + 9
        elif not janelas or janelas[-1][0] != ini:
            janelas.append([ini, ini + 9, preco])
    return janelas


def importar_eventos(nosso: dict, resumo: dict, carros: list[dict], ids_pneus: set[str] = frozenset()) \
        -> tuple[list[dict], list[dict]]:
    brutos = ler("Event")
    pneus_gt2 = ler("TiresFront")
    resumidos = ler("eventos")
    inimigos = ler("EnemyCars")
    por_id = {c["id"]: c for c in carros}
    # Consistência e agressividade não existem no GT2; valores aprovados para a
    # demo, iguais para jogador e IA (regra 5: a mesma IA para todos).
    pilotos = {"jogador": {"id": "jogador", "ritmo": 1.0, "consistencia": CONSISTENCIA, "agressividade": AGRESSIVIDADE}}
    eventos = []
    etapas: dict[str, int] = {}
    regulamentos = ler("Regulations")
    nomes = {c["id"]: c["nome"] for c in carros}
    copas = 0
    usados_marca: set[str] = set()
    for k, (b, r) in enumerate(zip(brutos, resumidos)):
        serie = SERIES.get(r["evento"][:3])
        marca = int(n(r["restricao_carros"]))
        lista_marca: list[str] = []
        if marca > 0 and marca <= len(regulamentos):
            codigos = [_codigo_carro(int(x)) for x in regulamentos[marca - 1]["EligibleCarIds"].split() if int(x)]
            lista_marca = [nosso[c] for c in codigos if c in nosso]
            if lista_marca:
                serie = _nome_copa([nomes[c] for c in lista_marca])
        if serie is None or r["rally"] not in ("", "0") or r["licenca"] not in [""] + LICENCAS_GT2 \
                or int(n(r["voltas"])) > MAX_VOLTAS or (marca > 0 and not lista_marca):
            continue
        restr = {}
        if lista_marca:
            restr["carros"] = lista_marca
            flags = int(n(b.get("CarRestrictionFlags")))
            if flags & (SO_RUA | SO_CORRIDA):
                restr["corrida"] = bool(flags & SO_CORRIDA)
                if restr["corrida"]:
                    serie += " Corrida"
            while serie in usados_marca:
                serie += " II" if not serie.endswith(" II") else "I"
            usados_marca.add(serie)
        if n(r["limite_ps"]) > 0:
            restr["potencia_max"] = int(n(r["limite_ps"]))
        if r["tracao"]:
            restr["tracao"] = [r["tracao"]]
        if r["evento"][:3] in RESISTENCIA:
            restr["licenca"] = "ELITE"
        elif r["licenca"]:
            restr["licenca"] = LICENCA_DO_GT2[r["licenca"]]
        elegiveis = [c for c in carros
                     if c["potencia"] <= restr.get("potencia_max", 10 ** 6) and c["tracao"] in restr.get("tracao", [c["tracao"]])
                     and c["id"] in restr.get("carros", [c["id"]])]
        if not elegiveis:
            continue
        ia = [n(b[c]) for c in b if c.startswith("AIAcceleration")]
        ritmo = round(statistics.mean(ia) / 100.0, 3) if ia and statistics.mean(ia) > 0 else 1.0
        id_piloto = f"ia_{int(round(ritmo * 100))}"
        pilotos[id_piloto] = {"id": id_piloto, "ritmo": ritmo, "consistencia": CONSISTENCIA, "agressividade": AGRESSIVIDADE}
        adversarios = []
        for idx in r["adversarios"].split()[:5]:
            i = int(idx)
            ini = inimigos[i] if i < len(inimigos) else {}
            codigo = ini.get("CarId", "")
            # O rival é o do próprio GT2 (com a preparação dele abaixo).
            if codigo in nosso:
                carro = nosso[codigo]
            else:
                alvo = resumo.get(codigo, {}).get("potencia_real", 0.0)
                carro = min(elegiveis, key=lambda c: abs(c["potencia"] - alvo))["id"]
            adv = {"carro": carro, "piloto": id_piloto}
            # Preparação do rival (EnemyCars): multiplicador de potência e pneu.
            mult = n(ini.get("PowerMultiplier")) / 100.0
            if mult > 0 and abs(mult - 1.0) > 1e-6:
                adv["potencia_mult"] = round(mult, 3)
            pt = int(n(ini.get("TiresFront")))
            if pt < len(pneus_gt2):
                est = int(n(pneus_gt2[pt]["Stage"]))
                if 0 < est != ESTAGIO_TERRA and f"pneu_{est}" in ids_pneus:
                    adv["pneus"] = [f"pneu_{est}"]
            adversarios.append(adv)
        premio_carros = [nosso[c] for c in r["carros_premio"].split() if c in nosso]
        pista = PISTAS.get(r["pista"].lower(), PISTA_PADRAO)
        if lista_marca:
            # O GT2 sorteia a pista das copas de marca; aqui ela gira pelas nossas.
            pool = [p for p in POOL_MARCA if p in PISTAS_EXISTENTES] or [PISTA_PADRAO]
            pista = pool[copas % len(pool)]
            copas += 1
        if pista not in PISTAS_EXISTENTES:
            pista = PISTA_DE_RESERVA.get(pista, PISTA_PADRAO)
        etapas[serie] = etapas.get(serie, 0) + 1
        largada = int(n(b.get("RollingStartSpeed")))
        eventos.append({
            "id": f"ev_{k:03d}", "nome": serie if lista_marca or r["evento"][:3] in RESISTENCIA else f"{serie} — etapa {etapas[serie]}", "pista": pista,
            "voltas": int(n(r["voltas"])) or 2, **({"largada_kmh": largada} if largada > 0 else {}),
            "condicao": "seco", "restricoes": restr, "adversarios": adversarios,
            "premios": [moeda(int(v) * 100) for v in r["premios_x100"].split() if int(v) > 0],
            "carro_premio": premio_carros[0] if premio_carros else None,
        })
        bonus = moeda(int(n(r.get("bonus_campeonato_x100"))) * 100)
        if bonus > 0:
            # SeriesChampBonus do GT2: pago ao campeão da série (decisão 35).
            eventos[-1]["bonus_campeonato"] = bonus
    return eventos, list(pilotos.values())


def _codigo_carro(car_id: int) -> str:
    """Id numérico de carro do GT2 para o código de 5 letras (ver gt2/tabelas.id_para_nome)."""
    return "".join(CARACTERES_ID[(car_id >> (i * 6)) & 0x3F] for i in range(4, -1, -1)).lstrip("-")


def _nome_copa(nomes: list[str]) -> str:
    """Copa de marca pelos modelos da lista (fabricante + modelo, sem versão):
    um modelo dá "Copa Marca Modelo"; dois, "Copa Marca A e B"; mais, as marcas."""
    modelos = list(dict.fromkeys(tuple(x.replace(" Corrida", "").split()[:2]) for x in nomes))
    marcas = list(dict.fromkeys(m[0] for m in modelos))
    if len(modelos) == 1:
        return "Copa " + " ".join(modelos[0])
    if len(modelos) == 2:
        a, b = modelos
        return f"Copa {a[0]} {a[1]} e {b[1] if a[0] == b[0] else ' '.join(b)}"
    return "Copa " + " e ".join(marcas[:2])


def gravar(nome: str, obj) -> None:
    (DATA / f"{nome}.json").write_text(json.dumps(obj, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
