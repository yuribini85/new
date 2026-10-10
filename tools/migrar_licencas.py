#!/usr/bin/env python3
"""Migração única dos ids de licença do GT2 (B, A, IC, IB, IA) para os do jogo
(CLUB, SPORT, NATIONAL, INTERNATIONAL, PRO; decisão 33) em data/contratos.json,
sem recalibrar: só o campo "licenca" muda. Idempotente.
Uso: python3 tools/migrar_licencas.py
"""
import json
import pathlib

MAPA = {"B": "CLUB", "A": "SPORT", "IC": "NATIONAL", "IB": "INTERNATIONAL", "IA": "PRO"}
CAMINHO = pathlib.Path(__file__).resolve().parent.parent / "data/contratos.json"

contratos = json.loads(CAMINHO.read_text(encoding="utf-8"))
for c in contratos:
    c["licenca"] = MAPA.get(c["licenca"], c["licenca"])
CAMINHO.write_text(json.dumps(contratos, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
print(sorted({c["licenca"] for c in contratos}))
