#!/usr/bin/env python3
"""Acrescenta a arte/carros/manifesto.json a descrição (em inglês, para o agente de
imagem) e a cor de fábrica de cada carro de data/carros.json que ainda não está lá.

A descrição sai dos números do carro (ano, categoria, tração, potência, peso) e do
tipo de carroceria lido do nome de referência (referencia/carros.csv, fora do Git):
só o tipo (perua, conversível, 3 portas...), nunca o nome. Versões da mesma família
(mesmo nome de modelo) pedem o mesmo desenho da primeira, para o agente manter a
coerência. Os 17 carros do primeiro build ficam como estão.

Uso: python3 tools/descrever_carros.py
"""
from __future__ import annotations

import csv
import json
import pathlib
import random
import re

RAIZ = pathlib.Path(__file__).resolve().parent.parent
MANIFESTO = RAIZ / "arte/carros/manifesto.json"
CARROS = RAIZ / "data/carros.json"
REF = RAIZ / "referencia/carros.csv"

CORES = ["deep red", "white", "silver grey", "black", "dark blue", "bright yellow", "racing green", "orange",
         "pale sky blue", "metallic gunmetal", "burgundy", "pearl white", "dark green", "light grey", "midnight blue",
         "champagne gold", "teal", "cream", "maroon", "graphite"]
PINTURA_CORRIDA = ["white with a single bold colour band (no text)", "two-tone blue and white (no text)",
                   "red and black blocks (no text)", "yellow with black accents (no text)",
                   "silver with orange panels (no text)", "green and white (no text)"]


def corpo(cat: str, nome_ref: str, peso: int, tracao: str) -> str:
    n = nome_ref.lower()
    if re.search(r"wagon|estate|touring w", n):
        return "five-door estate car"
    if re.search(r"4 ?door|sedan|saloon", n):
        return "four-door saloon"
    if re.search(r"spider|roadster|cabrio|convertible|barchetta|volante|speedster", n):
        return "two-seat open-top roadster"
    if cat == "roadster":
        return "small two-seat open roadster"
    if cat == "compacto":
        if peso and peso < 760:
            return "tiny kei-class city car, very short and narrow"
        return "small three-door hatchback"
    if cat == "seda":
        return "four-door saloon"
    if tracao == "MR":
        return "low mid-engined two-seat sports car, cabin forward, long rear deck"
    if tracao == "RR":
        return "rear-engined two-door sports coupé with a sloping fastback roof"
    return "two-door sports coupé"


def era(ano: int) -> str:
    if ano == 0:
        return "1990s design"
    if ano < 1975:
        return f"{ano} classic design: chrome bumpers, round headlights, slim pillars"
    if ano < 1990:
        return f"{ano} design: angular wedge shape, sharp creases, rectangular or pop-up headlights"
    if ano < 1996:
        return f"{ano} design: smooth rounded body, flush glass"
    return f"{ano} design: rounded modern body, projector headlights, body-coloured bumpers"


def tom(c: dict) -> str:
    ps, kg = c["potencia"], max(c["peso"], 1)
    partes = []
    if ps >= 450:
        partes.append("very wide aggressive stance, big air intakes, large rear wing")
    elif ps >= 270:
        partes.append("sporty stance, bonnet vents, rear spoiler, wide tyres")
    elif ps <= 110:
        partes.append("modest and plain, narrow tyres, small steel wheels")
    if c["tracao"] == "4WD" and ps >= 250:
        partes.append("rally-bred look with a bonnet scoop and flared arches")
    if ps / kg > 0.35:
        partes.append("light and purposeful")
    return ", ".join(partes)


def main() -> int:
    itens = json.loads(MANIFESTO.read_text(encoding="utf-8"))
    tem = {i["id"] for i in itens}
    carros = json.loads(CARROS.read_text(encoding="utf-8"))
    ref = {l["id"]: l for l in csv.DictReader(open(REF, encoding="utf-8"))}
    rng = random.Random(7)
    # Família = nome sem a versão (fabricante + modelo): o primeiro define o desenho.
    primeiro: dict[str, str] = {}
    novos = 0
    for c in carros:
        familia = " ".join(c["nome"].split()[:2])
        if c["id"] in tem:
            primeiro.setdefault(familia, c["id"])
            continue
        l = ref.get(c["id"], {})
        corrida = l.get("codigo_gt2", "").endswith("r")
        desc = "%s, %s drive; %s" % (corpo(c["categoria"], l.get("ref_real", ""), c["peso"], c["tracao"]),
                                     {"FF": "front-wheel", "FR": "rear-wheel", "MR": "mid-engine rear-wheel",
                                      "RR": "rear-engine rear-wheel", "4WD": "four-wheel"}[c["tracao"]], era(int(c["ano"])))
        extra = tom(c)
        if extra:
            desc += "; " + extra
        if corrida:
            desc = "RACE VERSION of a road car: " + desc + "; wide racing body kit, big rear wing, slick tyres, " \
                   "no sponsor text"
        base = primeiro.get(familia)
        if base and base != c["id"]:
            desc += f"; same basic body design as {base} (a variant of the same model)"
        else:
            primeiro[familia] = c["id"]
        itens.append({"id": c["id"], "descricao": desc,
                      "cor": rng.choice(PINTURA_CORRIDA) if corrida else rng.choice(CORES)})
        novos += 1
    MANIFESTO.write_text(json.dumps(itens, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"{novos} carros descritos; manifesto com {len(itens)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
