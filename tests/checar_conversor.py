#!/usr/bin/env python3
"""Testa tools/converter_carros.py com a tabela de exemplo das fixtures."""
import csv
import json
import pathlib
import sys

raiz = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(raiz / "tools"))
from converter_carros import converter  # noqa: E402

fabricantes = {f["id"] for f in json.loads((raiz / "data/fabricantes.json").read_text())}
with open(raiz / "tests/fixtures/referencia_exemplo.csv", newline="", encoding="utf-8") as f:
    carros, erros = converter(list(csv.DictReader(f)), fabricantes)

falhas = []
if erros:
    falhas.append(f"erros inesperados: {erros}")
if "NOME REAL" in json.dumps(carros):
    falhas.append("ref_real vazou para a saída")
if carros[0]["aderencia"] is not None or carros[0]["usado_dias"] != [0, 40]:
    falhas.append(f"opcionais do primeiro carro: {carros[0]}")
if carros[1].get("usado_dias") is not None or carros[1]["freio"] != 0.9:
    falhas.append(f"opcionais do segundo carro: {carros[1]}")
_, erros = converter([{"id": "x", "nome": "X", "fabricante": "nenhuma", "arquetipo": "a", "categoria": "c",
                       "tracao": "AWD", "potencia_cv": "1", "peso_kg": "1", "velocidade_max_kmh": "1",
                       "preco": "1", "ano": "1"}], fabricantes)
if len(erros) != 2:
    falhas.append(f"esperava 2 erros (tração, fabricante): {erros}")

for f in falhas:
    print("FAIL conversor: " + f)
if not falhas:
    print("ok   conversor de carros")
sys.exit(1 if falhas else 0)
